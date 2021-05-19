#!/bin/bash
set -x -e

id=${1?}
svs=${2?}

# Configure gsutil
gcloud auth activate-service-account --key-file /var/secrets/google/key.json
gcloud config set project cfn-cluster-test

URLBASE="gs://mtl_histology/$id/histo_proc/$svs/preproc"

# Locate the x16 PNG
if ! pngfile=$(gsutil ls "$URLBASE/${svs}_x16.png"); then
  echo "Raw PNG file not found for $id $svs"
  exit -1
fi

# Locate the tiff
mkdir -p ./data
gsutil cp $pngfile ./data

# Run VIPS
MIDRES_PNG=./data/${svs}_x16.png
MIDRES_TIFF=./data/${svs}_x16.tiff
MIDRES_PTIFF=./data/${svs}_x16_pyramid.tiff
convert $MIDRES_PNG $MIDRES_TIFF
vips tiffsave $MIDRES_TIFF $MIDRES_PTIFF \
  --vips-progress --compression=deflate \
  --tile --tile-width=256 --tile-height=256 \
  --pyramid --bigtiff

# Upload
gsutil cp $MIDRES_PTIFF $URLBASE/
