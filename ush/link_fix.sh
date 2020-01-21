#!/bin/bash

#
#-----------------------------------------------------------------------
#
# This file defines a function that <need to complete>...
#
#-----------------------------------------------------------------------
#
function link_fix() {
#
#-----------------------------------------------------------------------
#
# Save current shell options (in a global array).  Then set new options
# for this script/function.
#
#-----------------------------------------------------------------------
#
  { save_shell_opts; set -u -x; } > /dev/null 2>&1
#
#-----------------------------------------------------------------------
#
# Get the full path to the file in which this script/function is located 
# (scrfunc_fp), the name of that file (scrfunc_fn), and the directory in
# which the file is located (scrfunc_dir).
#
#-----------------------------------------------------------------------
#
  local scrfunc_fp=$( readlink -f "${BASH_SOURCE[0]}" )
  local scrfunc_fn=$( basename "${scrfunc_fp}" )
  local scrfunc_dir=$( dirname "${scrfunc_fp}" )
#
#-----------------------------------------------------------------------
#
# Get the name of this function.
#
#-----------------------------------------------------------------------
#
  local func_name="${FUNCNAME[0]}"
#
#-----------------------------------------------------------------------
#
# Specify the set of valid argument names that this script/function can
# accept.  Then process the arguments provided to it (which should con-
# sist of a set of name-value pairs of the form arg1="value1", etc).
#
#-----------------------------------------------------------------------
#
  local valid_args=( \
"verbose" \
"file_group" \
"output_varname_res_in_filenames" \
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
# Declare local variables.
#
#-----------------------------------------------------------------------
#
  local valid_vals_verbose \
        valid_vals_file_group \
        fns \
        fps \
        run_task \
        sfc_climo_fields \
        num_fields \
        i \
        ii \
        res_prev \
        res \
        fp_prev \
        fp \
        fn \
        relative_or_null \
        cres \
        tmp \
        fns_sfc_climo_with_halo_in_fn \
        fns_sfc_climo_no_halo_in_fn \
        target \
        symlink
#
#-----------------------------------------------------------------------
#
# Set the valid values that various input arguments can take on and then
# ensure that the values passed in are one of these valid values.
#
#-----------------------------------------------------------------------
#
  valid_vals_verbose=( "TRUE" "FALSE" )
  check_var_valid_value "verbose" "valid_vals_verbose"

  valid_vals_file_group=( "grid" "orog" "sfc_climo" )
  check_var_valid_value "file_group" "valid_vals_file_group"
#
#-----------------------------------------------------------------------
#
# Create symlinks in the FIXsar directory pointing to the grid files.
# These symlinks are needed by the make_orog, make_sfc_climo, make_ic,
# make_lbc, and/or run_fcst tasks.
#
# Note that we check that each target file exists before attempting to 
# create symlinks.  This is because the "ln" command will create sym-
# links to non-existent targets without returning with a nonzero exit
# code.
#
#-----------------------------------------------------------------------
#
  print_info_msg "$verbose" "
Creating links in the FIXsar directory to the grid files..."
#
#-----------------------------------------------------------------------
#
# Create globbing patterns for grid, orography, and surface climatology
# files.
#
#-----------------------------------------------------------------------
#
  case "${file_group}" in
#
  "grid")
    fns=( \
"C*_mosaic.nc" \
"C*_grid.tile${TILE_RGNL}.halo${NH3}.nc" \
"C*_grid.tile${TILE_RGNL}.halo${NH4}.nc" \
        )
    fps=( "${fns[@]/#/${GRID_DIR}/}" )
    run_task="${RUN_TASK_MAKE_GRID}"
    ;;
#
  "orog")
    fns=( \
"C*_oro_data.tile${TILE_RGNL}.halo${NH0}.nc" \
"C*_oro_data.tile${TILE_RGNL}.halo${NH4}.nc" \
        )
    fps=( "${fns[@]/#/${OROG_DIR}/}" )
    run_task="${RUN_TASK_MAKE_OROG}"
    ;;
#
  "sfc_climo")
    sfc_climo_fields=( \
"facsf" \
"maximum_snow_albedo" \
"slope_type" \
"snowfree_albedo" \
"soil_type" \
"substrate_temperature" \
"vegetation_greenness" \
"vegetation_type" \
                     )
    num_fields=${#sfc_climo_fields[@]}
    fns=()
    for (( i=0; i<${num_fields}; i++ )); do
      ii=$((2*i))
      fns[$ii]="C*.${sfc_climo_fields[$i]}.tile${TILE_RGNL}.halo${NH0}.nc"
      fns[$ii+1]="C*.${sfc_climo_fields[$i]}.tile${TILE_RGNL}.halo${NH4}.nc"
    done
    fps=( "${fns[@]/#/${SFC_CLIMO_DIR}/}" )
    run_task="${RUN_TASK_MAKE_SFC_CLIMO}"
    ;;
#
  esac
#
#-----------------------------------------------------------------------
#
# Find all files matching the globbing patterns and make sure that they
# all have the same resolution (an integer) in their names.
#
#-----------------------------------------------------------------------
#
  i=0
  res_prev=""
  res=""
  fp_prev=""

  for fp in ${fps[@]}; do

    fn=$( basename $fp )
  
    res=$( printf "%s" $fn | sed -n -r -e "s/^C([0-9]*).*/\1/p" )
    if [ -z $res ]; then
      print_err_msg_exit "\
The resolution could not be extracted from the current file's name.  The
full path to the file (fp) is:
  fp = \"${fp}\"
This may be because fp contains the * globbing character, which would
imply that no files were found that match the globbing pattern specified
in fp."
    fi

    if [ $i -gt 0 ] && [ ${res} != ${res_prev} ]; then
      print_err_msg_exit "\
The resolutions (as obtained from the file names) of the previous and 
current file (fp_prev and fp, respectively) are different:
  fp_prev = \"${fp_prev}\"
  fp      = \"${fp}\"
Please ensure that all files have the same resolution."
    fi

    i=$((i+1))
    fp_prev="$fp"
    res_prev=${res}

  done
#
#-----------------------------------------------------------------------
#
# If the output variable name is not set to a null string, set it.  This
# variable is just the resolution extracted from the file names in the 
# specified file group.  Note that if the output variable name is not
# specified in the call to this function, the process_args function will
# set it to a null string, in which case no output variable will be set.
#
#-----------------------------------------------------------------------
#
  if [ ! -z "${output_varname_res_in_filenames}" ]; then
    eval ${output_varname_res_in_filenames}="$res"
  fi
#
#-----------------------------------------------------------------------
#
# Replace the * globbing character in the set of globbing patterns with 
# the resolution.  This will result in a set of (full paths to) specific
# files.
#
#-----------------------------------------------------------------------
#
  fps=( "${fps[@]/\*/$res}" )
#
#-----------------------------------------------------------------------
#
# In creating the various symlinks below, it is convenient to work in 
# the FIXsar directory.  We will change directory back to the original
# later below.
#
#-----------------------------------------------------------------------
#
  cd_vrfy "$FIXsar"
#
#-----------------------------------------------------------------------
#
# Use the set of full file paths generated above as the link targets to 
# create symlinks to these files in the FIXsar directory.
#
#-----------------------------------------------------------------------
#
  relative_or_null=""
  if [ "${run_task}" = "TRUE" ]; then
    relative_or_null="--relative"
  fi

  for fp in "${fps[@]}"; do
    if [ -f "$fp" ]; then
      ln_vrfy -sf ${relative_or_null} $fp .
    else
      print_err_msg_exit "\
Cannot create symlink because target file (fp) does not exist:
  fp = \"${fp}\""
    fi
  done
#
#-----------------------------------------------------------------------
#
# Set the C-resolution based on the resolution appearing in the file 
# names.
#
#-----------------------------------------------------------------------
#
  cres="C$res"
#
#-----------------------------------------------------------------------
#
# If considering grid files, create a symlink to the halo4 grid file
# that does not contain the halo size in its name.  This is needed by 
# the tasks that generate the initial and lateral boundary condition 
# files.
#
#-----------------------------------------------------------------------
#
  if [ "${file_group}" = "grid" ]; then
    target="${cres}_grid.tile${TILE_RGNL}.halo${NH4}.nc"
    symlink="${cres}_grid.tile${TILE_RGNL}.nc"
    ln_vrfy -sf $target $symlink
#
# The surface climatology file generation code looks for a grid file ha-
# ving a name of the form "C${GFDLgrid_RES}_tile7.halo4.nc" (i.e. the 
# resolution used in this file is that of the number of grid points per
# horizontal direction per tile, just like in the global model).  Thus,
# if we are running this code, if the grid is of GFDLgrid type, and if
# we are not using GFDLgrid_RES in filenames (i.e. we are using the 
# equivalent global uniform grid resolution instead), then create a 
# link whose name uses the GFDLgrid_RES that points to the link whose
# name uses the equivalent global uniform resolution.
#
    if [ "${RUN_TASK_MAKE_SFC_CLIMO}" = "TRUE" ] && \
       [ "${GRID_GEN_METHOD}" = "GFDLgrid" ] && \
       [ "${GFDLgrid_USE_GFDLgrid_RES_IN_FILENAMES}" = "FALSE" ]; then
      target="${cres}_grid.tile${TILE_RGNL}.halo${NH4}.nc"
      symlink="C${GFDLgrid_RES}_grid.tile${TILE_RGNL}.nc"
      ln_vrfy -sf $target $symlink
    fi

  fi
#
#-----------------------------------------------------------------------
#
# If considering surface climatology files, create symlinks to the sur-
# face climatology files that do not contain the halo size in their 
# names.  These are needed by the task that generates the initial condi-
# tion files.
#
#-----------------------------------------------------------------------
#
  if [ "${file_group}" = "sfc_climo" ]; then

    tmp=( "${sfc_climo_fields[@]/#/${cres}.}" )
    fns_sfc_climo_with_halo_in_fn=( "${tmp[@]/%/.tile${TILE_RGNL}.halo${NH4}.nc}" )
    fns_sfc_climo_no_halo_in_fn=( "${tmp[@]/%/.tile${TILE_RGNL}.nc}" )

    for (( i=0; i<${num_fields}; i++ )); do
      target="${fns_sfc_climo_with_halo_in_fn[$i]}"
      symlink="${fns_sfc_climo_no_halo_in_fn[$i]}"
      if [ -f "$target" ]; then
        ln_vrfy -sf $target $symlink
      else
        print_err_msg_exit "\
Cannot create symlink because target file (target) does not exist:
  target = \"${target}\""
      fi
    done
#
#-----------------------------------------------------------------------
#
# Change directory back to original one.
#
#-----------------------------------------------------------------------
#
    cd_vrfy -

  fi
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the start of this script/function.
#
#-----------------------------------------------------------------------
#
  { restore_shell_opts; } > /dev/null 2>&1

}
