import numpy as np
import os
import sys
sys.path.append('/ncrc/home1/Kun.Gao/py_functions/')
from vi_functions import *
from functions import *

do_write_out = True 

min_wind = 20. 
max_lat = 35.
res = 1/33.
min_dist_dom0 = 2. # deg
min_dist_dom1 = 0.1 # filter domain deg
filter_domain = 24.

grid0 = 'C768r10n4_atl_vi'
grid1 = 'C768r10n4_atl_vi_large'
grid_base = '/lustre/f2/dev/gfdl/Kun.Gao/SHiELD_IC_v16/' 

vital_base = '/ncrc/home1/Kun.Gao/tshield_vi_driver/tc_vitals/'
ic_base = '/lustre/f2/dev/gfdl/Kun.Gao/SHiELD_IC_v16/C768r10n4_atl_vi/'

#os.mkdir(vital_base + '/processed/')

date_list = []
date1 = dt.datetime.strptime('2020082000',"%Y%m%d%H")
for t in np.arange(160):
      date1 = date1 + dt.timedelta(days=0.5)
      date_list.append(date1.strftime("%Y%m%d%H"))

#date1 = dt.datetime.strptime('2022090100',"%Y%m%d%H")
#for t in np.arange(60):
#      date1 = date1 + dt.timedelta(days=0.5)
#      date_list.append(date1.strftime("%Y%m%d%H"))

#date_list = ['2022092000']

# --- Main program begins

min_index_dom0 = int(min_dist_dom0/res)
min_index_dom1 = int(min_dist_dom1/res)

#grid_file0 = grid_base + grid0 + '/INPUT/grid_spec.nest02.tile7.nc'
#grid_file1 = grid_base + grid1 + '/INPUT/grid_spec.nest02.tile7.nc'

grid_file0 = grid_base + grid0 + '/INPUT/C768_grid.tile7.nc'
grid_file1 = grid_base + grid1 + '/INPUT/C768_grid.tile7.nc'

'''
grid0_latt = read_nc(grid_file0, 'grid_latt')
grid0_lont = read_nc(grid_file0, 'grid_lont')
grid1_latt = read_nc(grid_file1, 'grid_latt')
grid1_lont = read_nc(grid_file1, 'grid_lont')
'''

y0 = read_nc(grid_file0, 'y')
x0 = read_nc(grid_file0, 'x')
grid0_lont = x0[1::2,1::2]
grid0_latt = y0[1::2,1::2]

y1 = read_nc(grid_file1, 'y')
x1 = read_nc(grid_file1, 'x')
grid1_lont = x1[1::2,1::2]
grid1_latt = y1[1::2,1::2]

for date in date_list:
  vital_file = vital_base + 'observed_all/tcvitals_'+date[:-2]+'.'+date[-2:]+'Z.txt'
  #vital_file = vital_base + 'observed_all/tcvitals_20200916.00Z.txt'
  ic_dir = ic_base + date[:-2]+'.'+date[-2:]+'Z_IC'
 
  out_dir = vital_base + 'processed/'

  if os.path.exists(vital_file) and os.path.exists(ic_dir+'/gfs_ctrl.nc') :
    print '-'*20, date
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
      if tc_vmax >=min_wind and tc_lat <=max_lat:

         de0,dw0,ds0,dn0 = find_min_dist_tc_center_and_domain_edges(360-tc_lon, tc_lat, grid0_lont, grid0_latt)
         de1,dw1,ds1,dn1 = find_min_dist_tc_center_and_domain_edges(360-lon_p1, lat_p1, grid1_lont, grid1_latt)
         de2,dw2,ds2,dn2 = find_min_dist_tc_center_and_domain_edges(360-lon_p2, lat_p2, grid1_lont, grid1_latt)
         de3,dw3,ds3,dn3 = find_min_dist_tc_center_and_domain_edges(360-lon_p3, lat_p3, grid1_lont, grid1_latt)
         de4,dw4,ds4,dn4 = find_min_dist_tc_center_and_domain_edges(360-lon_p4, lat_p4, grid1_lont, grid1_latt)

         if min(de0,dw0,ds0,dn0) > min_index_dom0 \
         and min(de1,dw1,ds1,dn1) > min_index_dom1 \
         and min(de2,dw2,ds2,dn2) > min_index_dom1 \
         and min(de3,dw3,ds3,dn3) > min_index_dom1 \
         and min(de4,dw4,ds4,dn4) > min_index_dom1: 

           find_good_tc = True

      # stop looping all TCs at this initialization time
      if find_good_tc:
         break 

    if find_good_tc:
      stormID = tc_id[2:]

      print 'STORMID, OBS VMAX:', stormID, tc_vmax

      # detect TC in IC - location of min pres
      #print 'Obs lat, lon:', tc_lat, tc_lon
      #print ic_dir
      tc_lon_mod, tc_lat_mod = detect_tc_center_from_ic(ic_dir, tc_lon, tc_lat, opt=0)
      print 'Obs lat, lon:', tc_lat, tc_lon 
      print 'Mod lat, lon:', tc_lat_mod, tc_lon_mod
      if abs(tc_lat_mod-tc_lat) >0.5 or  abs(tc_lon_mod-tc_lon) > 0.5:
         print 'Check this case more carefully ...'
     
      # write out txt files
      if do_write_out:
        out_dir = vital_base + '/processed/'+date+'/'
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
