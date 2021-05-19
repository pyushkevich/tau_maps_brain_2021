#!/bin/bash
ROOT=/data/picsl/pauly/tau_atlas
SAMPERBLOCK=4

<<'SKIP'
for fn in $(ls $ROOT/work/*/blockface/*/*blockface.nii.gz); do
  for ((i=0;i<$SAMPERBLOCK;i++)); do

    SLICE=$((RANDOM % 100))
    OUTFN="/tmp/$(basename $fn .nii.gz)_s${i}.nii.gz"

    echo $fn $i
    c3d -mcs $fn -foreach -slice z ${SLICE}% -endfor -omc $OUTFN

  done
done
SKIP

# Create output directory
mkdir -p $ROOT/manual/common/bf_train
c3d -verbose -mcs /tmp/*blockface*_s?.nii.gz \
  -foreach -pad-to 512x512x1 0 -endfor \
  -foreach-comp 3 -tile z -endfor \
  -omc $ROOT/manual/common/bf_train/bf_train.nii.gz
