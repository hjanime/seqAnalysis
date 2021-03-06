#!/bin/env python

import os, sys, re, string
import argparse
import pysam

bed_dir = "/media/storage2/data/bed/"

def main(argv):
    
    parser = argparse.ArgumentParser(description="convert BAM file to BED")
    parser.add_argument("-i", required=True, dest='sam')
    parser.add_argument('-p', action='store_true', dest='pe', default=False, 
                        help="include if sample is paired-end")
    args = parser.parse_args()
    # open BAM and get the iterator
    sam = args.sam
    pe = args.pe
    # check for index
    if not os.path.exists(sam + ".bai"):
        print "Creating index"
        pysam.index(sam)
    samfile = pysam.Samfile(sam, "rb" )
    it = samfile.fetch()
    
    # calculate the end position and print out BED
    take = (0, 2, 3) # CIGAR operation (M/match, D/del, N/ref_skip)
    bed = bed_dir + sam.split(".")[0] + ".bed"
    bedfile = open(bed, 'w')
    print "Writing BED"
    chrom = ""
    for read in it:
        tmp = samfile.getrname(read.rname)
        if tmp != chrom:
            print tmp
            chrom = tmp
        if read.is_unmapped or int(read.mapq) < 255: continue
        # compute total length on reference
        #t = 0
        if not pe:
            t = sum([ l for op,l in read.cigar if op in take ])
        else:
            if read.is_reverse:
                t = -1 * read.isize
                strand = "-"
            else :
                t = read.isize
                strand = "+"
        #if read.is_reverse: strand = "-"
        #else: strand = "+"
        bedfile.write("%s\t%d\t%d\t%s\t%d\t%c\n" %\
                          ( samfile.getrname( read.rname ),
                            read.pos, read.pos+t, read.qname,
                            read.mapq, strand) )            

if __name__ == "__main__":
    sys.exit( main( sys.argv) )
