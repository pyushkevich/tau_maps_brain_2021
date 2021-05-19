#!/bin/bash
ROOT=${1?}
OUTDIR=${2?}

for id in $(ls $ROOT/work); do
  if [[ -d $ROOT/work/$id/historeg ]]; then
    for block in $(ls $ROOT/work/$id/historeg); do
      bdir=$ROOT/work/$id/historeg/$block/affine_x16
      if [[ -d $bdir ]]; then
        mkdir -p $OUTDIR/$id/$block
        n=0
        m=0
        for fn in $(ls $bdir | grep '.png$'); do
          if [[ -f $bdir/${fn/.png/.mat} ]]; then
            n=$((n+1))
            # cp -av $bdir/$fn $bdir/${fn/.png/.mat} $OUTDIR/$id/$block
          fi
          m=$((m+1))
        done
        echo $id $block $m $n
      fi
    done
  fi
done
