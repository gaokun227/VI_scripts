#!/bin/bash
#SBATCH --output=/ncrc/home1/Kun.Gao/vi_driver/stdout/%x.o%j
#SBATCH --job-name=vi_on_ic
#SBATCH --partition=batch
#SBATCH --account=gfdl_W
##SBATCH --qos=urgent
#SBATCH --ntasks=1
#SBATCH --time=03:00:00
#SBATCH --cluster=c5

#set -xe
set -x # for C5

ulimit

#===============================================================================
# setting up

export version=v3
export exec=exec_vi_ic_${version}
#export CDATE=2022092000
#export STORMID=07L

# -- vi options
export zind_str=29 # 28 - same as v1
export deg_box1=10
export deg_box2=10
export res_box1=0.02
export res_box2=0.20

export nest_grids=0 # ndom=nestdoms+1
export basin=AL
export initopt=0
export gfs_flag=0
export gesfhr=6 # basically useless; only useful in setting the value for item in split.f
export ibgs=2 # cold start
export iflag_cold=1 # cold start

# -- data dir
export vital_dir=/ncrc/home1/Kun.Gao/vi_driver/tc_vitals/processed_ic/ # !!!
export ic_base_dir=/lustre/f2/dev/gfdl/Kun.Gao/SHiELD_IC_v16/C768r10n4_atl_new/
export grid_dir=${ic_base_dir}/INPUT/
export ic_dir_src=${ic_base_dir}/${CDATE:0:8}.${CDATE:8:2}Z_IC/
export ic_dir_dst=${ic_dir_src}
export ic_file_ori=${ic_dir_src}/gfs_data.tile7.nc
export ic_file_dst=${ic_dir_dst}/gfs_data.tile7_vi_${version}.nc

# -- work dir
export work_dir_base=/lustre/f2/scratch/gfdl/Kun.Gao/tshield_vi_work_ic_${version}/
export work_dir=${work_dir_base}/${CDATE}/${STORMID}
export work_dir_ic=${work_dir}/data/ic/
export work_dir_vital=${work_dir}/data/vital/
export work_dir_vi=${work_dir}/atm_vi/

# -- code dir
export HOMEhafs=/ncrc/home1/Kun.Gao/hafs_tools/
export USHhafs=${HOMEhafs}/ush
export EXEChafs=${HOMEhafs}/sorc/hafs_tools.fd/${exec}/
export FIXhafs=${HOMEhafs}/fix

export APRUNC="srun --ntasks=8"
export APRUNC1="srun --ntasks=1"
export DATOOL=${EXEChafs}/hafs_datool.x

# -- activating or deactivating certain steps
export do_pre=1
export do_split=1
export do_pert=1
export do_combine=1
export do_enhance=1
export do_post=1

rm -rf $work_dir
mkdir -p $work_dir
mkdir -p $work_dir_ic
mkdir -p $work_dir_vital
mkdir -p $work_dir_vi

#===============================================================================
# main program starts now 

source ${USHhafs}/hafs_pre_job.sh.inc > /dev/null 2>&1
module use ${HOMEhafs}/modulefiles
module load modulefile.hafs.gaea_c5 > /dev/null 2>&1
#module list

#===============================================================================
# prepare data 

# tc files
cp $vital_dir/$CDATE/tcvitals.vi                 $work_dir_vital/
cp $vital_dir/$CDATE/${STORMID}*atcfunix.all     $work_dir_vital/

# prepare ic files
ln -sf ${grid_dir}/grid_spec.nest02.tile7.nc     ${work_dir_ic}/grid_spec.nc
ln -sf ${ic_dir_src}/gfs_ctrl.nc                 ${work_dir_ic}/gfs_ctrl.nc
ln -sf ${ic_dir_src}/sfc_data.tile7.nc           ${work_dir_ic}/sfc_data.nc
ln -sf ${ic_dir_src}/gfs_data.tile7.nc           ${work_dir_ic}/gfs_data.nc

tcvital=${work_dir_vital}/tcvitals.vi
vmax_vit=`cat ${tcvital} | cut -c68-69`

#===============================================================================
# preprocessing: prepare files for VI

if [ ${do_pre} -gt 0 ]; then

  # --- part 1
  # 1) remove top few layers (VI code do not support layers more than 121)
  # 2) change c-grid winds to a-grid winds
  ic_file_for_vi=${work_dir_ic}/gfs_data_for_vi.nc # next step expects 'gfs_data_for_vi.nc'
  rm -rf $ic_file_for_vi

  ${APRUNC1} ${DATOOL} hafsvi_create_nc --in_dir=${work_dir_ic} \
                                        --zsel=${zind_str} \
                                        --out_file=${ic_file_for_vi}
  # --- part 2
  # select data in a small box

  prep_dir=${work_dir_vi}/prep_init
  mkdir -p ${prep_dir}

  cd ${prep_dir}

  vortexradius=${deg_box1}
  res=${res_box1}
  ${APRUNC1} ${DATOOL} hafsvi_preproc_ic --in_dir=${work_dir_ic} \
                                     --debug_level=11 --interpolation_points=4 \
                                     --infile_date=${CDATE:0:8}.${CDATE:8:2}0000 \
                                     --tcvital=${tcvital} \
                                     --vortexradius=${vortexradius} --res=${res} \
                                     --nestdoms=${nest_grids} \
                                     --out_file=vi_inp_${vortexradius}deg${res/\./p}.bin
  vortexradius=${deg_box2}
  res=${res_box2}
  ${APRUNC1} ${DATOOL} hafsvi_preproc_ic --in_dir=${work_dir_ic} \
                                     --debug_level=11 --interpolation_points=4 \
                                     --infile_date=${CDATE:0:8}.${CDATE:8:2}0000 \
                                     --tcvital=${tcvital} \
                                     --vortexradius=${vortexradius} --res=${res} \
                                     --nestdoms=${nest_grids} \
                                     --out_file=vi_inp_${vortexradius}deg${res/\./p}.bin
fi


#===============================================================================
# VI steps 

work_dir_split=${work_dir_vi}/split_init/
work_dir_pert=${work_dir_vi}/anl_pert_init/
work_dir_combine=${work_dir_vi}/anl_storm/

# --- 1. split step

if [ ${do_split} -gt 0 ]; then

  rm -rf ${work_dir_split}
  mkdir -p ${work_dir_split}
  cd ${work_dir_split}	

  # 1.1 -- create_trak
  # input
  ln -sf ${tcvital} fort.11
  if [ -e ${work_dir_vital}/${STORMID}.${CDATE}.trak.atcfunix.all ]; then
    ln -sf ${work_dir_vital}/${STORMID}.${CDATE}.trak.atcfunix.all ./trak.atcfunix.all
    grep "^.., ${STORMID:0:2}," trak.atcfunix.all > trak.atcfunix.tmp
  else
    touch trak.atcfunix.tmp
  fi
  ln -sf trak.atcfunix.tmp fort.12
  # output
  ln -sf ./trak.fnl.all fort.30

  ln -sf ${EXEChafs}/hafs_vi_create_trak_init.x ./
  ./hafs_vi_create_trak_init.x ${STORMID}

  # -- 1.2 split

  # input
  ln -sf ${tcvital} fort.11
  ln -sf ./trak.fnl.all fort.30
  ln -sf ../prep_init/vi_inp_${deg_box1}deg0p02.bin ./fort.26
  ln -sf ../prep_init/vi_inp_${deg_box2}deg0p20.bin ./fort.46
  # output
  ln -sf storm_env                     fort.56
  ln -sf rel_inform                    fort.52
  ln -sf vital_syn                     fort.55
  ln -sf storm_pert                    fort.71
  ln -sf storm_radius                  fort.85

  ln -sf ${EXEChafs}/hafs_vi_split.x ./
  echo ${gesfhr} $ibgs $vmax_vit $iflag_cold 1.0 | ./hafs_vi_split.x 

  # KGao - check if command executed successfully
  if [ $? -eq 0 ]; then
    echo "=== VI split step executed successfully"
  else
    echo "=== VI split step failed"
    exit 1
  fi

fi

# --- 2. anl_pert step

if [ ${do_pert} -gt 0 ]; then

  rm -rf ${work_dir_pert}
  mkdir -p ${work_dir_pert}
  cd ${work_dir_pert}

  # input
  ln -sf ${tcvital} fort.11
  ln -sf ../prep_init/vi_inp_${deg_box1}deg0p02.bin fort.46

  ln -sf ${work_dir_split}/storm_env fort.26
  ln -sf ${work_dir_split}/storm_pert fort.71
  ln -sf ${work_dir_split}/storm_radius fort.65
  # output
  ln -sf storm_pert_new fort.58
  ln -sf storm_size_p fort.14
  ln -sf storm_sym fort.23

  ln -sf ${EXEChafs}/hafs_vi_anl_pert.x ./
  echo 6 ${basin} ${initopt} | ./hafs_vi_anl_pert.x 
  # KGao - check if command executed successfully
  if [ $? -eq 0 ]; then
    echo "=== VI anl_pert step executed successfully"
  else 
    echo "=== VI anl_pert step failed"
    exit 1
  fi
fi

# --- 3. anl_combine step

if [ ${do_combine} -gt 0 ]; then

  rm -rf ${work_dir_combine}
  mkdir -p ${work_dir_combine}
  cd ${work_dir_combine}

  # input
  ln -sf ${tcvital} fort.11
  ln -sf ../prep_init/vi_inp_${deg_box1}deg0p02.bin ./fort.46 #roughness

  ln -sf ${work_dir_split}/trak.atcfunix.tmp fort.12
  ln -sf ${work_dir_split}/trak.fnl.all fort.30
  ln -sf ${work_dir_split}/storm_env fort.26
  ln -sf ${work_dir_split}/storm_radius fort.85 # filter domain mean radius

  ln -sf ${work_dir_pert}/storm_size_p fort.14
  ln -sf ${work_dir_pert}/storm_sym fort.23
  ln -sf ${work_dir_pert}/storm_pert_new fort.71

  # output
  # storm_env_new: env + stretched tc
  ln -sf storm_env_new                 fort.36
  ln -sf storm_anl_combine             fort.56

  ln -sf ${EXEChafs}/hafs_vi_anl_combine.x ./
  echo ${gesfhr} ${basin} ${gfs_flag} ${initopt} | ./hafs_vi_anl_combine.x
  # KGao - check if command executed successfully
  if [ $? -eq 0 ]; then
    echo "=== VI anl_combine step executed successfully"
  else 
    echo "=== VI anl_combine step failed"
    exit 1
  fi

  if [ -s storm_anl_combine ]; then
    cp -p storm_anl_combine storm_anl
  fi
fi

# --- 4. anl_enhance step 

if [ ${do_enhance} -gt 0 ]; then
  
  cd ${work_dir_combine}
	
  if [ -s storm_env_new ]; then

    # input
    #ln -sf ../prep_init/vi_inp_${deg_box1}deg0p02.bin ./fort.46 #roughness
    ln -sf ${work_dir_pert}/storm_sym fort.23
    ln -sf storm_env_new fort.26 # from anl_combine step

    ln -sf ${FIXhafs}/fix_vi/hafs_storm_axisy_47 fort.71
    ln -sf ${FIXhafs}/fix_vi/hafs_storm_axisy_47 fort.72
    ln -sf ${FIXhafs}/fix_vi/hafs_storm_axisy_47 fort.73
    ln -sf ${FIXhafs}/fix_vi/hafs_storm_axisy_47 fort.74
    ln -sf ${FIXhafs}/fix_vi/hafs_storm_30       fort.75
    ln -sf ${FIXhafs}/fix_vi/hafs_storm_30       fort.76
    ln -sf ${FIXhafs}/fix_vi/hafs_storm_30       fort.77
    ln -sf ${FIXhafs}/fix_vi/hafs_storm_axisy_47 fort.78

    # output
    ln -sf storm_anl_enhance                     fort.56

    ln -sf ${EXEChafs}/hafs_vi_anl_enhance.x ./
    echo 6 ${basin} ${iflag_cold} | ./hafs_vi_anl_enhance.x
    # KGao - check if command executed successfully
    if [ $? -eq 0 ]; then
      echo "=== VI anl_enhance step executed successfully"
    else 
      echo "=== VI anl_enhance step failed"
      exit 1
    fi
    cp -p storm_anl_enhance storm_anl
  fi

fi


#===============================================================================
# postprocessing

if [ ${do_post} -gt 0 ]; then

  # --- part 1:  merge the data in the selected box back to the whole domain 
  cp ${ic_file_for_vi} ${work_dir_ic}/gfs_data_after_vi.nc
  ${APRUNC1} ${DATOOL} hafsvi_postproc_ic --in_file=${work_dir_vi}/anl_storm/storm_anl \
                               --debug_level=11 --interpolation_points=4 \
                               --relaxzone=30 \
                               --infile_date=${CDATE:0:8}.${CDATE:8:2}0000 \
                               --nestdoms=${nest_grids} \
                               --out_dir=${work_dir_ic}
#                              [--relaxzone=50 (grids, default is 30) ]
#                              [--debug_level=10 (default is 1) ]
#                              [--interpolation_points=5 (default is 4, range 1-500) ]

 # --- part 2: update source ic file 
 # update var adjusted by VI (wind increment on a-grid will be remapped on to c-grid) 
 # here we put the final-adjusted IC file in the dst dir directly 
 cp $ic_file_ori ${work_dir_ic}/gfs_data_vi.nc 
 ${APRUNC1} ${DATOOL} hafsvi_update_nc --in_dir=${work_dir_ic} \
                                       --zsel=${zind_str} \
                                       --out_file=${work_dir_ic}/gfs_data_vi.nc

 # --- step 3: check
 # if ic files after VI differs from ori file, then VI was successfully 
 module load cdo
 mkdir -p $work_dir/data/check
 cd $work_dir/data/check
 cdo selvar,u_w -sellevel,128 ${work_dir_ic}/gfs_data.nc u_before.nc
 cdo selvar,u_w -sellevel,128 ${work_dir_ic}/gfs_data_vi.nc u_after.nc
 cdo selvar,sphum -sellevel,128 ${work_dir_ic}/gfs_data.nc sphum_before.nc
 cdo selvar,sphum -sellevel,128 ${work_dir_ic}/gfs_data_vi.nc sphum_after.nc

 testok1=`cdo -diff u_before.nc u_after.nc | sed -n '/records differ$/p' | tr -s " " | cut -f2 -d" "`
 testok2=`cdo -diff sphum_before.nc sphum_after.nc | sed -n '/records differ$/p' | tr -s " " | cut -f2 -d" "`

 if [ ${testok1} -eq 1 ]  && [ ${testok2} -eq 1 ]; then
    echo 'VI went successfully'
    cp ${work_dir_ic}/gfs_data_vi.nc ${ic_file_dst} 
 else
    echo 'VI did not work'
 fi

fi

