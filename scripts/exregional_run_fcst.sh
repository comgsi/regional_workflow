#!/bin/bash
#
#-----------------------------------------------------------------------
#
# Source the variable definitions file and the bash utility functions.
#
#-----------------------------------------------------------------------
#
. ${GLOBAL_VAR_DEFNS_FP}
. $USHDIR/source_util_funcs.sh
. $USHDIR/set_FV3nml_ens_stoch_seeds.sh
#
#-----------------------------------------------------------------------
#
# Source other necessary files.
#
#-----------------------------------------------------------------------
#
. $USHDIR/create_model_configure_file.sh
. $USHDIR/create_diag_table_file.sh
#
#-----------------------------------------------------------------------
#
# Save current shell options (in a global array).  Then set new options
# for this script/function.
#
#-----------------------------------------------------------------------
#
{ save_shell_opts; set -u +x; } > /dev/null 2>&1
#
#-----------------------------------------------------------------------
#
# Get the full path to the file in which this script/function is located 
# (scrfunc_fp), the name of that file (scrfunc_fn), and the directory in
# which the file is located (scrfunc_dir).
#
#-----------------------------------------------------------------------
#
scrfunc_fp=$( readlink -f "${BASH_SOURCE[0]}" )
scrfunc_fn=$( basename "${scrfunc_fp}" )
scrfunc_dir=$( dirname "${scrfunc_fp}" )
#
#-----------------------------------------------------------------------
#
# Print message indicating entry into script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
Entering script:  \"${scrfunc_fn}\"
In directory:     \"${scrfunc_dir}\"

This is the ex-script for the task that runs a forecast with FV3 for the
specified cycle.
========================================================================"
#
#-----------------------------------------------------------------------
#
# Specify the set of valid argument names for this script/function.  
# Then process the arguments provided to this script/function (which 
# should consist of a set of name-value pairs of the form arg1="value1",
# etc).
#
#-----------------------------------------------------------------------
#
valid_args=( \
"cdate" \
"cycle_type" \
"cycle_subtype" \
"cycle_dir" \
"gridspec_dir" \
"ensmem_indx" \
"slash_ensmem_subdir" \
"NWGES_BASEDIR" \
"RESTART_HRS" \
)
process_args valid_args "$@"
#
#-----------------------------------------------------------------------
#
# For debugging purposes, print out values of arguments passed to this
# script.  Note that these will be printed out only if VERBOSE is set to
# TRUE.
#
#-----------------------------------------------------------------------
#
print_input_args valid_args
#
#-----------------------------------------------------------------------
#
# Load modules.
#
#-----------------------------------------------------------------------
#
case $MACHINE in

  "WCOSS2")
    ulimit -s unlimited
    ulimit -a
#    export OMP_PROC_BIND=true
    export OMP_NUM_THREADS=2
    export OMP_STACKSIZE=1G
#    export OMP_PLACES=cores
    export MPICH_ABORT_ON_ERROR=1
    export MALLOC_MMAP_MAX_=0
    export MALLOC_TRIM_THRESHOLD_=134217728
    export FORT_FMT_NO_WRAP_MARGIN=true
    export MPICH_REDUCE_NO_SMP=1
    export FOR_DISABLE_KMP_MALLOC=TRUE
    export FI_OFI_RXM_RX_SIZE=40000
    export FI_OFI_RXM_TX_SIZE=40000
    export MPICH_OFI_STARTUP_CONNECT=1
    export MPICH_OFI_VERBOSE=1
    export MPICH_OFI_NIC_VERBOSE=1
    #ncores=$(( NNODES_RUN_FCST*PPN_RUN_FCST))
    ncores=${PE_MEMBER01}
    APRUN="mpiexec -n ${ncores} -ppn ${PPN_RUN_FCST} --cpu-bind core --depth ${OMP_NUM_THREADS}"
    ;;

  "HERA")
    ulimit -s unlimited
    ulimit -a
    APRUN="srun"
    OMP_NUM_THREADS=2
    ;;

  "ORION")
    ulimit -s unlimited
    ulimit -a
    APRUN="srun"
    OMP_NUM_THREADS=1
    ;;

  "JET")
    ulimit -s unlimited
    ulimit -a
    APRUN="srun  --mem=0"
    if [ "${PREDEF_GRID_NAME}" == "RRFS_NA_3km" ]; then
      OMP_NUM_THREADS=4
    else
      OMP_NUM_THREADS=2
    fi
    ;;

  "ODIN")
    module list
    ulimit -s unlimited
    ulimit -a
    APRUN="srun -n ${PE_MEMBER01}"
    ;;

  "CHEYENNE")
    module list
    nprocs=$(( NNODES_RUN_FCST*PPN_RUN_FCST ))
    APRUN="mpirun -np $nprocs"
    ;;

  "STAMPEDE")
    module list
    APRUN="ibrun -np ${PE_MEMBER01}"
    ;;

  *)
    print_err_msg_exit "\
Run command has not been specified for this machine:
  MACHINE = \"$MACHINE\"
  APRUN = \"$APRUN\""
    ;;

esac
#
#-----------------------------------------------------------------------
#
# Set the forecast run directory.
#
#-----------------------------------------------------------------------
#
run_dir="${cycle_dir}"
#
#-----------------------------------------------------------------------
#
# Create links in the INPUT subdirectory of the current run directory to
# the grid and (filtered) orography files.
#
#-----------------------------------------------------------------------
#
print_info_msg "$VERBOSE" "
Creating links in the INPUT subdirectory of the current run directory to
the grid and (filtered) orography files ..."


# Create links to fix files in the FIXLAM directory.


cd_vrfy ${run_dir}/INPUT

relative_or_null=""

# Symlink to mosaic file with a completely different name.
target="${FIXLAM}/${CRES}${DOT_OR_USCORE}mosaic.halo${NH3}.nc" # must use *mosaic.halo3.nc
symlink="grid_spec.nc"
if [ -f "${target}" ]; then
  ln_vrfy -sf ${relative_or_null} $target $symlink
else
  print_err_msg_exit "\
Cannot create symlink because target does not exist:
  target = \"$target\""
fi

## Symlink to halo-3 grid file with "halo3" stripped from name.
#target="${FIXLAM}/${CRES}${DOT_OR_USCORE}grid.tile${TILE_RGNL}.halo${NH3}.nc"
#if [ "${RUN_TASK_MAKE_SFC_CLIMO}" = "TRUE" ] && \
#   [ "${GRID_GEN_METHOD}" = "GFDLgrid" ] && \
#   [ "${GFDLgrid_USE_GFDLgrid_RES_IN_FILENAMES}" = "FALSE" ]; then
#  symlink="C${GFDLgrid_RES}${DOT_OR_USCORE}grid.tile${TILE_RGNL}.nc"
#else
#  symlink="${CRES}${DOT_OR_USCORE}grid.tile${TILE_RGNL}.nc"
#fi

# Symlink to halo-3 grid file with "halo3" stripped from name.
mosaic_fn="grid_spec.nc"
grid_fn=$( get_charvar_from_netcdf "${mosaic_fn}" "gridfiles" )

target="${FIXLAM}/${grid_fn}"
symlink="${grid_fn}"
if [ -f "${target}" ]; then
  ln_vrfy -sf ${relative_or_null} $target $symlink
else
  print_err_msg_exit "\
Cannot create symlink because target does not exist:
  target = \"$target\""
fi

# Symlink to halo-4 grid file with "${CRES}_" stripped from name.
#
# If this link is not created, then the code hangs with an error message
# like this:
#
#   check netcdf status=           2
#  NetCDF error No such file or directory
# Stopped
#
# Note that even though the message says "Stopped", the task still con-
# sumes core-hours.
#
target="${FIXLAM}/${CRES}${DOT_OR_USCORE}grid.tile${TILE_RGNL}.halo${NH4}.nc"
symlink="grid.tile${TILE_RGNL}.halo${NH4}.nc"
if [ -f "${target}" ]; then
  ln_vrfy -sf ${relative_or_null} $target $symlink
else
  print_err_msg_exit "\
Cannot create symlink because target does not exist:
  target = \"$target\""
fi



relative_or_null=""

# Symlink to halo-0 orography file with "${CRES}_" and "halo0" stripped from name.
target="${FIXLAM}/${CRES}${DOT_OR_USCORE}oro_data.tile${TILE_RGNL}.halo${NH0}.nc"
symlink="oro_data.nc"
if [ -f "${target}" ]; then
  ln_vrfy -sf ${relative_or_null} $target $symlink
else
  print_err_msg_exit "\
Cannot create symlink because target does not exist:
  target = \"$target\""
fi

#
# Symlink to halo-4 orography file with "${CRES}_" stripped from name.
#
# If this link is not created, then the code hangs with an error message
# like this:
#
#   check netcdf status=           2
#  NetCDF error No such file or directory
# Stopped
#
# Note that even though the message says "Stopped", the task still con-
# sumes core-hours.
#
target="${FIXLAM}/${CRES}${DOT_OR_USCORE}oro_data.tile${TILE_RGNL}.halo${NH4}.nc"
symlink="oro_data.tile${TILE_RGNL}.halo${NH4}.nc"
if [ -f "${target}" ]; then
  ln_vrfy -sf ${relative_or_null} $target $symlink
else
  print_err_msg_exit "\
Cannot create symlink because target does not exist:
  target = \"$target\""
fi

#
# If using the FV3_HRRR or FV3_RAP physics suites, there are two files 
# (that contain statistics of the orography) that are needed by the gravity 
# wave drag parameterization in that suite.  Below, create symlinks to these 
# files in the run directory.  Note that the symlinks must have specific names 
# that the FV3 model is hardcoded to recognize, and those are the names 
# we use below.
#
if [ "${CCPP_PHYS_SUITE}" = "FV3_HRRR" ] || \
   [ "${CCPP_PHYS_SUITE}" = "FV3_RAP" ]  || \
   [ "${CCPP_PHYS_SUITE}" = "FV3_GFS_v15_thompson_mynn_lam3km" ]; then


  fileids=( "ss" "ls" )
  for fileid in "${fileids[@]}"; do
    target="${FIXLAM}/${CRES}${DOT_OR_USCORE}oro_data_${fileid}.tile${TILE_RGNL}.halo${NH0}.nc"
    symlink="oro_data_${fileid}.nc"
    if [ -f "${target}" ]; then
      ln_vrfy -sf ${relative_or_null} $target $symlink
    else
      print_err_msg_exit "\
Cannot create symlink because target does not exist:
  target = \"${target}\"
  symlink = \"${symlink}\""
    fi
  done

fi


#
#-----------------------------------------------------------------------
#
# The FV3 model looks for the following files in the INPUT subdirectory
# of the run directory:
#
#   gfs_data.nc
#   sfc_data.nc
#   gfs_bndy*.nc
#   gfs_ctrl.nc
#
# Some of these files (gfs_ctrl.nc, gfs_bndy*.nc) already exist, but
# others do not.  Thus, create links with these names to the appropriate
# files (in this case the initial condition and surface files only).
#
#-----------------------------------------------------------------------
#
print_info_msg "$VERBOSE" "
Creating links with names that FV3 looks for in the INPUT subdirectory
of the current run directory (run_dir), where
  run_dir = \"${run_dir}\"
..."

BKTYPE=1    # cold start using INPUT
if [ -r ${run_dir}/INPUT/coupler.res ] ; then
  BKTYPE=0  # cycling using RESTART
fi
print_info_msg "$VERBOSE" "
The forecast has BKTYPE $BKTYPE (1:cold start ; 0 cycling)"

cd_vrfy ${run_dir}/INPUT
#ln_vrfy -sf gfs_data.tile${TILE_RGNL}.halo${NH0}.nc gfs_data.nc
#ln_vrfy -sf sfc_data.tile${TILE_RGNL}.halo${NH0}.nc sfc_data.nc

relative_or_null=""

n_iolayouty=$(($IO_LAYOUT_Y-1))
list_iolayout=$(seq 0 $n_iolayouty)

if [ ${BKTYPE} -eq 1 ]; then
  target="gfs_data.tile${TILE_RGNL}.halo${NH0}.nc"
else
  target="fv_core.res.tile1.nc"
fi
symlink="gfs_data.nc"
if [ -f "${target}.0000" ]; then
  for ii in ${list_iolayout}
  do
    iii=$(printf %4.4i $ii)
    if [ -f "${target}.${iii}" ]; then
      ln_vrfy -sf ${relative_or_null} $target.${iii} $symlink.${iii}
    else
      print_err_msg_exit "\
      Cannot create symlink because target does not exist:
      target = \"$target.$iii\""
    fi
  done
else
  if [ -f "${target}" ]; then
    ln_vrfy -sf ${relative_or_null} $target $symlink
  else
    print_err_msg_exit "\
    Cannot create symlink because target does not exist:
    target = \"$target\""
  fi
fi

if [ ${BKTYPE} -eq 1 ]; then
  target="sfc_data.tile${TILE_RGNL}.halo${NH0}.nc"
  symlink="sfc_data.nc"
  if [ -f "${target}" ]; then
    ln_vrfy -sf ${relative_or_null} $target $symlink
  else
    print_err_msg_exit "\
    Cannot create symlink because target does not exist:
    target = \"$target\""
  fi
else
  if [ -f "sfc_data.nc.0000" ] || [ -f "sfc_data.nc" ]; then
    print_info_msg "$VERBOSE" "
    sfc_data.nc is available at INPUT directory"
  else
    print_err_msg_exit "\
    sfc_data.nc is not available for cycling"
  fi
fi

#
if [ "${DO_SMOKE_DUST}" = "TRUE" ]; then
  ln_vrfy -snf  ${FIX_SMOKE_DUST}/${PREDEF_GRID_NAME}/dust12m_data.nc  ${run_dir}/INPUT/dust12m_data.nc
  ln_vrfy -snf  ${FIX_SMOKE_DUST}/${PREDEF_GRID_NAME}/emi_data.nc      ${run_dir}/INPUT/emi_data.nc
  yyyymmddhh=${cdate:0:10}
  echo ${yyyymmddhh}
  if [ ${cycle_type} == "spinup" ]; then
    smokefile=${NWGES_BASEDIR}/RAVE_INTP/SMOKE_RRFS_data_${yyyymmddhh}00_spinup.nc
  else
    smokefile=${NWGES_BASEDIR}/RAVE_INTP/SMOKE_RRFS_data_${yyyymmddhh}00.nc
  fi
  echo "try to use smoke file=",${smokefile}
  if [ -f ${smokefile} ]; then
    ln_vrfy -snf ${smokefile} ${run_dir}/INPUT/SMOKE_RRFS_data.nc
  else
    ln_vrfy -snf ${FIX_SMOKE_DUST}/${PREDEF_GRID_NAME}/dummy_24hr_smoke.nc ${run_dir}/INPUT/SMOKE_RRFS_data.nc
    echo "smoke file is not available, use dummy_24hr_smoke.nc instead"
  fi
fi
#
#-----------------------------------------------------------------------
#
# Create links in the current run directory to fixed (i.e. static) files
# in the FIXam directory.  These links have names that are set to the
# names of files that the forecast model expects to exist in the current
# working directory when the forecast model executable is called (and
# that is just the run directory).
#
#-----------------------------------------------------------------------
#
cd_vrfy ${run_dir}

print_info_msg "$VERBOSE" "
Creating links in the current run directory (run_dir) to fixed (i.e.
static) files in the FIXam directory:
  FIXam = \"${FIXam}\"
  run_dir = \"${run_dir}\""

relative_or_null=""

regex_search="^[ ]*([^| ]+)[ ]*[|][ ]*([^| ]+)[ ]*$"
num_symlinks=${#CYCLEDIR_LINKS_TO_FIXam_FILES_MAPPING[@]}
for (( i=0; i<${num_symlinks}; i++ )); do

  mapping="${CYCLEDIR_LINKS_TO_FIXam_FILES_MAPPING[$i]}"
  symlink=$( printf "%s\n" "$mapping" | \
             sed -n -r -e "s/${regex_search}/\1/p" )
  target=$( printf "%s\n" "$mapping" | \
            sed -n -r -e "s/${regex_search}/\2/p" )

  symlink="${run_dir}/$symlink"
  target="$FIXam/$target"
  if [ -f "${target}" ]; then
    ln_vrfy -sf ${relative_or_null} $target $symlink
  else
    print_err_msg_exit "\
  Cannot create symlink because target does not exist:
    target = \"$target\""
  fi

done

ln_vrfy -sf ${relative_or_null} ${FIXam}/optics_??.dat ${run_dir}
ln_vrfy -sf ${relative_or_null} ${FIXam}/aeroclim.m??.nc ${run_dir}
#
#-----------------------------------------------------------------------
#
# If running this cycle/ensemble member combination more than once (e.g.
# using rocotoboot), remove any time stamp file that may exist from the
# previous attempt.
#
#-----------------------------------------------------------------------
#
cd_vrfy ${run_dir}
rm_vrfy -f time_stamp.out
#
#-----------------------------------------------------------------------
#
# Create links in the current run directory to cycle-independent (and
# ensemble-member-independent) model input files in the main experiment
# directory.
#
#-----------------------------------------------------------------------
#
print_info_msg "$VERBOSE" "
Creating links in the current run directory to cycle-independent model
input files in the main experiment directory..."

relative_or_null=""

ln_vrfy -sf ${relative_or_null} ${DATA_TABLE_FP} ${run_dir}
ln_vrfy -sf ${relative_or_null} ${FIELD_TABLE_FP} ${run_dir}
ln_vrfy -sf ${relative_or_null} ${NEMS_CONFIG_FP} ${run_dir}
ln_vrfy -sf ${relative_or_null} ${NEMS_YAML_FP} ${run_dir}

#
# Determine if running stochastic physics for the specified cycles in CYCL_HRS_STOCH
#
STOCH="FALSE"
if [ "${DO_ENSEMBLE}" = TRUE ] && ([ "${DO_SPP}" = TRUE ] || [ "${DO_SPPT}" = TRUE ] || [ "${DO_SHUM}" = TRUE ] \
  || [ "${DO_SKEB}" = TRUE ] || [ "${DO_LSM_SPP}" =  TRUE ]); then
   for cyc_start in "${CYCL_HRS_STOCH[@]}"; do
     if [ ${HH} -eq ${cyc_start} ]; then 
       STOCH="TRUE"
     fi
   done
fi

if [ ${BKTYPE} -eq 0 ]; then
  # cycling, using namelist for cycling forecast
  if [ "${STOCH}" == "TRUE" ]; then
    cp_vrfy ${FV3_NML_RESTART_STOCH_FP} ${run_dir}/${FV3_NML_FN}
   else
    cp_vrfy ${FV3_NML_RESTART_FP} ${run_dir}/${FV3_NML_FN}
  fi
else
  if [ -f "INPUT/cycle_surface.done" ]; then
  # namelist for cold start with surface cycle
    cp_vrfy ${FV3_NML_CYCSFC_FP} ${run_dir}/${FV3_NML_FN}
  else
  # cold start, using namelist for cold start
    if [ "${STOCH}" == "TRUE" ]; then
      cp_vrfy ${FV3_NML_STOCH_FP} ${run_dir}/${FV3_NML_FN}
     else
      cp_vrfy ${FV3_NML_FP} ${run_dir}/${FV3_NML_FN}
    fi
  fi
fi

if [ "${STOCH}" == "TRUE" ]; then
  cp ${run_dir}/${FV3_NML_FN} ${run_dir}/${FV3_NML_FN}_base
  set_FV3nml_ens_stoch_seeds cdate="$cdate" || print_err_msg_exit "\
 Call to function to create the ensemble-based namelist for the current 
 cycle's (cdate) run directory (run_dir) failed: 
   cdate = \"${cdate}\"
   run_dir = \"${run_dir}\""
fi
#
#-----------------------------------------------------------------------
#
# Call the function that creates the model configuration file within each
# cycle directory.
#
#-----------------------------------------------------------------------
#
create_model_configure_file \
  cdate="$cdate" \
  cycle_type="$cycle_type" \
  cycle_subtype="$cycle_subtype" \
  run_dir="${run_dir}" \
  nthreads=${OMP_NUM_THREADS:-1} \
  restart_hrs="${RESTART_HRS}" || print_err_msg_exit "\
Call to function to create a model configuration file for the current
cycle's (cdate) run directory (run_dir) failed:
  cdate = \"${cdate}\"
  run_dir = \"${run_dir}\""

#
#-----------------------------------------------------------------------
#
# Call the function that creates the model configuration file within each
# cycle directory.
#
#-----------------------------------------------------------------------
#
create_diag_table_file \
  run_dir="${run_dir}" || print_err_msg_exit "\
  Call to function to create a diag table file for the current.
cycle's (cdate) run directory (run_dir) failed:
  run_dir = \"${run_dir}\""

#
#-----------------------------------------------------------------------
#
export KMP_AFFINITY=${KMP_AFFINITY:-scatter}
export KMP_AFFINITY=scatter
export OMP_NUM_THREADS=${OMP_NUM_THREADS:-1} #Needs to be 1 for dynamic build of CCPP with GFDL fast physics, was 2 before.
export OMP_STACKSIZE=${OMP_STACKSIZE:-1024m}

#
#-----------------------------------------------------------------------
#
# If INPUT/phy_data.nc exists, convert it from NetCDF4 to NetCDF3
# (happens for cycled runs, not cold-started)
#
#-----------------------------------------------------------------------
#
if [[ -f phy_data.nc ]] ; then
  echo "convert phy_data.nc from NetCDF4 to NetCDF3"
  cd INPUT
  rm -f phy_data.nc3 phy_data.nc4
  cp -fp phy_data.nc phy_data.nc4
  if ( ! time ( module purge ; module load intel szip hdf5 netcdf nco ; module list ; set -x ; ncks -3 --64 phy_data.nc4 phy_data.nc3) ) ; then
    mv -f phy_data.nc4 phy_data.nc
    rm -f phy_data.nc3
    echo "NetCDF 4=>3 conversion failed. :-( Continuing with NetCDF 4 data."
  else
    mv -f phy_data.nc3 phy_data.nc
  fi
  cd ..
fi
#
#-----------------------------------------------------------------------
#
# Run the FV3-LAM model.  Note that we have to launch the forecast from
# the current cycle's directory because the FV3 executable will look for
# input files in the current directory.  Since those files have been
# staged in the cycle directory, the current directory must be the cycle
# directory (which it already is).
#
#-----------------------------------------------------------------------
#
# Copy the executable to the run directory.
if [ -f ${FV3_EXEC_FP} ]; then
   print_info_msg "$VERBOSE" "
  Copying the fv3lam  executable to the run directory..."
  cp_vrfy ${FV3_EXEC_FP} ${run_dir}/ufs_model
else
  print_err_msg_exit "\
 The GSI executable specified in FV3_EXEC_FP does not exist:
   FV3_EXEC_FP = \"$FV3_EXEC_FP\"
 Build FV3LAM and rerun."
fi

$APRUN ${run_dir}/ufs_model || print_err_msg_exit "\
Call to executable to run FV3-LAM forecast returned with nonzero exit
code."
#
#-----------------------------------------------------------------------
#
# Print message indicating successful completion of script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
FV3 forecast completed successfully!!!

Exiting script:  \"${scrfunc_fn}\"
In directory:    \"${scrfunc_dir}\"
========================================================================"
#
#-----------------------------------------------------------------------
#
# Save grid_spec files for restart subdomain.
#
#-----------------------------------------------------------------------
#
if [ ${BKTYPE} -eq 1 ] && [ ${n_iolayouty} -ge 1 ]; then
  for ii in ${list_iolayout}
  do
    iii=$(printf %4.4i $ii)
    if [ -f "grid_spec.nc.${iii}" ]; then
      cp_vrfy grid_spec.nc.${iii} ${gridspec_dir}/fv3_grid_spec.${iii}
    else
      print_err_msg_exit "\
      Cannot create symlink because target does not exist:
      target = \"grid_spec.nc.$iii\""
    fi
  done
fi
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the beginning of this script/func-
# tion.
#
#-----------------------------------------------------------------------
#
{ restore_shell_opts; } > /dev/null 2>&1

