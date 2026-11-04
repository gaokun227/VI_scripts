##!/bin/tcsh

set hh_list=(00) # 12)
set initial=20220901
set end=30
set int=1

set initial=20210820
set end=52
set int=1

set script = /ncrc/home1/Kun.Gao/tshield_vi_driver/overwrite_general.sh

set i=0
set x=0
while ($x < $end)
  set DATE = `date -d "$initial $i days" +%Y%m%d`

  foreach hh ($hh_list)
  set rundir1 = /lustre/f2/dev/Kun.Gao/tshield_vi/${DATE}.${hh}Z.C768r10n4_atl_vi_large.nh.32bit.non-mono.0h/rundir/
  set rundir2 = /lustre/f2/dev/Kun.Gao/tshield_vi/${DATE}.${hh}Z.C768r10n4_atl_vi.nh.32bit.non-mono.0h/rundir/

  set rst1_vi = $rundir1/RESTART_vi_sol2_e/
  set rst2 = $rundir2/RESTART/
  set rst2_vi = $rundir2/RESTART_vi_sol2_e/

  set file1 = ${rst1_vi}'/fv_core.res.nest02.tile7.nc'
  set file2 = ${rst1_vi}'/fv_tracer.res.nest02.tile7.nc'

  if (-f $file1  && -f $file2 && ! -d $rst2_vi ) then
     echo 'submitting overwrite job for' $DATE.$hh
     sbatch --job-name=overwrite_${DATE} --export=rst1_vi=${rst1_vi},rst2=${rst2},rst2_vi=${rst2_vi},ALL ${script} 
  endif

  end
  @ i = $i + $int
  @ x++
end
