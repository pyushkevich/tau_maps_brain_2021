#!/bin/bash

# Read local configuration (ROOT)
if [[ $TAU_ATLAS_ROOT ]]; then
  . $TAU_ATLAS_ROOT/scripts/env.sh
else
  . "$(dirname $0)/env.sh"
fi

# The script directory where script files are located
SDIR=${ROOT?}/scripts

# The directory with manifest files
MDIR=${ROOT?}/manifest

# PATH
PATH=$ROOT/bin:$PATH

# Main directories
mkdir -p $ROOT/dump

# Make sure there is a tmpdir
if [[ ! $TMPDIR ]]; then
  TMPDIR=/tmp/recon_${PPID}
  mkdir -p $TMPDIR
fi

# Limit threads per CPU
if [[ $SLURM_NPROCS ]]; then
  NSLOTS=$SLURM_NPROCS
fi


