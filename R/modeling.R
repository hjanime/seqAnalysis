library(MASS)
registerDoMC(cores=4)

fitNormal <- function(vals, plot=TRUE) {
  normfit <- fitdistr(vals, "normal")
  if (plot) {
    x <- seq(min(vals), max(vals), length=100)
    y <- dnorm(x, normfit$estimate[1], normfit$estimate[2])
    plot(density(vals))
    lines(x, y, col="red")
  }  
  return(normfit)
}


fitCauchy <- function(vals, plot=TRUE) {
  dfit <- fitdistr(vals, "cauchy")
  if (plot) {
    x <- seq(min(vals), max(vals), length=100)
    y <- dcauchy(x, dfit$estimate[1], dfit$estimate[2])
    plot(density(vals))
    lines(x, y, col="red")
  }
}

fitT <- function(vals, plot=TRUE) {
   dfit <- fitdistr(vals, "t")
  if (plot) {
    plotDistModel(vals, dfit)
  }
}

fitPois <- function(vals, plot=TRUE) {
  dfit <- fitdistr(vals, "poisson")
  if (plot) {
      step <- round((max(vals) - min(vals)) / 500)
      x <- seq(min(vals), max(vals), by=step)
    y <- dpois(x, dfit$estimate[1])
    plot(density(vals))
    lines(x, y, col="red")
  }
}

fitExp <- function(vals, plot=TRUE) {
  dfit <- fitdistr(vals, "exponential")
  if (plot) {
      step <- round((max(vals) - min(vals)) / 500)
      x <- seq(min(vals), max(vals), by=step)
    y <- dexp(x, dfit$estimate[1])
    plot(density(vals))
    lines(x, y, col="red")
  }
}

plotDistModel <- function(vals, dfit) {
  step <- round((max(vals) - min(vals)) / 100)
  x <- seq(min(vals), max(vals), by=step)
  y <- dt(x, dfit$estimate[1], dfit$estimate[2])
  plot(density(vals))
  lines(x, y, col="red")
}

getNormQ <- function(fit.param, q) {
  d <- qnorm(q, mean=fit.param$estimate[1], fit.param$estimate[2])
  return(d)
}

permutationTest <- function(x, y, N=1000, sub=0.5, FUN="mean") {
  x_y <- c(x, y)
  t_obs <- abs(mean(x, na.rm=TRUE) - mean(y, na.rm=TRUE))
  t_perm <- vector("numeric", N)

  sample_size <- length(x_y) * sub
  
  for (i in 1:N) {
    ind <- sample(1:length(x_y), sample_size)
    #x_y_perm <- x_y[ind]
    half_1 <- 1:(sample_size/2)
    #print(half_1)
    half_2 <- (sample_size/2 + 1):sample_size
    #print(half_2)
    t_perm[i] <- abs(do.call(FUN, list(x_y[ind[half_1]], na.rm=TRUE)) - do.call(FUN, list(x_y[ind[half_2]], na.rm=TRUE)))

  }
  
  above <- table(t_perm >= t_obs)
  if (length(above) == 2) {
    p_value <- above[2]/N
  } else {
    p_value <- 0
  }
  return(p_value)
  print(table(t_perm >= t_obs))
}

## Accepts two matrices, tests pairwise by column
permutationTest.mat <- function(d1, d2, chunkSize=5, N=10000, adjust="BH") {
  ncols <- ncol(d1)
  i <- 0
  out <- foreach(column=isplitIndices(ncols, chunkSize=chunkSize), .combine="c") %dopar% {
    if (chunkSize > 1) {
      x <- apply(d1[,column], 1, mean, na.rm=TRUE)
      y <- apply(d2[,column], 1, mean, na.rm=TRUE)
    } else {
      x <- d1[,column]
      y <- d2[,column]
    }
    permutationTest(x, y, N=N)
  } 
  if (!is.null(adjust)) p.adjust(out, method="BH")
  return(out)
}

## Accepts list of matrices and performs a pairwise comparison on all combinations
## Returns list of column pvalues for each comparison
permutationTest.matList <- function(data, chunkSize=5, N=10000, adjust="BH") {
  comparisons <- combn(names(data), 2)
  comparisons_labels <- apply(comparisons, 2, paste, collapse="_")
  out <- apply(comparisons, 2, function(comparison) {
    print(comparison)
    permutationTest.mat(data[[comparison[1]]], data[[comparison[2]]], chunkSize=chunkSize, N=N, adjust=adjust)
  })
  colnames(out) <- comparisons_labels
  return(out)
}

permutationTest.quantile <- function(x, y, N=1000, quantile) {
  qs <- foreach (i=1:N, .combine=c) %do% {
    ind <- sample(1:length(y), length(y))
    ratio <- log2(x / y[ind])
    return(quantile(ratio, probs=quantile))
  }
  return(mean(qs))
}

plotSigLine <- function(sig_values, thresh=0.05, step, yval, ...) {
  sig_positions <- which(sig_values <= thresh)
  if (length(sig_positions > 0)) {
    for(i in 1:length(sig_positions)) {
      lines(c(sig_positions[i] * step, sig_positions[i] * step + step ), rep(yval, times=2), lwd=2, ...)
    }
  } else {
    print("No significant positions.")
  }  
}

KLdist <- function(x, y) {
  out <- sum(x * log(x/y))
  return(out)
}

JSdist <- function(x, y) {
  xy_mean <- (x + y) / 2
  out <- sqrt(KLdist(x, xy_mean) / 2 + KLdist(y, xy_mean) / 2)
  if (is.nan(out)) out <- 0
  return(out)
}

funOnColPairs <- function(data, FUN) {
  #print(ncol(data))
  nc <- ncol(data)
  if (!is.null(nc)) {
    ind <- seq(1,ncol(data), 2)
    tmp <- unlist(lapply(ind, function(x) do.call(FUN, list(data[,x], data[,x+1]))))
    return(tmp)
  }
  return(do.call("rbind", tmp))
}

# data is data.frame with paired columns of values and column for splitting
# key indicates which column to split by
# ind is the column indices of data to be processed
JScounts <- function(data, key, ind) {
  data.s <- split(data, data[,'key']) 
  data.norm <- lapply(data.s, function(x) apply(x[,ind], 2, function(y) y/sum(y)))
  out <- lapply(data, function(x) funOnColPairs(x, JSdist))
  return(do.call("rbind", out))
}
  
## Table factors
## For each factor
##     Sample N values from index vector
##     Subtract sampled values
## Compute median values for each sampled factor set
## Compute fraction with given factor arrangement

sampleMultipleFactors <- function(vals, blank.factor="NO") {
  vals.table <- table(vals)
  vals.table <- vals.table[names(vals.table)!=blank.factor]
  curr.ind <- 1:length(vals)
  new.vals <- c()
  for (i in 1:length(vals.table)) {
    ind.sample <- sample(curr.ind, vals.table[i])
    names(ind.sample) <- rep(names(vals.table)[i], times=length(ind.sample))
    new.vals <- c(new.vals, ind.sample)
    curr.ind <- setdiff(curr.ind, ind.sample)
  }
  return(new.vals)
}

testPattern <- function(value, factor, blank.factor="NO", N=10000) {
  out <- foreach(n=1:N, .combine="rbind") %dopar% {
    new_values <- data.frame(value, as.character(blank.factor))
    #print(new_values)
    new_ind <- sampleMultipleFactors(factor, blank.factor=blank.factor)
    print(new_ind)
    print(names(new_ind))
    new_values[new_ind,2] <- names(new_ind)
    print(new_values)
    summ <- tapply(new_values[,1], new_values[,2], median)
    return(summ)
  }
  return(out)
}

testPeakIntersects <- function(summary) {
  GENOME_SIZE <- 2E9
  peak_basename <- str_split(summary, "/")
  print(peak_basename)
  peak_basename <- peak_basename[[1]][length(peak_basename[[1]]) - 1]
  data <- read.delim(summary)
  #return(data)
  
  pvalues <- apply(data, 1, function(feature) {
    #print(feature)
    obs <- as.numeric(feature[5])
    total <- as.numeric(feature[2])
    feature_fraction <- as.numeric(feature[4]) / GENOME_SIZE
                                        #return(feature_fraction)
    exp <- round(total * feature_fraction)
    contig_table <- matrix(c(obs, total - obs, exp, total - exp), ncol=2)
    chisq.test(contig_table)$p.value
  })
  
  names(pvalues) <- data$feature
  qvalues <- p.adjust(pvalues, method="BH")
  out <- data.frame(chisq.pvalue=unlist(pvalues), chisq.BH=qvalues)
  out_path <- paste("~/s2/data/homer/peaks/intersections/", peak_basename, "stats", "chisq", sep="/")
  write.table(out, file=out_path, quote=FALSE, sep="\t")
  return(out)            
}
