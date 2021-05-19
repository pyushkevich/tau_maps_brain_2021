#!/bin/bash
RSYNC_ROOT=10.150.13.41:/volume1/Histology/UCLM2018/frombox_20180702
ROOT=/data/picsl/pauly/tau_atlas/exp02/HNL_11_15

# Repeat for the three blocks imaged
for block in HR3p HR2a HR4a; do

  # Copy files
  mkdir -p $ROOT/blockface/${block}/raw $ROOT/blockface/${block}/trim $ROOT/blockface/${block}/thumb
  rsync -av $RSYNC_ROOT/*${block}*.jpg $ROOT/blockface/${block}/raw/

  # Trim
  for fn in $(ls $ROOT/blockface/${block}/raw | grep 'jpg$'); do

    # c2d -mcs $ROOT/blockface/${block}/raw/$fn -foreach -region 1488x1040 772x636 -endfor \
    #    -type uchar -oo $ROOT/blockface/${block}/trim/rgb%02d_${fn}

    c3d -verbose $ROOT/blockface/${block}/trim/rgb??_${fn} \
      -tile z -stretch 0.5% 98% 0 255 -clip 0 255 -slice z 0:-1 \
      -type uchar -omc $ROOT/blockface/${block}/thumb/thumb_${fn/.jpg/.png}

  done

  continue

  # Flip?
  FLIP=$(echo $block | cut -c 4-4 | sed -e "s/a//" -e "s/p/-flip z/")

  c3d \
    -verbose \
    $ROOT/blockface/${block}/trim/rgb00*.jpg -tile z -popas R \
    $ROOT/blockface/${block}/trim/rgb01*.jpg -tile z -popas G \
    $ROOT/blockface/${block}/trim/rgb02*.jpg -tile z -popas B \
    -push R -push G -push B \
    -foreach -spacing 0.083x0.083x0.05mm $FLIP -endfor \
    -omc $ROOT/blockface/HNL_11_15_${block}_blockface.nii.gz

done
