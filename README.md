# Scripts for building a 3D atlas of tau burden from MRI and histology

## Data organization

For each subject/specimen, the following data are required:

* `input/[id]/mold_mri/mtl7t.nii.gz`
    
  this is the 7T MRI scan
   
* `input/[id]/mold_mri/contour_image.nii.gz`

  this is the level set segmentation of the scan (ITK-SNAP) -4 on the inside, +4 on the outside, 0 at the boundary
  
* `input/[id]/mold_mri/slitmold.nii.gz`

  this is the image of the 3D printed mold. 
  
* `input/[id]/mold_mri/holderrotation.mat`

  this is the rotation of the MRI into the mold space
    
