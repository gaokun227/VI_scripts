#! /usr/bin/env python3
import numpy as np
import os
import sys
import getopt
#from vi_functions import *
#from netCDF4 import Dataset
from scipy.io import netcdf

# ===> define functions to be used 

def read_nc(file, var_name):
    f1 = netcdf.netcdf_file(file, 'r')
    var  = f1.variables[var_name][:]
    var  = np.squeeze(var)
    return var

def find_min_dist_tc_center_and_domain_edges(tc_lon, tc_lat, grid_lont, grid_latt):
  ny, nx = np.shape(grid_lont)
  dist = (grid_latt-tc_lat)**2 + (grid_lont-tc_lon)**2
  detected_center =  np.where(dist == np.min(dist))
  jc, ic = detected_center[0][0], detected_center[1][0]
  dist_e = ic
  dist_w = nx-ic
  dist_s = ny-jc
  dist_n = jc
  return dist_e, dist_w, dist_s, dist_n

def read_tcvitals(filename):
    # Note TCs in input file are sorted based on intensity
    tc_dict = {}
    f = open(filename, "r")
    counter = 0
    for line in f:
        tc_tmp = {}
        L = line.split()
        tc_id = str(counter)+'_'+L[1]
        tc_tmp['lat'] = float(L[5][:-1])/10
        tc_tmp['lon'] = float(L[6][:-1])/10
        tc_tmp['vmax'] = float(L[12])
        tc_dict[tc_id] = tc_tmp
        counter += 1
    return tc_dict

def find_center(var, lon, lat, tc_lon, tc_lat):
    dlon = lon - (360-tc_lon)
    dlat = lat - tc_lat
  
    dist = (dlon**2+dlat**2)**0.5
    center = np.where(dist == np.nanmin(dist))
    ic, jc = center[0][0], center[1][0]

    box_half_width = 0.5 # deg
    res = 1./33 # res in deg
    scope = np.int(box_half_width/res)
  
    var_sel = var[ic-scope:ic+scope, jc-scope:jc+scope]
    lon_sel = lon[ic-scope:ic+scope, jc-scope:jc+scope]
    lat_sel = lat[ic-scope:ic+scope, jc-scope:jc+scope]

    detected_center =  np.where(var_sel == np.nanmin(var_sel))

    ic_new, jc_new = detected_center[0][0], detected_center[1][0]

    tc_lon_new = 360-lon_sel[ic_new,jc_new]
    tc_lat_new = lat_sel[ic_new,jc_new]

    return tc_lon_new, tc_lat_new

def detect_tc_center_from_ic_for_jet(ic_dir, tc_lon, tc_lat):
    f1 = netcdf.netcdf_file(ic_dir+'/ps_nc3.nc', 'r')
    print(ic_dir+'/ps_nc3.nc')

    lon = f1.variables['geolon'][:]
    lat = f1.variables['geolat'][:]
    var = np.squeeze(f1.variables['ps'][:])
    #slmsk = np.squeeze(f2.variables['slmsk'][:])
    #slmsk[slmsk==1]=np.nan
    #slmsk[slmsk==0]=1
    #var = var*slmsk
    tc_lon_new, tc_lat_new = find_center(var, lon, lat, tc_lon, tc_lat)
    return np.round(tc_lon_new,1), np.round(tc_lat_new,1)

# ===> main program

# INPUT needed

# -d: date          -> current date as CDATE 
# -w: min_wind      -> min Vmax for VI
# -l: max_lat       -> max initial lat for VI
# -i: ic_base       -> base dir for ic, e.g., '/lustre/f2/dev/gfdl/Kun.Gao/SHiELD_IC_v16/'+grid+'/'
# -f: vital_file    -> obs vital messages as a txt file, e.g., vital_base+'observed_all/tcvitals_'+date+'.txt'
# -o: vital_dir_out -> where processed tc txt files are saved, e.g., vital_base+'/processed/'

# --- get the arguments from the command line
argv = sys.argv[1:]
try:
    opts, args = getopt.getopt(argv, 'd:w:l:i:f:o:')
    if len(opts) == 0 and len(opts) > 6:
      print ('wrong input args')
    else:
      for opt, arg in opts:
          if opt == '-d':
             date = arg
          elif opt == '-w':
             min_wind = float(arg)
          elif opt == '-l':
             max_lat = float(arg)
          elif opt == '-i':
             ic_base = arg
          elif opt == '-f':
             vital_file = arg
          elif opt == '-o':
             vital_dir_out = arg
# KGao: need better error control for RT system
except getopt.GetoptError:
    print ('wrong args')
    sys.exit(2)

# --- hardcoded paramters below
#min_wind = 20. 
#max_lat = 35.
filter_domain = 10.
res = 1/33.
min_dist_dom = 0.1 # min distance of the selected box corners from the nested domain edges 

# --- Main program begins

if not os.path.exists(vital_dir_out): 
   os.mkdir(vital_dir_out)
min_index_dom = int(min_dist_dom/res)

grid_file = ic_base + '/GRID/grid_spec.nest02.tile7.nc'
grid_latt = read_nc(grid_file, 'grid_latt')
grid_lont = read_nc(grid_file, 'grid_lont')
ic_dir = ic_base + date[:-2]+'.'+date[-2:]+'Z_IC'

if True:
    tc_dict = read_tcvitals(vital_file)
    tc_id_list = list(tc_dict.keys())
    tc_id_list.sort()

    # check if the selected TC is most suitable for VI
    # if more than one TC, starts from the strongest

    find_good_tc = False
    for i in range(len(tc_id_list)):
      tc_id = tc_id_list[i]
      tc_lon = tc_dict[tc_id]['lon']   
      tc_lat = tc_dict[tc_id]['lat']
      tc_vmax = tc_dict[tc_id]['vmax']

      # filter domain corners
      lat_p1 = tc_lat + filter_domain/2.
      lon_p1 = tc_lon + filter_domain/2.
      lat_p2 = tc_lat + filter_domain/2.
      lon_p2 = tc_lon - filter_domain/2.
      lat_p3 = tc_lat - filter_domain/2.
      lon_p3 = tc_lon + filter_domain/2.
      lat_p4 = tc_lat - filter_domain/2.
      lon_p4 = tc_lon - filter_domain/2.

      # Here we select the TC for VI
      # level 1 criterion: TC needs to be strong enough and not located too far north
      # level 2 criterion: TC needs to be far enough from the domain edges

      if tc_vmax >=min_wind: # and tc_lat <=max_lat:

         de1,dw1,ds1,dn1 = find_min_dist_tc_center_and_domain_edges(360-lon_p1, lat_p1, grid_lont, grid_latt)
         de2,dw2,ds2,dn2 = find_min_dist_tc_center_and_domain_edges(360-lon_p2, lat_p2, grid_lont, grid_latt)
         de3,dw3,ds3,dn3 = find_min_dist_tc_center_and_domain_edges(360-lon_p3, lat_p3, grid_lont, grid_latt)
         de4,dw4,ds4,dn4 = find_min_dist_tc_center_and_domain_edges(360-lon_p4, lat_p4, grid_lont, grid_latt)

         if  min(de1,dw1,ds1,dn1) > min_index_dom \
         and min(de2,dw2,ds2,dn2) > min_index_dom \
         and min(de3,dw3,ds3,dn3) > min_index_dom \
         and min(de4,dw4,ds4,dn4) > min_index_dom: 

           find_good_tc = True

      # stop looping all TCs at this initialization time
      if find_good_tc:
         break 

    if find_good_tc:
      stormID = tc_id[2:]

      #print 'STORMID, OBS VMAX:', stormID, tc_vmax

      # detect TC in IC - location of min pres
      #print 'Obs lat, lon:', tc_lat, tc_lon

      tc_lon_mod, tc_lat_mod = detect_tc_center_from_ic_for_jet(ic_dir, tc_lon, tc_lat)
      #print 'Obs lat, lon:', tc_lat, tc_lon 
      #print 'Mod lat, lon:', tc_lat_mod, tc_lon_mod
      if abs(tc_lat_mod-tc_lat) >0.5 or  abs(tc_lon_mod-tc_lon) > 0.5:
         print ('Check this case more carefully ...')
     
      # write out txt files
      do_write_out = True
      if do_write_out:
        out_dir = vital_dir_out + date + '/'
        out_file1 = out_dir + 'tcvitals.vi'
        out_file2 = out_dir + stormID + '.' + date + '.trak.atcfunix.all'

        if os.path.exists(out_dir):
           if os.path.exists(out_file1):
              os.remove(out_file1)
           if os.path.exists(out_file2):
              os.remove(out_file2)
           os.rmdir(out_dir) 
        os.mkdir(out_dir)

        # generate obs tc vital file
        obs_string = "NHC  "+stormID
        #print obs_string, vital_file, out_file1
        cmd = 'grep "{}" {} > {}'.format(obs_string, vital_file, out_file1)
        os.system(cmd)

        # generate model atcf file
        lat_str = str(int(np.round(tc_lat_mod*10,0)))
        lon_str = str(int(np.round(tc_lon_mod*10,0)))
        #print lat_str, lon_str
        # Note: only lat,lon info is acutually used in VI as of 01/12/2022; intensity and R34 not important
        mod_string = "AL, {}, {}, 03, HAFS, 000, {}N,  {}W,  00,  000, XX,  34, NEQ, 0000, 0000, 0000, 0000".format(stormID[:2], date, lat_str, lon_str)

        f = open(out_file2, "w")
        n = f.write(mod_string)
        f.close()
