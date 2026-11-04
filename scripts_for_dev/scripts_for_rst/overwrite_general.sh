#!/bin/bash
#SBATCH --output=/ncrc/home1/Kun.Gao/tshield_vi_driver/stdout/%x.o%j
#SBATCH --job-name=overwrite_rst
#SBATCH --partition=batch
#SBATCH --account=gfdl_W
#SBATCH --qos=urgent
#SBATCH --ntasks=1
#SBATCH --time=03:00:00
#SBATCH --cluster=c3

set -xe

rm -rf $rst2_vi
mkdir -p $rst2_vi
cp $rst2/fv_core.res.nest02.tile7.nc  $rst2_vi
cp $rst2/fv_tracer.res.nest02.tile7.nc $rst2_vi

module load PythonEnv-noaa/1.5.0
python /ncrc/home1/Kun.Gao/tshield_vi_driver/do_overwrite.py -a $rst1_vi -b $rst2_vi 

exit
