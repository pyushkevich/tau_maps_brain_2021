#!/usr/bin/env Rscript
library("optparse")
library('oro.nifti');
library('methods');
library('MASS')

# Read the arguments
option_list = list(
   make_option(c("-M", "--manifest"), type="character", default=NULL, 
               help="Manifest file name. File must have 4 columns for multichannel image, mask, target and output", 
               metavar="filename"),
   make_option(c("--sfg"), type="integer", default=500, 
               help="Number of samples per slide from the masked region (default: 500)", metavar="int"),
   make_option(c("--sbg"), type="integer", default=100, 
               help="Number of samples per slide from the background region (default: 100)", metavar="int")
); 

opt_parser = OptionParser(option_list=option_list);
opt = parse_args(opt_parser);

if (is.null(opt$manifest)){
   print_help(opt_parser)
   stop("At least one argument must be supplied (input file).n", call.=FALSE)
}

# Read the manifest file and parse it as a dataframe
M = read.csv(opt$manifest, header=FALSE, sep=" ",
             col.names = c('features','mask','target','result'),
             colClasses = c('character','character','character','character'));

# Read the input data and append to the main matrix
for (row in 1:nrow(M)) {

   print(paste('Sampling:', M$features[row]))
   
   # Read the three images
   f.nii = readNIfTI(M$features[row]);
   m.nii = readNIfTI(M$mask[row]);
   t.nii = readNIfTI(M$target[row]);
   
   # Convert to matrices
   f.mat = matrix(f.nii[,,1,1,],,20);
   m.mat = matrix(m.nii[,]);
   t.mat = matrix(t.nii[,],,1);
   
   # Get foreground/background regions
   r.fg = m.mat > 0;
   r.bg = m.mat == 0;
   
   # Training sample - inside the mask
   f.fg=f.mat[r.fg,];
   f.bg=f.mat[r.bg,];
   t.fg=matrix(t.mat[r.fg,],,1);
   t.bg=matrix(t.mat[r.bg,],,1);
   
   # Get foreground/background samples
   sam.fg = sample.int(sum(r.fg), opt$sfg);
   sam.bg = sample.int(sum(r.bg), opt$sbg);
   
   # Take the samples
   f.sam = rbind(f.fg[sam.fg,], f.bg[sam.bg,]);
   t.sam = rbind(matrix(t.fg[sam.fg,],,1), matrix(t.bg[sam.bg,],,1));
   
   # Append the samples to the large sample array
   if (row == 1) {
      all.f.sam = f.sam
      all.t.sam = t.sam
   }
   else {
      all.f.sam = rbind(all.f.sam, f.sam)
      all.t.sam = rbind(all.t.sam, t.sam)
   }
}

# We how have read all the data in. We can do regression
print(dim(f.fg))
print(dim(t.fg))
print(dim(f.bg))
print(dim(t.bg))
print(dim(all.f.sam))
print(dim(all.t.sam))
df=data.frame(y=all.t.sam, x=all.f.sam)

# Uggly!
model=rlm(y ~ x.1 + x.2 + x.3 + x.4 + x.5 + 
         x.6 + x.7 + x.8 + x.9 + x.10 + 
         x.11 + x.12 + x.13 + x.14 + x.15 + 
         x.16 + x.17 + x.18 + x.19 + x.20, data=df)

print(model)

# Second pass: prediction
for (row in 1:nrow(M)) {

   print(paste('Predicting:', M$features[row]))

   # Read the three images
   f.nii = readNIfTI(M$features[row]);
   m.nii = readNIfTI(M$mask[row]);
   t.nii = readNIfTI(M$target[row]);
   
   # Convert to matrices
   f.mat = matrix(f.nii[,,1,1,],,20);
   m.mat = matrix(m.nii[,]);
   t.mat = matrix(t.nii[,],,1);
   
   # Predict all intensities 
   t.sim=predict(model, data.frame(x=f.mat));
   
   # Clip predicted intensities (why?)
   t.min = min(t.mat); 
   t.max = max(t.mat);
   t.sim[t.sim < t.min] = t.min;
   t.sim[t.sim > t.max] = t.max;

   # Save result
   r.nii = t.nii;
   r.nii[]=matrix(t.sim,c(dim(t.nii),1))
   writeNIfTI(r.nii,gsub("\\..*","",M$result[row]));
}
