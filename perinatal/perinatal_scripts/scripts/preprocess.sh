#!/bin/bash
# ============================================================================
# Developing brain Region Annotation With Expectation-Maximization (Draw-EM)
#
# Copyright 2013-2016 Imperial College London
# Copyright 2013-2016 Andreas Schuh
# Copyright 2013-2016 Antonios Makropoulos
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ============================================================================


[ $# -eq 4 ] || { echo "usage: $(basename "$0") <subject>" 1>&2; exit 1; }
subj=$1
type=$2
fetneo=$3
age=$4

ROOT_DIR="/home/u153881/Downloads/Recon"
SCRIPT_DIR="$ROOT_DIR/irtk/wrapping/cython/scripts"

if [ -n "$FSLDIR" ]; then
  [ -f "$FSLDIR/bin/bet" ] || { echo "FSLDIR environment variable invalid!" 1>&2; exit 1; }
else
  FSLDIR="$(cd "$(dirname "$(which bet)")"/.. && pwd)"
  [ -f "$FSLDIR/bin/bet" ] || { echo "FSLDIR environment variable not set!" 1>&2; exit 1; }
  export PATH="$FSLDIR/bin:$PATH"
fi

N4=N4
if ! hash $N4 2>/dev/null; then
  N4=N4BiasFieldCorrection
  if ! hash $N4 2>/dev/null; then
    echo "The N4 command is not installed!" 1>&2; 
    exit 1; 
  fi
fi

datadir=`pwd`
sdir=segmentations-data

mkdir -p segmentations N4 dofs bias || exit 1

if [ ! -f N4/$subj.nii.gz ];then 

	if [ ! -f segmentations/${subj}_brain_mask.nii.gz ];then

	  #convert image and rescale
	  run mirtk convert-image $datadir/$type/$subj.nii.gz N4/${subj}_rescaled.nii.gz -rescale 0 1000 -double

	  #brain extract
	  run bet N4/${subj}_rescaled.nii.gz segmentations/${subj}_brain.nii.gz -R -f 0.2 -m

	  python $code_dir/threshold_mask.py -i segmentations/${subj}_brain.nii.gz -o $datadir/segmentations/${subj}_brain_mask.nii.gz 

	  echo "Registering brain to template..."

	  prefix=$datadir/transform_
          mov_img=segmentations/${subj}_brain.nii.gz
  	  fix_img=$template_T2/template-$age.nii.gz
  	  sigma="4x2x1x0"
    	  shrink="8x4x2x1"
          iter="[500x250x100x10,1e-9,10]"
          metrics="MI[${fix_img},${mov_img},1,32,Random,1]"

   	  ${ANTSPATH}/antsRegistration -d 3 -i 0 -n BSpline -o ${prefix} --verbose 1 --float \
		-r [$fix_img,$mov_img,1] \
                --winsorize-image-intensities [0.005,0.995] --use-histogram-matching 0 \
		-t Rigid[0.1] --metric ${metrics} -c ${iter} -s ${sigma} -f ${shrink} \

	  #niftymic_register_image --fixed $template_T2/template-$age.nii.gz --fixed-mask $template_mask/template-$age.nii.gz --moving segmentations/${subj}_brain.nii.gz --moving-mask segmentations/${subj}_brain_mask.nii.gz --dir-input-mc $datadir/motion_correction --output $datadir/transform.txt --init-pca

	  #${ANTSPATH}/ConvertTransformFile 3 $datadir/transform.txt $datadir/transform.mat --convertToAffineType

	  ${ANTSPATH}/antsApplyTransforms -d 3 -i segmentations/${subj}_brain.nii.gz -r $template_T2/template-$age.nii.gz -o $datadir/$type/$subj.nii.gz -n Linear -t ${prefix}0GenericAffine.mat --verbose 1 -f 0

	  python $code_dir/threshold_mask.py -i $type/$subj.nii.gz -o $datadir/segmentations/${subj}_brain_mask.nii.gz
	  
	fi

	#convert image and rescale
	run mirtk convert-image $type/$subj.nii.gz N4/${subj}_rescaled.nii.gz -rescale 0 1000 -double

	#bias correct
	run $N4 3 -i N4/${subj}_rescaled.nii.gz -x segmentations/${subj}_brain_mask.nii.gz -o "[N4/${subj}_corr.nii.gz,bias/$subj.nii.gz]" -c "[50x50x50,0.001]" -s 2 -b "[100,3]" -t "[0.15,0.01,200]"
	run mirtk calculate N4/${subj}_corr.nii.gz -mul segmentations/${subj}_brain_mask.nii.gz -out N4/${subj}_corr.nii.gz 
	  
	#rescale image
	run mirtk convert-image N4/${subj}_corr.nii.gz N4/$subj.nii.gz -rescale 0 1000 -double 

	rm N4/${subj}_rescaled.nii.gz N4/${subj}_corr.nii.gz

fi
