library(boot)

boot.samplemean <- function(x, d) {
  return(mean(x[d]))
}

bootCI <- function(vals) {
  bootObj <- boot(data=vals, statistic=boot.samplemean, R=100)
  bootCI <- boot.ci(bootObj, type="perc")
  percentCI <- as.array(bootCI$percent[1,4:5])
  return(percentCI)
}