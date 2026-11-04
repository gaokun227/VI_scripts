##!/bin/tcsh

set hh_list=(00 12)
set initial=20200901
set end=1200
set int=1

set i=0
set x=0
while ($x < $end)

  set DATE = `date -d "$initial $i days" +%Y%m%d`

  foreach hh ($hh_list)
  # check if model restart files and processed vitial files exist
  set ic_dir = /lustre/f2/dev/Kun.Gao/SHiELD_IC_v16/C768r10n4_atl_new/${DATE}.${hh}Z_IC/
  set ic_src_file = ${ic_dir}/gfs_data.tile7_vi.nc
  set ic_dst_file = ${ic_dir}/gfs_data.tile7_vi_v1.nc

  if ( -f $ic_src_file && ! -f $ic_dst_file ) then
     echo 'handling ', $ic_src_file
     mv $ic_src_file $ic_dst_file
  endif

  end
  @ i = $i + $int
  @ x++
end
