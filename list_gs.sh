#!/bin/bash
for url in $( gsutil ls gs://mtl_histology/${1?}/histo_raw/*.tif); do
  sld=$(basename $url .tif)
  echo $sld | grep _TAU_ | awk -F_ '{printf "%s,Tau,%s,%d,9\n",$0,$2,$4}'
  echo $sld | grep _NISSL_ | awk -F_ '{printf "%s,NISSL,%s,%d,10\n",$0,$2,$4}'
done
