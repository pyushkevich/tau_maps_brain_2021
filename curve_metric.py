import os
import numpy as np
import nibabel as nib
import matplotlib.pyplot as plt
from skimage import measure
import skimage.filters as flt
import skimage.morphology as morph
import scipy.interpolate as interp
import similaritymeasures as sim
import scipy.spatial.distance as sdist
import scipy.stats
import json
import sys
import svgwrite

def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

if __name__ == "__main__":

    if len(sys.argv) < 5:
        print("Wrong number of arguments")
        sys.exit(-1)

    # Load the data
    nii_mri = nib.load(sys.argv[1])
    nii_hist = nib.load(sys.argv[2])
    out_svg = sys.argv[3]
    out_json = sys.argv[4]
    mri= np.array(nii_mri.dataobj).squeeze()
    hist = np.array(nii_hist.dataobj).squeeze()

    # Extract contours from histology
    h_mask = morph.binary_erosion(hist > 20, morph.disk(2))
    h_cnt = measure.find_contours(hist, 60, mask=h_mask);
    if len(h_cnt) < 1:
        eprint("No contours in histology: %d" % (len(h_cnt),))
        sys.exit(-1)

    # Find the longest contour (this is weak)
    h_idx = list(map(len, h_cnt)).index(max(list(map(len, h_cnt))))

    # Find the label on this slice
    label = int(np.round(
        scipy.stats.mode(mri.flatten()[np.logical_and(mri.flatten() >= 0.5, mri.flatten() <= 4.5)]).mode[0]))
    m_flat = mri.flatten()

    # Extract contours from MRI
    m_mask = np.logical_and(
        np.logical_and(
            morph.binary_dilation(mri == label, morph.disk(9)),
            morph.binary_dilation(mri == 6, morph.disk(9))),
        morph.binary_erosion(mri != 5, morph.disk(9)))

    m_cnt = measure.find_contours(mri, (6 + label) / 2.0, mask=m_mask)
    if len(m_cnt) < 1:
        eprint("No contours in MRI: %d" % (len(m_cnt),))
        sys.exit(-1)

    # Find the longest contour (this is weak)
    m_idx = list(map(len, m_cnt)).index(max(list(map(len, m_cnt))))

    # Get the first part of each contour (assume there is only one)
    Xh,Xm=h_cnt[h_idx], m_cnt[m_idx]

    # Remap the contours to mm. 
    Ym=nii_mri.affine[:2, :2].dot(Xm.transpose()).transpose()+nii_mri.affine[:2, 3]
    Yh=nii_hist.affine[:2, :2].dot(Xh.transpose()).transpose()+nii_hist.affine[:2, 3]

    # Compute pointwise distance matrix
    D=sdist.cdist(Ym,Yh)
    dh,dm = np.amin(D,0), np.amin(D,1)

    # From the end of each curve, trim the points that match to the end of the other curve
    am,bm,ah,bh = 0,len(Ym)-1,0,len(Yh)-1

    while am < bm and (D[am, 0] == dm[am] or D[am,len(Yh)-1] == dm[am]):
        am = am + 1

    while bm > am and (D[bm, 0] == dm[bm] or D[bm, len(Yh) - 1] == dm[bm]):
        bm = bm - 1

    while ah < bh and (D[0, ah] == dh[ah] or D[len(Ym) - 1, ah] == dh[ah]):
        ah = ah + 1

    while bh > ah and (D[0, bh] == dh[bh] or D[len(Ym) - 1, bh] == dh[bh]):
        bh = bh - 1

    print("Clipping MRI by %d and %d, Histo by %d and %d points" % (am, len(Ym)-bm, ah, len(Yh)-bh))

    # Extract just the subcurves
    Ym_clip = Ym[range(am,bm+1),:]
    Yh_clip = Yh[range(ah,bh+1),:]
    D=sdist.cdist(Ym_clip,Yh_clip)
    dh,dm = np.amin(D,0), np.amin(D,1)

    # Compute some standard metrics
    mtx = {
        "label": label,
        "bde_median": np.mean((np.median(dh), np.median(dm))),
        "bde_mad": np.mean((np.mean(dh), np.mean(dm))),
        "bde_rms": np.sqrt(np.mean((np.mean(dh**2), np.mean(dm**2)))),
        "bde_hd95": np.mean((np.quantile(dh, 0.95), np.quantile(dm, 0.95))),
        "bde_hd": np.max((np.max(dh), np.max(dm))),
        "frechet" : sim.frechet_dist(Ym, Yh)
    }

    # Print the json
    with open(out_json, "w") as outfile:
        json.dump(mtx, outfile)

    # Ym = Ym_clip
    # Yh = Yh_clip

    # Generate a SVG of the curves for visualization
    dwg = svgwrite.Drawing(out_svg, size=(mri.shape[0], mri.shape[1]))

    print(am,bm,ah,bh)

    for i in range(1, am+1):
        dwg.add(dwg.line(start=(Xm[i - 1][0], Xm[i - 1][1]), end=(Xm[i][0], Xm[i][1]), stroke='yellow', stroke_width=2))
    for i in range(am+1, bm+1):
        dwg.add(dwg.line(start=(Xm[i - 1][0], Xm[i - 1][1]), end=(Xm[i][0], Xm[i][1]), stroke='orange', stroke_width=2))
    for i in range(bm+1, len(Ym)):
        dwg.add(dwg.line(start=(Xm[i - 1][0], Xm[i - 1][1]), end=(Xm[i][0], Xm[i][1]), stroke='yellow', stroke_width=2))

    for i in range(1, ah+1):
        dwg.add(dwg.line(start=(Xh[i - 1][0], Xh[i - 1][1]), end=(Xh[i][0], Xh[i][1]), stroke='yellow', stroke_width=2))
    for i in range(ah+1, bh+1):
        dwg.add(dwg.line(start=(Xh[i - 1][0], Xh[i - 1][1]), end=(Xh[i][0], Xh[i][1]), stroke='red', stroke_width=2))
    for i in range(bh+1, len(Yh)):
        dwg.add(dwg.line(start=(Xh[i - 1][0], Xh[i - 1][1]), end=(Xh[i][0], Xh[i][1]), stroke='yellow', stroke_width=2))

    dwg.save()

    sys.exit(0)







