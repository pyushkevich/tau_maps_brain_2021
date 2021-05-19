#!/bin/bash
#$ -S /bin/bash
set -x -e

# Current slide list
ROOT=/data/picsl/pauly/tau_atlas
SLIDE_LIST_FILE=$ROOT/input/histology/slide_src.txt

# Tempdir
if [[ ! $TMPDIR ]]; then
  TMPDIR=/tmp/histology_$PPID
  mkdir -p $TMPDIR
fi

# SED commands to protect paths
SED_PROT_CMD="-e \"s/ /\\\ /g\" -e \"s/(/\\\(/g\" -e \"s/)/\\\)/g\""

# Code for a single file
function process_slide()
{
  LINE_NO=${1?}

  SLIDE_URL=$(cat $SLIDE_LIST_FILE | head -n $LINE_NO | tail -n 1)
  SLIDE_EXT=$(echo $SLIDE_URL | sed -e "s/.*\.//g")
  SLIDE_ID=$(echo $(basename "$SLIDE_URL") | sed -e "s/\.[a-z]*$//")
  WORK=$ROOT/input/histology/slides/$SLIDE_ID

  # Full size SVS file
  SVS=$TMPDIR/${SLIDE_ID}.${SLIDE_EXT}

  # Main output
  MRILIKE=$WORK/${SLIDE_ID}_mrilike.nii.gz
  TEARFIX=$WORK/${SLIDE_ID}_tearfix.nii.gz
  SUMMARY=$WORK/${SLIDE_ID}_thumbnail.tiff

  # Mid-resolution images
  MIDRES="$WORK/${SLIDE_ID}_x16.png"
  MIDRESDUMP="$WORK/${SLIDE_ID}_resolution.txt"

  # Quit if result exists
  ### if [[ -f $MRILIKE && -f $SUMMARY && -f $MIDRES && -f $TEARFIX ]]; then
  if [[ -f $MRILIKE && -f $SUMMARY && -f $MIDRES ]]; then
    return
  fi

  if [[ $2 == "check" ]]; then
    echo runme
    return
  fi

  # Create a work directory
  mkdir -p $WORK

  # Copy the slide into the local directory
  if [[ ! -f $SVS ]]; then
    scp "$SLIDE_URL" $SVS
  fi

  # Process the slide
  ### conda activate base -- seems to break
  if [[ ! -f $SUMMARY ]]; then
    $ROOT/scripts/process_raw_slide.py -i $SVS -s $WORK/${SLIDE_ID}
  fi

  if [[ ! -f $MIDRES ]]; then
    $ROOT/scripts/process_raw_slide.py -i $SVS -m $MIDRES > $MIDRESDUMP
  fi

  if [[ ! -f $MRILIKE ]]; then

    # Generate the MRI-like image
    $ROOT/scripts/process_raw_slide.py -i $SVS -o $MRILIKE -t 100

    # Apply additional fixup (negation and tear fix)
    c2d $MRILIKE -clip 0 1 -stretch 0 1 1 0 \
      -as G -thresh 0.2 inf 1 0 -as M \
      -push G -median 11x11 -times \
      -push G -push M -replace 0 1 1 0 -times \
      -add -o $TEARFIX

  fi

  rm -rf $SVS
}

function get_slide_list_single()
{
  read -r id server url fext <<<  "$@"
  FOLDER=$(echo "$url" | sed -e "s/ /\\\\ /g" -e "s/(/\\\\(/g" -e "s/)/\\\\)/g")
  ssh $server ls $FOLDER/*.${fext} | sed -e "s/ /\\\\ /g" -e "s/(/\\\\(/g" -e "s/)/\\\\)/g" \
    -e "s/^/$server:/"
}

# Generate a slide list
function gen_slide_list()
{
  REGEXP=$1

  mkdir -p $ROOT/input/histology

  local N_SRV=$(cat $ROOT/manifest/svs_source.txt | grep "$REGEXP" | wc -l)

  for ((i=1; i<=$N_SRV; i++)); do
    line=$(cat $ROOT/manifest/svs_source.txt | grep "$REGEXP" | head -n $i | tail -n 1)
    get_slide_list_single $line
  done > $SLIDE_LIST_FILE
}

# main loop
function main()
{
  # Read the optional ID selection
  IDPATTERN=$1

  # Generate a list of slides to process
  gen_slide_list $IDPATTERN

  N=$(cat $SLIDE_LIST_FILE | wc -l)
  
  for ((i=1;i<=$N;i++)); do
    if [[ $(process_slide $i check) == "runme" ]]; then
      qsub -j y -cwd -V -o $ROOT/dump -N "aperio_$i" \
        $0 process_slide $i
      sleep 30
    fi

  done
}

# Entrypoint
cmd=${1?}
shift 1
$cmd "$@"
