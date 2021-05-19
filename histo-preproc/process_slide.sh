#!/bin/bash
set -x -e

id=${1?}
svs=${2?}

# Configure gsutil
gcloud auth activate-service-account --key-file /var/secrets/google/key.json
gcloud config set project cfn-cluster-test

# Upload function
function upload_result() 
{
	out=${1?}
	REQUIRED=${2?}

	if [[ $REQUIRED -eq 1 && ! -f $out ]]; then
    echo "Failed to generate output $out"
    exit -1
	fi

  if [[ -f $out ]]; then
    if ! gsutil cp $out gs://mtl_histology/$id/histo_proc/${svs}/preproc/ ; then
      echo "Failed to upload results"
      exit -1
    fi
  fi
}

# Locate the SVS
if ! svsfile=$(gsutil ls "gs://mtl_histology/$id/histo_raw/${svs}.*"); then
  echo "Raw SVS file not found for $id $svs"
  exit -1
fi

# Download the SVS to a local file
mkdir -p ./data
gsutil cp $svsfile ./data

# Find the file
if ! svslocal=$(ls ./data/${svs}.*); then
  echo "Download failed for $id $svs $svsfile"
  exit -1
fi

# Check for levels, and if there is only one level, replace the
# image with a pyramid one
LEVELS=$(python process_raw_slide.py -i $svslocal -l)
if [[ $LEVELS -le 1 ]]; then
  mkdir -p ./data/fixflat
  mv $svslocal ./data/fixflat
  svsflat=$(ls ./data/fixflat/${svs}.*)

  # Write pyramid
	if ! vips tiffsave $svsflat $svslocal \
		--vips-progress --compression=jpeg --Q=80 \
		--tile --tile-width=256 --tile-height=256 \
		--pyramid --bigtiff; then
		echo "Failed to generate pyramid tif/svs"
		exit -1
  fi

  if ! gsutil cp $svslocal $svsfile; then
    echo "Failed to upload pyramid tif/svs"
    exit -1
  fi
fi

# Extract a thumbnail and a 40um resolution image
SUMMARY=./data/${svs}_thumbnail.tiff
RGB_NIFTI=./data/${svs}_rgb_40um.nii.gz
METADATA=./data/${svs}_metadata.json
LABELFILE=./data/${svs}_label.tiff
python process_raw_slide.py -i $svslocal -s ./data/${svs}

# Mid-resolution image
MIDRES_PNG=./data/${svs}_x16.png
MIDRES_TIFF=./data/${svs}_x16.tiff
MIDRES_PTIFF=./data/${svs}_x16_pyramid.tiff
RESFILE=./data/${svs}_resolution.txt

# Create the mid-resolution image
python process_raw_slide.py -i $svslocal -m $MIDRES_PNG > $RESFILE

# Generate a pyramid TIFF file of the x16
convert $MIDRES_PNG $MIDRES_TIFF
vips tiffsave $MIDRES_TIFF $MIDRES_PTIFF \
  --vips-progress --compression=deflate \
  --tile --tile-width=256 --tile-height=256 \
  --pyramid --bigtiff

# Upload the results generated so far
upload_result $SUMMARY 1
upload_result $RGB_NIFTI 1
upload_result $METADATA 1
upload_result $MIDRES_PNG 1
upload_result $MIDRES_PTIFF 1
upload_result $RESFILE 1
upload_result $LABELFILE 0
