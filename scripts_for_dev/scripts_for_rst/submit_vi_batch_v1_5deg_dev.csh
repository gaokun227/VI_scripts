##!/bin/tcsh

set hh_list=(00 12)
#set initial=20220901
#set end=30
set initial=20200820
set end=52

set hh_list=(00)
set initial=20220901
set end=30
set int=1

set script = /ncrc/home1/Kun.Gao/tshield_vi_driver/exhafs_atm_vi_general_v1_5deg_dev.sh
set vital_dir = /ncrc/home1/Kun.Gao/tshield_vi_driver/tc_vitals/processed_vi1/

set i=0
set x=0
while ($x < $end)

  set DATE = `date -d "$initial $i days" +%Y%m%d`

  foreach hh ($hh_list)
  # check if model restart files and processed vitial files exist
  set rst_dir = /lustre/f2/dev/Kun.Gao/tshield_vi/${DATE}.${hh}Z.C768r10n4_atl_vi_large.nh.32bit.non-mono.0h/rundir/
  set rst_src_dir = ${rst_dir}/RESTART
  set rst_out_dir = ${rst_dir}/RESTART_vi_5deg
  set vital_file = ${vital_dir}/${DATE}${hh}/tcvitals.vi

  if (-f $vital_file  && -d $rst_src_dir && ! -d $rst_out_dir ) then
     set CDATE=$DATE$hh
     set atcf_file = `cd ${vital_dir}/${DATE}${hh} && ls *atcf*`
     set STORMID=`echo $atcf_file  | cut -c1-3`
     echo 'submitting' $CDATE, $STORMID
     sbatch --job-name=vi_${CDATE} --export=CDATE=${CDATE},STORMID=${STORMID},rst_dir=${rst_dir},vital_dir=${vital_dir},ALL ${script} 
  endif

  end
  @ i = $i + $int
  @ x++
end
