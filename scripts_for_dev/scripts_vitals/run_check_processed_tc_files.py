import numpy as np
import os
import sys
import glob
import json

sys.path.append('/ncrc/home1/Kun.Gao/py_functions/')
from vi_functions import *

vital_base = '/ncrc/home1/Kun.Gao/tshield_vi_driver/tc_vitals/processed/'

date_list = []
date1 = dt.datetime.strptime('2021082000',"%Y%m%d%H")
for t in np.arange(180):
      date1 = date1 + dt.timedelta(days=0.5)
      date_list.append(date1.strftime("%Y%m%d%H"))

print date_list[-1]

for date in date_list:

 obs_vital = vital_base + date + '/tcvitals.vi'
 if os.path.exists(obs_vital):
  tc_dict = read_tcvitals(obs_vital)
  tc_id_list = list(tc_dict.keys())
  tc_id = tc_id_list[0]
  stormID = tc_id[2:]
  print '-'*20, date
  print stormID, 'vmax:', tc_dict[tc_id]['vmax']
  print ''
    

