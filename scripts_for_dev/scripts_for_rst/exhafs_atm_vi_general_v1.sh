#!/bin/bash
#SBATCH --output=/ncrc/home1/Kun.Gao/tshield_vi_driver/stdout/%x.o%j
#SBATCH --job-name=atm_vi
#SBATCH --partition=batch
#SBATCH --account=gfdl_W
#SBATCH --qos=urgent
#SBATCH --ntasks=8
#SBATCH --time=03:00:00
#SBATCH --cluster=c4

set -xe
ulimit

# ---> setting up work dir
#export vital_dir=/ncrc/home1/Kun.Gao/tshield_vi_driver/tc_vitals/processed/
#export rst_dir=/lustre/f2/dev/Kun.Gao/tshield_vi/20220920.00Z.C768r10n4_atl_vi_large.nh.32bit.non-mono.0h/rundir/
#export CDATE=2022092000
#export STORMID=07L

export WORKhafs=/lustre/f2/scratch/gfdl/Kun.Gao/tshield_vi_work/${CDATE}/${STORMID}
export COMhafsprior=${WORKhafs}/../../2020070100/00L # random dir; not needed at this point
export static_dir=/lustre/f2/dev/Kun.Gao/tshield_vi/static/
export rst_src_dir=$rst_dir/RESTART/
export rst_out_dir=$rst_dir/RESTART_vi/ 
export rst_work_dir=$WORKhafs/intercom/RESTART_init

rm -rf $WORKhafs
mkdir -p $WORKhafs
mkdir -p $WORKhafs/intercom/RESTART_init
mkdir -p $WORKhafs/intercom/atm_init

# tc files
cp $vital_dir/$CDATE/tcvitals.vi $WORKhafs/
cp $vital_dir/$CDATE/${STORMID}*atcfunix.all $WORKhafs/intercom/atm_init/

# nc files
export datetime=${CDATE:0:8}.${CDATE:8:2}0000
ln -sf ${rst_src_dir}/fv_core.res.nest02.nc          ${rst_work_dir}/${datetime}.fv_core.res.nc
ln -sf ${rst_src_dir}/fv_core.res.nest02.tile7.nc    ${rst_work_dir}/${datetime}.fv_core.res.tile1.nc
ln -sf ${rst_src_dir}/fv_tracer.res.nest02.tile7.nc  ${rst_work_dir}/${datetime}.fv_tracer.res.tile1.nc
ln -sf ${rst_src_dir}/fv_srf_wnd.res.nest02.tile7.nc ${rst_work_dir}/${datetime}.fv_srf_wnd.res.tile1.nc
ln -sf ${rst_src_dir}/phy_data.nest02.tile7.nc       ${rst_work_dir}/${datetime}.phy_data.nc
ln -sf ${rst_src_dir}/sfc_data.nest02.tile7.nc       ${rst_work_dir}/${datetime}.sfc_data.nc
ln -sf ${static_dir}/*                               ${rst_work_dir}

# <--- end setting up

export HOMEhafs=/ncrc/home1/Kun.Gao/hafs_tools/
export USHhafs=${HOMEhafs}/ush
export EXEChafs=${HOMEhafs}/sorc/hafs_tools.fd/exec_ref/
export FIXhafs=${HOMEhafs}/fix

source ${USHhafs}/hafs_pre_job.sh.inc > /dev/null 2>&1
module use ${HOMEhafs}/modulefiles
module load modulefile.hafs.gaea > /dev/null 2>&1
#module list

export vi_warm_start_vmax_threshold=${vi_warm_start_vmax_threshold:-20} # m/s
export vi_bogus_vmax_threshold=${vi_bogus_vmax_threshold:-100} # m/s
export vi_storm_env=${vi_storm_env:-init} # init: from gfs/gdas init; pert: from the same source for the storm perturbation
export vi_storm_relocation=${vi_storm_relocation:-yes}
export vi_storm_modification=${vi_storm_modification:-yes}
export vi_ajust_intensity=${vi_adjust_intensity:-yes}
export vi_ajust_size=${vi_adjust_size:-yes}
export crfactor=${crfactor:-1.0}

export deg_box1=${deg_box1:-30} #30
export deg_box2=${deg_box2:-41} #45

if [ ${vi_storm_modification} = yes ]; then
  initopt=0
else
  initopt=1
fi

APRUNC=${APRUNC:-"srun --ntasks=8"}
APRUNC1=${APRUNC1:-"srun --ntasks=1"}

# Utilities
export NCP=${NCP:-"/bin/cp"}
#export NMV=${NMV:-"/bin/mv"}
#export NLN=${NLN:-"/bin/ln -sf"}
export DATOOL=${DATOOL:-${EXEChafs}/hafs_datool.x}
PDY=`echo $CDATE | cut -c1-8`
cyc=`echo $CDATE | cut -c9-10`
yr=`echo $CDATE | cut -c1-4`
mn=`echo $CDATE | cut -c5-6`
dy=`echo $CDATE | cut -c7-8`
hh=`echo $CDATE | cut -c9-10`

export RESTARTinp=${RESTARTinp:-${COMhafsprior}/RESTART}
export INTCOMinit=${INTCOMinit:-${WORKhafs}/intercom/atm_init}
export RESTARTinit=${RESTARTinit:-${WORKhafs}/intercom/RESTART_init}
export RESTARTout=${RESTARTout:-${WORKhafs}/intercom/RESTART_vi}
export DATA=${DATA:-${WORKhafs}/atm_vi}

mkdir -p $INTCOMinit
mkdir -p $RESTARTout
mkdir -p $DATA
cd $DATA
cp ${WORKhafs}/tcvitals.vi .
tcvital=${DATA}/tcvitals.vi
vmax_vit=`cat ${tcvital} | cut -c68-69`

#===============================================================================
# Stage 1: Process current cycle's vortex  

if [ $vmax_vit -ge $vi_warm_start_vmax_threshold ]; then

  cd $DATA

  # prep
  work_dir=${DATA}/prep_init
  mkdir -p ${work_dir}
  cd ${work_dir}
  vortexradius=${deg_box1}
  res=0.02
  ${APRUNC} ${DATOOL} hafsvi_preproc --in_dir=${RESTARTinit} \
                                     --debug_level=11 --interpolation_points=4 \
                                     --infile_date=${CDATE:0:8}.${CDATE:8:2}0000 \
                                     --tcvital=${tcvital} \
                                     --vortexradius=${vortexradius} --res=${res} \
                                     --nestdoms=$((${nest_grids:-1}-1)) \
                                     --out_file=vi_inp_${vortexradius}deg${res/\./p}.bin
  if [[ ${nest_grids} -gt 1 ]]; then
    mv vi_inp_${vortexradius}deg${res/\./p}.bin vi_inp_${vortexradius}deg${res/\./p}.bin_grid01
    mv vi_inp_${vortexradius}deg${res/\./p}.bin_nest$(printf "%02d" ${nest_grids}) vi_inp_${vortexradius}deg${res/\./p}.bin
  fi
  vortexradius=${deg_box2}
  res=0.20
  ${APRUNC} ${DATOOL} hafsvi_preproc --in_dir=${RESTARTinit} \
                                     --debug_level=11 --interpolation_points=4 \
                                     --infile_date=${CDATE:0:8}.${CDATE:8:2}0000 \
                                     --tcvital=${tcvital} \
                                     --vortexradius=${vortexradius} --res=${res} \
                                     --nestdoms=$((${nest_grids:-1}-1)) \
                                     --out_file=vi_inp_${vortexradius}deg${res/\./p}.bin
  if [[ ${nest_grids} -gt 1 ]]; then
    mv vi_inp_${vortexradius}deg${res/\./p}.bin vi_inp_${vortexradius}deg${res/\./p}.bin_grid01
    mv vi_inp_${vortexradius}deg${res/\./p}.bin_nest$(printf "%02d" ${nest_grids}) vi_inp_${vortexradius}deg${res/\./p}.bin
  fi

  # create_trak and split
  work_dir=${DATA}/split_init
  mkdir -p ${work_dir}
  cd ${work_dir}
  # input
  ln -sf ${tcvital} fort.11
  if [ -e ${INTCOMinit}/${STORMID}.${CDATE}.trak.atcfunix.all ]; then
    ln -sf ${INTCOMinit}/${STORMID}.${CDATE}.trak.atcfunix.all ./trak.atcfunix.all
    grep "^.., ${STORMID:0:2}," trak.atcfunix.all > trak.atcfunix.tmp
  else
    touch trak.atcfunix.tmp
  fi
  ln -sf trak.atcfunix.tmp fort.12
  # output
  ln -sf ./trak.fnl.all fort.30

  ln -sf ${EXEChafs}/hafs_vi_create_trak_init.x ./
  time ./hafs_vi_create_trak_init.x ${STORMID}

  # split
  # input
  ln -sf ${tcvital} fort.11
  ln -sf ./trak.fnl.all fort.30
  ln -sf ../prep_init/vi_inp_${deg_box1}deg0p02.bin ./fort.26
  ln -sf ../prep_init/vi_inp_${deg_box2}deg0p20.bin ./fort.46
  if [ -s ../split_guess/storm_radius ]; then
    ln -sf ../split_guess/storm_radius ./fort.65
  fi
  # output
  ln -sf storm_env                     fort.56
  ln -sf rel_inform                    fort.52
  ln -sf vital_syn                     fort.55
  ln -sf storm_pert                    fort.71
  ln -sf storm_radius                  fort.85

  ln -sf ${EXEChafs}/hafs_vi_split.x ./
  gesfhr=${gesfhr:-6}
  # Warm start or cold start
  if [ -s fort.65 ]; then
    ibgs=1
    iflag_cold=0
  else
    ibgs=2
    iflag_cold=1
  fi
  echo ${gesfhr} $ibgs $vmax_vit $iflag_cold 1.0 | ./hafs_vi_split.x

  # anl_pert
  work_dir=${DATA}/anl_pert_init
  mkdir -p ${work_dir}
  cd ${work_dir}
  # input
  ln -sf ${tcvital} fort.11
  ln -sf ../split_init/storm_env fort.26
  ln -sf ../prep_init/vi_inp_${deg_box1}deg0p02.bin fort.46
  ln -sf ../split_init/storm_pert fort.71
  ln -sf ../split_init/storm_radius fort.65
  # output
  ln -sf storm_pert_new fort.58
  ln -sf storm_size_p fort.14
  ln -sf storm_sym fort.23

  ln -sf ${EXEChafs}/hafs_vi_anl_pert.x ./
  basin=${pubbasin2:-AL}
  initopt=${initopt:-0}
  echo 6 ${basin} ${initopt} | ./hafs_vi_anl_pert.x

#===============================================================================
# Stage 2: Correct the vortex and merge it back  

  # anl_storm
  work_dir=${DATA}/anl_storm
  mkdir -p ${work_dir}
  cd ${work_dir}

  if [ $vmax_vit -ge $vi_bogus_vmax_threshold ] && [ ! -s ../anl_pert_guess/storm_pert_new ] ; then
  # Bogus a storm if prior cycle does not exist and tcvital intensity >= vi_bogus_vmax_threshold (e.g., 33 m/s)

    pert=init
    senv=$pert
    # anl_bogus
    # input
    ln -sf ${tcvital} fort.11
    ln -sf ../split_${senv}/storm_env fort.26
    ln -sf ../prep_${pert}/vi_inp_${deg_box1}deg0p02.bin ./fort.36
    ln -sf ../prep_${pert}/vi_inp_${deg_box1}deg0p02.bin ./fort.46 #roughness
    ln -sf ../split_${pert}/storm_pert fort.61
    ln -sf ../split_${pert}/storm_radius fort.85

    ln -sf ${FIXhafs}/fix_vi/hafs_storm_axisy_47 fort.71
    ln -sf ${FIXhafs}/fix_vi/hafs_storm_axisy_47 fort.72
    ln -sf ${FIXhafs}/fix_vi/hafs_storm_axisy_47 fort.73
    ln -sf ${FIXhafs}/fix_vi/hafs_storm_axisy_47 fort.74
    ln -sf ${FIXhafs}/fix_vi/hafs_storm_30       fort.75
    ln -sf ${FIXhafs}/fix_vi/hafs_storm_30       fort.76
    ln -sf ${FIXhafs}/fix_vi/hafs_storm_30       fort.77
    ln -sf ${FIXhafs}/fix_vi/hafs_storm_axisy_47 fort.78

    # output
    ln -sf storm_anl_bogus                        fort.56

    ln -sf ${EXEChafs}/hafs_vi_anl_bogus.x ./
    basin=${pubbasin2:-AL}
    echo 6 ${basin} | ./hafs_vi_anl_bogus.x
    cp -p storm_anl_bogus storm_anl

  else
    # warm-start from prior cycle or cold start from global/parent model

    # anl_combine
    if [ $vmax_vit -ge $vi_warm_start_vmax_threshold ] && [ -s ../anl_pert_guess/storm_pert_new ] ; then
      pert=guess
    else
      pert=init
    fi
    if [ $vi_storm_env = init ] ; then
      senv=init
    else
      senv=$pert
    fi
    if [ $pert = init ] ; then
      gfs_flag=0
    else
      gfs_flag=6
    fi
    if [ $ENSDA = YES ]; then
      gfs_flag=1
    fi

    rm -f flag_file
    # input
    ln -sf ${tcvital} fort.11
    ln -sf ../split_${pert}/trak.atcfunix.tmp fort.12
    ln -sf ../split_${pert}/trak.fnl.all fort.30
    ln -sf ../anl_pert_${pert}/storm_size_p fort.14
    ln -sf ../anl_pert_${pert}/storm_sym fort.23
    ln -sf ../anl_pert_${pert}/storm_pert_new fort.71
    ln -sf ../split_${senv}/storm_env fort.26
    ln -sf ../prep_${pert}/vi_inp_${deg_box1}deg0p02.bin ./fort.46 #roughness

    # output
    ln -sf storm_env_new                 fort.36
    ln -sf storm_anl_combine             fort.56
 
    gesfhr=${gesfhr:-6}
    basin=${pubbasin2:-AL}
    gfs_flag=${gfs_flag:-6}
    initopt=${initopt:-0}
    ln -sf ${EXEChafs}/hafs_vi_anl_combine.x ./
    echo ${gesfhr} ${basin} ${gfs_flag} ${initopt} | ./hafs_vi_anl_combine.x
    if [ -s storm_anl_combine ]; then
      cp -p storm_anl_combine storm_anl
    fi

    # If the combined storm is weaker than the tcvital intensity, add a small
    # fraction of the composite storm to enhance the storm intensity so that it
    # matches the tcvital intensity
    if [ -s flag_file ] && [ -s storm_env_new ]; then
    # anl_enhance
    # input
    #ln -sf ${tcvital} fort.11
    #ln -sf ./flag_file flag_file
    ln -sf ../anl_pert_${pert}/storm_sym fort.23
    ln -sf storm_env_new fort.26
    ln -sf ../prep_${pert}/vi_inp_${deg_box1}deg0p02.bin ./fort.46 #roughness
    ln -sf ../split_${pert}/storm_radius fort.85

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

    basin=${pubbasin2:-AL}
    iflag_cold=${iflag_cold:-0}
    ln -sf ${EXEChafs}/hafs_vi_anl_enhance.x ./
    echo 6 ${basin} ${iflag_cold} | ./hafs_vi_anl_enhance.x
    cp -p storm_anl_enhance storm_anl

    fi
  fi

  if [ ! -s storm_anl ]; then
    echo "FATAL ERROR: failed to produce storm_anl"
    exit 1
  fi

  # Interpolate storm_anl back to HAFS restart files
  cd $DATA

  # post
  mkdir -p ${RESTARTout}
  if [ $senv = init ] ; then
    RESTARTdst=${RESTARTinit}
  else
    RESTARTdst=${RESTARTinp}
  fi
  mkdir -p $RESTARTdst

  # below are just hyperlinks
  ${NCP} -rp ${RESTARTdst}/${CDATE:0:8}.${CDATE:8:2}0000* ${RESTARTout}/
  ${NCP} -rp ${RESTARTdst}/atmos_static*.nc ${RESTARTout}/
  ${NCP} -rp ${RESTARTdst}/grid_*spec*.nc ${RESTARTout}/
  ${NCP} -rp ${RESTARTdst}/oro_data*.nc ${RESTARTout}/

  # copy over the two actual files (will be modified)
  rm ${RESTARTout}/${datetime}.fv_core.res.tile1.nc
  rm ${RESTARTout}/${datetime}.fv_tracer.res.tile1.nc
  ${NCP} ${rst_src_dir}/fv_core.res.nest02.tile7.nc    ${RESTARTout}/${datetime}.fv_core.res.tile1.nc
  ${NCP} ${rst_src_dir}/fv_tracer.res.nest02.tile7.nc  ${RESTARTout}/${datetime}.fv_tracer.res.tile1.nc

  for nd in $(seq 1 ${nest_grids})
  do

  ${APRUNC1} ${DATOOL} hafsvi_postproc --in_file=${DATA}/anl_storm/storm_anl \
                               --debug_level=11 --interpolation_points=4 \
                               --relaxzone=30 \
                               --infile_date=${CDATE:0:8}.${CDATE:8:2}0000 \
                               --nestdoms=$((${nd}-1)) \
                               --out_dir=${RESTARTout}
#                              [--relaxzone=50 (grids, default is 30) ]
#                              [--debug_level=10 (default is 1) ]
#                              [--interpolation_points=5 (default is 4, range 1-500) ]

  done
#===============================================================================

# copy modified restart files to tshield rundir 
# need to check hafsvi_postproc is successful

  module load cdo

  mkdir -p $WORKhafs/intercom/check
  cd $WORKhafs/intercom/check
  cdo selvar,u -sellevel,75 ${RESTARTdst}/${datetime}.fv_core.res.tile1.nc u_before.nc
  cdo selvar,u -sellevel,75 ${RESTARTout}/${datetime}.fv_core.res.tile1.nc u_after.nc
  cdo selvar,sphum -sellevel,75 ${RESTARTdst}/${datetime}.fv_tracer.res.tile1.nc sphum_before.nc
  cdo selvar,sphum -sellevel,75 ${RESTARTout}/${datetime}.fv_tracer.res.tile1.nc sphum_after.nc

  testok1=`cdo -diff u_before.nc u_after.nc | sed -n '/records differ$/p' | tr -s " " | cut -f2 -d" "`
  testok2=`cdo -diff sphum_before.nc sphum_after.nc | sed -n '/records differ$/p' | tr -s " " | cut -f2 -d" "`

  if [ ${testok1} -eq 1 ]  && [ ${testok2} -eq 1 ]; then
    mkdir -p $rst_out_dir
    echo 'VI went successfully'
    ${NCP} ${RESTARTout}/${datetime}.fv_core.res.tile1.nc   $rst_out_dir 
    ${NCP} ${RESTARTout}/${datetime}.fv_tracer.res.tile1.nc $rst_out_dir
    cd $rst_out_dir 
    mv ${datetime}.fv_tracer.res.tile1.nc fv_tracer.res.nest02.tile7.nc
    mv ${datetime}.fv_core.res.tile1.nc   fv_core.res.nest02.tile7.nc
  else
    echo 'VI did not work'
  fi

fi # end if [ $vmax_vit -ge $vi_warm_start_vmax_threshold]
 
exit
