#!/bin/bash
ROOT=/data/picsl/pauly/tau_atlas
SRC=/data/jux/sravikumar/atlasPHG2019/

for fn in $(cat $ROOT/manifest/hiresmri_src.txt | awk '{print $1}'); do
  ML=$(find $SRC/preproc -name "${fn}*_axisalign_phgsegshape_multilabel.nii.gz")
  MAT=$(find $SRC/inputs -name "${fn}*_raw_to_axisalign.mat")

  echo $ML
  echo $MAT
  if [[ -f $ML && -f $MAT ]]; then

    WDIR=$ROOT/manual/$fn/mri_seg/
    mkdir -p $WDIR

    cp $ML $WDIR/${fn}_axisalign_phgsegshape_multilabel.nii.gz
    cp $MAT $WDIR/${fn}_raw_to_axisalign.mat

  else

    echo "MISSING FILES FOR $fn"

  fi


  done
