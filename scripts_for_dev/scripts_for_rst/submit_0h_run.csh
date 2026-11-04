##!/bin/tcsh

set hh_list=(00 12)

#set initial=20220901
#set end=30
set initial=20210820
set end=52

set hh_list=(00)
set initial=20210925
set end=1

set int=1

set grid1 = C768r10n4_atl_vi
set grid2 = C768r10n4_atl_vi_large
set script_dir  = /ncrc/home1/Kun.Gao/SHiELD/SHiELD_run/GAEA/script_vi/
set basescript1 = ${script_dir}/RUN_tsh22_vi_0h.csh
set basescript2 = ${script_dir}/RUN_tsh22_vi_large_0h.csh

set rst_base = /lustre/f2/dev/Kun.Gao/tshield_vi/

set vital_dir = /ncrc/home1/Kun.Gao/tshield_vi_driver/tc_vitals/processed/

set i=0
set x=0
while ($x < $end)

  foreach hh ( $hh_list )
  set DATE = `date -d "$initial $i days" +%Y%m%d`
  set ic_dir1 = /lustre/f2/dev/gfdl/Kun.Gao/SHiELD_IC_v16/${grid1}/${DATE}.${hh}Z_IC/
  set ic_dir2 = /lustre/f2/dev/gfdl/Kun.Gao/SHiELD_IC_v16/${grid2}/${DATE}.${hh}Z_IC/
  set tcvitial = ${vital_dir}/${DATE}${hh}/tcvitals.vi

  set target_dir1 = ${rst_base}/${DATE}.${hh}Z.${grid1}.nh.32bit.non-mono.0h/rundir/RESTART
  set target_dir2 = ${rst_base}/${DATE}.${hh}Z.${grid2}.nh.32bit.non-mono.0h/rundir/RESTART

  if (-f $tcvitial && -d $ic_dir1 && ! -f $target_dir1/coupler.res ) then
     echo 'submitting' $DATE.$hh vi
     sbatch --job-name=${DATE}${hh}_0h       --export=NAME=${DATE}.${hh}Z,ALL $basescript1
  endif
  if (-f $tcvitial && -d $ic_dir2 && ! -f $target_dir2/coupler.res ) then
     echo 'submitting' $DATE.$hh vi_large
     sbatch --job-name=${DATE}${hh}_0h_large --export=NAME=${DATE}.${hh}Z,ALL $basescript2
  endif
  end

  @ i = $i + $int
  @ x++
end
