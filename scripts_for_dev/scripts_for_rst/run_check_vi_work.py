import numpy as np
import os
import sys
import glob
import json

sys.path.append('/ncrc/home1/Kun.Gao/py_functions/')
from vi_functions import *

write_out_json = True

vital_base = '/ncrc/home1/Kun.Gao/tshield_vi_driver/tc_vitals/processed_vi1/'
work_base =  '/lustre/f2/scratch/gfdl/Kun.Gao/tshield_vi_work_small_sol0_a/'

date_list = []
date1 = dt.datetime.strptime('2021082000',"%Y%m%d%H")
for t in np.arange(180):
      date1 = date1 + dt.timedelta(days=0.5)
      date_list.append(date1.strftime("%Y%m%d%H"))

date_list = []
date1 = dt.datetime.strptime('2021090100',"%Y%m%d%H")
for t in np.arange(60):
      date1 = date1 + dt.timedelta(days=0.5)
      date_list.append(date1.strftime("%Y%m%d%H"))

dict_good = {}

for date in date_list:

 obs_vital = vital_base + date + '/tcvitals.vi'
 if os.path.exists(obs_vital):
  tc_dict = read_tcvitals(obs_vital)
  tc_id_list = list(tc_dict.keys())
  stormID = tc_id_list[0][2:]

  work_dir_ = work_base + date + '/' + stormID + '/intercom/' 
  work_dirs = glob.glob(work_dir_)

  if len(work_dirs) == 1:

    print '='*20, date 
    work_dir = work_dirs[0]
    #print work_dir

    check_dir = work_dir + '/check/' 
    obs_vital = work_dir + '../tcvitals.vi'

    if os.path.exists(check_dir):
      print 'VI is good'
      dict_good[date] = stormID 
    else:
      print 'VI did not work'

if write_out_json:
   with open("good_vi_list.json", "w") as outfile:
     json.dump(dict_good, outfile, indent=0, sort_keys=True)
    

