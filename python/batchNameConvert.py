#!/usr/bin/env python

import sys
import os
import re
from string import *

def main(argv):

    start_label = argv[1]
    end_label = argv[2]
    file_names = argv[3:]
    curdir = os.getcwd()
    for file_name in file_names:
        os.chdir(curdir)
        if re.search(start_label, file_name):
            sname = file_name.split(start_label)
            output_name = end_label + sname[1]
            os.renames(file_name, output_name)
            if os.path.isdir(output_name):
                os.chdir(output_name)
                args = ['name', start_label, end_label]
                args.extend(os.listdir(os.getcwd()))
                main(args)
        
if __name__ == "__main__":
    main(sys.argv)
