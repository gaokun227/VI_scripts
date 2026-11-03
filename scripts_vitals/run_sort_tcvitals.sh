##!/bin/tcsh

set hh_list = (00 12)

# 2022 0901-0930 
#set initial=20220901
#set end=30
#set int=1

# 2024 0701-1030
set initial=20240701
set end=130
set int=1

set min_wind = 20.
set max_lat = 40.

set ic_dir = /gpfs/f6/bil-coastal-gfdl/proj-shared/Kun.Gao/SHiELD_INPUT/SHiELD_IC_v16/
set tcvital_dir = $HOME/vi_driver/tc_vitals/observed_all/ 
mkdir -p $tcvital_dir

set i=0
set x=0
while ($x < $end)
  set DATE = `date -d "$initial $i days" +%Y%m%d`

   foreach hh ($hh_list)

   set IC = ${ic_dir}/${DATE}.${hh}Z_IC/
   echo 'finding tc vitals at' ${DATE}.${hh}
   # note some loose criteria already added here
   /autofs/ncrc-svm1_home1/Kun.Gao/VI/HAFS_tools/ush/tcutil_multistorm_sort_gfdl.py ${DATE}${hh} L $min_wind $max_lat > tmpvit
   more tmpvit
   grep -q -F "NHC" "tmpvit" && mv tmpvit ${tcvital_dir}/tcvitals_${DATE}.${hh}Z.txt || echo 'TC not found'
   rm -f tmpvit
   end

   @ i = $i + $int
  @ x++

end
