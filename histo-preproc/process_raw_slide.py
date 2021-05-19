#!/usr/bin/env python
from __future__ import print_function
import openslide
import numpy as np
import os, time, math, sys
import getopt
import parse
import SimpleITK as sitk
import json

# Little function to round numbers up to closest divisor of d
def round_up(x, d):
    return int(math.ceil(x * 1.0 / d) * d)

# This little function computes the means of image tiles. No smoothing is performed
def tile_means(img, tile_size):
    b=np.mean(img.reshape(img.shape[0],-1,tile_size),axis=2)
    c=np.mean(b.reshape(-1,tile_size,b.shape[1]),axis=1)
    return c

# Read spacing from an OpenSlide
# Get the image spacing from the header, in mm units
def get_spacing(slide):
    (sx, sy) = (0.0, 0.0)
    if 'openslide.mpp-x' in slide.properties:
        sx = float(slide.properties['openslide.mpp-x']) / 1000.0
        sy = float(slide.properties['openslide.mpp-y']) / 1000.0
    elif 'openslide.comment' in slide.properties:
        for z in slide.properties['openslide.comment'].split('\n'):
            r = parse.parse('Resolution = {} um', z)
            if r is not None:
                sx = float(r[0]) / 1000.0
                sy = float(r[0]) / 1000.0
    # If there is no spacing, throw exception
    if sx == 0.0 or sy == 0.0:
        raise Exception('No spacing information in image')
    return (sx, sy)


# Main function
def process_svs(p):

    # If only asking to see the number of levels, do that
    if p['check_levels'] is True:
        try:
            slide=openslide.OpenSlide(p['in_img'])
            print(slide.level_count)
        except:
            print(-1)
        return

    # Read the slide first
    slide=openslide.OpenSlide(p['in_img'])

    # If we just want summaries, do that
    if len(p['summary']):
        # The simple thumbnail
        img = slide.get_thumbnail((1000,1000))
        img.save(p['summary'] + '_thumbnail.tiff')

        # The NIFTI thumbnail with fixed resolution
        (sx,sy) = get_spacing(slide)

        # Determine the dimensions of the thumbnail to achieve desired
        # resolution of 0.04x0.04mm
        wx = round_up(slide.dimensions[0] * sx / 0.04, 1)
        wy = round_up(slide.dimensions[1] * sy / 0.04, 1)

        # Get the thumbnail from the image at this resolution
        idata = np.asarray(slide.get_thumbnail((wx, wy)))
        (wwx, wwy) = (idata.shape[1], idata.shape[0])

        # Recompute the spacing using the actual size of image
        ssx = (sx * slide.dimensions[0]) / wwx
        ssy = (sy * slide.dimensions[1]) / wwy

        # Save as a NIFTI
        res = sitk.GetImageFromArray(idata, True)
        res.SetSpacing((ssx, ssy))
        sitk.WriteImage(res, p['summary'] + '_rgb_40um.nii.gz')

        # Save dimensions info to a JSON file
        with open(p['summary'] + "_metadata.json", "wt") as fp:
            json.dump({
                "dimensions": slide.dimensions,
                "level_count": slide.level_count,
                "level_dimensions": slide.level_dimensions,
                "level_downsamples": slide.level_downsamples,
                "spacing": (sx,sy) }, fp);

        # Get the label
        if 'label' in slide.associated_images:
            img = slide.associated_images['label']
            img.save(p['summary'] + '_label.tiff')

    if len(p['out_x16']):

        # Requested x16 middle-resolution image. The middle resolution images
        # can be generated using openslide very easily
        best_lev = 0
        for lev in range(slide.level_count):
          dsam=int(slide.level_downsamples[lev] + 0.5)
          if dsam <= 16:
            best_lev = lev

        # Downsample at this level
        image=slide.read_region((0,0), best_lev, slide.level_dimensions[best_lev])
        image.save(p['out_x16'])

        # Print slide information
        print("Level dimensions: ", slide.level_dimensions)
        print("Level downsamples: ", slide.level_downsamples)

# Usage
def usage(exit_code):
    print('process_raw_slide -i <input_svs> -o <output> -m <out_x16> [-t tile_size]')
    sys.exit(exit_code)
    
# Main
def main(argv):
    # Initial parameters
    p = {'in_img' : '', 
         'out_img' : '', 
         'summary' : '',
         'out_x16' : '',
         'tile_size' : 100,
         'check_levels' : False}

    # Read options
    try:
        opts, args = getopt.getopt(argv, "hi:o:t:s:m:l")
    except getopt.GetoptError:
        usage(2)

    for opt,arg in opts:
        if opt == '-h':
            usage(0)
        elif opt == '-i':
            p['in_img'] = arg
        elif opt == '-o':
            p['out_img'] = arg
        elif opt == '-s':
            p['summary'] = arg
        elif opt == '-m':
            p['out_x16'] = arg
        elif opt == '-t':
            p['tile_size'] = int(arg)
        elif opt == '-l':
            p['check_levels'] = True


    # Run the main code
    process_svs(p)

if __name__ == "__main__":
    main(sys.argv[1:])
