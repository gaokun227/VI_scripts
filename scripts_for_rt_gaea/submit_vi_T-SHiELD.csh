#!/bin/tcsh
module load python/3.9

set echo
set verbose
unlimit

# This script drives the VI-related workflow for the RT T-SHiELD
# It is triggerd by the IC creation script once ICs are generated

# If there are storms that need VI, this script will:
#  - create two TC text files to be used by VI
#  - launch the VI script

# === get the model initialization date&time from command-line argument
set CDATE = $1

if (! $?SLURM_JOB_QOS) then
  setenv USRDEF_QOS 'normal'
else
  setenv USRDEF_QOS $SLURM_JOB_QOS
endif

# === directory to be specified by the user

# vi code and scripts
set vi_base = ${HOME}/NGGPS/VI
cd ${vi_base} || exit 1

# ic files
set GRID = 'C768r10n4_atl_new'
#set ic_base = /gpfs/f5/gfdl_w/scratch/${USER}/SHiELD_INPUT/SHiELD_IC_v16/${GRID}/
set ic_base = /gpfs/f5/gfdl_w/proj-shared/${USER}/SHiELD_INPUT_DATA/variable.v202311/${GRID}/

# vi criteria (will be passed to python scripts that generated TC files)
set min_wind = 30.
set max_lat = 35.

# === specific dir and file name settings

# scripts
set vi_tool_dir = ${vi_base}/HAFS_tools/
set vi_driver_dir = ${vi_base}/VI_scripts/scripts_for_rt_gaea/
set vi_script = ${vi_driver_dir}/vi_T-SHiELD.sh

# tc files
set vital_base = ${vi_driver_dir}/tc_vitals/
set vital_dir_obs = ${vital_base}/observed_all/
set vital_dir_processed = ${vital_base}/processed/
set obs_vital = ${vital_dir_obs}/tcvitals_${CDATE}.txt # this is the obs vital at given time

# ics
set DATE = `echo ${CDATE} | cut -c1-8`
set hh = `echo ${CDATE} | cut -c9-10`
set ic_dir = ${ic_base}/${DATE}.${hh}Z_IC/
set ic_src_file = ${ic_dir}/gfs_data.tile7.nc # IC without VI
set nonomatch ic_dst_file=(${ic_dir}/gfs_data.tile7_vi_?.nc) # IC after VI

mkdir -p $vital_dir_obs
mkdir -p $vital_dir_processed

# === Step 1: prepare text files for VI
# this step will generate the two text files used by VI

set nonomatch vitfiles=(${vital_dir_processed}/${CDATE}/???/tcvitals.vi)
if ( ! -e $vitfiles[1] ) then

  # --- find if there is any ATL tc at the given time (using tcutil_multistorm_sort_xx.py)

  ${vi_tool_dir}/ush/tcutil_multistorm_sort_gfdl.py ${CDATE} L $min_wind $max_lat > tmpvit # select TCs
  more tmpvit
  grep -q -F "NHC" "tmpvit" && mv tmpvit ${obs_vital} || echo 'TC not found'
  rm -f tmpvit

  # --- if so, prepare the text files that can be used for VI (using prepare_tc_files.py)

  # -d: date          -> current date as CDATE
  # -w: min_wind      -> min Vmax for VI
  # -l: max_lat       -> max initial lat for VI
  # -i: ic_base       -> base dir for ic, e.g., '/lustre/f2/dev/gfdl/Kun.Gao/SHiELD_IC_v16/'+grid+'/'
  # -f: vital_file    -> obs vital messages as a txt file, e.g., vital_base+'observed_all/tcvitals_'+date+'.txt'
  # -o: vital_dir_out -> where processed tc txt files are saved, e.g., vital_base+'/processed/'

  if ( -f ${obs_vital} && -f ${ic_src_file} ) then
     # note the wind and lat criteria are duplicated in script below
     echo "VILOG: prepare_tc_files.py -d ${CDATE} -w $min_wind -l $max_lat -i $ic_base -f $obs_vital -o $vital_dir_processed"
     ${vi_driver_dir}/prepare_tc_files.py -d ${CDATE} -w $min_wind -l $max_lat -i $ic_base -f $obs_vital -o $vital_dir_processed
  else
    echo "VILOG: Not calling ${vi_driver_dir}/prepare_tc_files.py [obs_vital(${obs_vital}) and/or ic_src_file(${ic_src_file}) not available]"
  endif

endif

# === Step 2. trigger VI script

# tcvitals.vi can be used as a flag; if it exists for a given date&time, VI is needed for this case
set nonomatch vitfiles=(${vital_dir_processed}/${CDATE}/???/tcvitals.vi)
if ( -e $vitfiles[1] ) then

  /bin/ls -l ${vital_dir_processed}/${CDATE}/???/tcvitals.vi
  set STORMIDlist = `find ${vital_dir_processed}/${CDATE} -type f -name 'tcvitals.vi' -printf '%T@ %Tc %p\n' | sort -n | awk -F/ '{print $(NF-1)}' | tr '\n' ' '`

  if ( ! -e $ic_dst_file[1] ) then
    echo "VILOG: Submitting ${CDATE}, ${STORMIDlist}"
    sbatch --job-name=vi_dev_ic_${GRID}_${CDATE} --output=${ic_dir}/%x.out --export=NONE,CDATE=${CDATE},STORMIDlist="${STORMIDlist}" --qos ${USRDEF_QOS} ${vi_script}
  else
    exit 1
  endif

else # if VI not triggered, trigger forecast job from here

  # submit the forecast job
  echo 'VILOG: No need for VI; Submitting forecast job for' ${CDATE}
  set runscript = ${HOME}/NGGPS/T-SHiELD_rt2024/SHiELD_run/GAEA/submit_forecast.sh
  set runmode = 'realtime'
  ${runscript} -y "${CDATE}" -a 'gfdl_w' -m "${runmode}" -n 999

endif
