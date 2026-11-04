import numpy as np
import matplotlib.pyplot as plt
import datetime as dt
from netCDF4 import Dataset
import glob
import os
import getopt
import sys

# Input needed:
# source_dir
# target_dir

# Get the arguments from the command line
argv = sys.argv[1:]
try:
    opts, args = getopt.getopt(argv, 'a:b:', ['foperand', 'soperand'])
    if len(opts) == 0 and len(opts) > 2:
      print ('usage: name.py -a <first_operand> -b <second_operand>')
    else:
      for opt, arg in opts:
          if opt == '-a':
             source_dir = arg
          if opt == '-b':
             target_dir = arg
except getopt.GetoptError:
    print ('wrong args')
    sys.exit(2)

# Grid settings
ioffset1, joffset1 = 25, 49 
ioffset2, joffset2 = 49, 241
refine_ratio = 4
idiff = (ioffset2-ioffset1)*refine_ratio
jdiff = (joffset2-joffset1)*refine_ratio

# Main program
files = ['fv_tracer', 'fv_core']
var_list1 = ['sphum']
var_list2 = ['u','v','DZ','T','delp']#,'phis']

for file_name in files:

  file1 = source_dir + file_name + '.res.nest02.tile7.nc' 
  file2 = target_dir + file_name + '.res.nest02.tile7.nc' 

  f1 = Dataset(file1, 'r')
  f2 = Dataset(file2, 'r+')

  if 'tracer' in file_name:
      var_list = var_list1
  else:
      var_list = var_list2

  for var_name in var_list:

     print var_name
     var1_size = np.squeeze(f1.variables[var_name][0,-1,:,:])
     var2_size = np.squeeze(f2.variables[var_name][0,-1,:,:])
     ny1, nx1 = np.shape(var1_size)
     ny2, nx2 = np.shape(var2_size)
     #print nx1,ny1, nx2,ny2

     var1_sel = f1.variables[var_name][0, :, jdiff : jdiff+ny2, idiff : idiff+nx2]
     #print np.shape(var1_sel)

     offset = 5 # uses a smaller?  
     f2[var_name][0,:,offset:-offset,offset:-offset] = var1_sel[:, offset:-offset, offset:-offset] # do not overwrite the edge points
  f1.close()
  f2.close()
