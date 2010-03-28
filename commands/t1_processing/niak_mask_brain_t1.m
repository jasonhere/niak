function mask_brain = niak_mask_brain_t1(anat,opt)
%
% _________________________________________________________________________
% SUMMARY NIAK_MASK_BRAIN_T1
%
% Derive a head and a brain masks from a T1 scan.
%
% SYNTAX:
% MASK_BRAIN = NIAK_MASK_BRAIN_T1(ANAT,MASK_HEAD,OPT)
%
% _________________________________________________________________________
% INPUTS :
%
%   ANAT
%       (3D volume) a T1 volume of a brain.
%
%   OPT
%       (structure) with the following fields.
%
%       VOXEL_SIZE
%           (vector 1*3, default [1 1 1]) the size of a voxel.
%
%       NB_COMP_MAX
%           (integer, default 3) To find the brain, the procedure will test
%           the sphericity of the NB_COMP_MAX largest connected components.
%
%       SIZE_SPHERE
%           (scalar, default 25) To find the brain, the procedure will test
%           the which portion of a sphere of radius SIZE_SPHERE and 
%           centered on the center of gravity of each component is included 
%           in this component. The unit of the radius are the one of
%           VOXEL_SIZE.
%
%       PERC_CONF
%           (scalar, default 0.5) the portion of brain tissue that is
%           excluded when defining core dense regions (the darkest voxels
%           are excluded first).
%
%       REGION_GROWING
%           (structure) with the following fields :
%
%           NB_EROSIONS
%               (integer, default 0) number of erosions to apply on the mask
%               before defining the spatial density.
%
%           THRE_DENSITY
%               (scalar, default 0.9) the spatial density threshold to define
%               the core clusters.
%
%           TYPE_NEIG_GROW
%               (integer, default 6) defines the spatial neighbourhood in the
%               region growing.
%               Available options 4 (2D), 6 (3D), 8 (2D) and 26 (3D).
%
%           NB_ITER_MAX
%               (integer, default Inf) the maximal number of iteration in the
%               region growing to propagate cluster labels
%
%           NB_CLUSTERS_MAX
%               (integer, default 15) the maximal number of clusters.
%               See the OPT field in NIAK_CLUSTERING_SPACE_DENSITY.
%
%       FILL_HOLES
%           (structure) with the following fields :
%
%           THRESH_DIST
%               (scalar, default 10) the distance for expansion/shrinking
%               of the brain, expressed in the same units as VOXEL_SIZE.
%
%       FLAG_VERBOSE
%           (boolean, default 1) if the flag is 1, then the function
%           prints some infos during the processing.
%
%       FLAG_TEST
%           (boolean, default 0) if FLAG_TEST equals 1, the brick does not
%           do anything but update the default values in FILES_IN,
%           FILES_OUT and OPT.
%
% _________________________________________________________________________
% OUTPUTS :
%
%   MASK_BRAIN
%       (volume) a binary mask of the brain tissues, i.e. gray matter,
%       white matter and inner CSF. Ideally, the veinous sinus and dura
%       should be stripped out, but some of it may be included in the mask.
%       The skull and fat should be masked out.
%
% _________________________________________________________________________
% SEE ALSO :
% NIAK_MASK_BRAIN, NIAK_BRICK_MASK_BRAIN_T1, NIAK_CLUSTERING_SPACE_DENSITY
%
% _________________________________________________________________________
% COMMENTS
%
% The algorithm is similar conceptually to the competitive region growing
% approach proposed in :
%
% J. G. Park & C. Lee (2009). `Skull stripping based on region growing for
% magnetic resonance brain images'. NeuroImage 47(4):1394-1407.
%
% The actual implementation was still markedly different. It is 3D rather
% than 2D and the competitive region growing algorithm exploits the concept 
% of spatial density rather than more standard morphomathematical 
% operations. Specifically, the main stages are the following :
%
%   1. Classification of brain tissues into CSF/WM/GM using k-means.
%
%   2. Competitive region growing. The seed regions are the bigger
%   connected components within the dense portions of the grey matter. This
%   method is known as DBSCAN and has been proposed in :
%
%   Martin Ester, Hans-Peter Kriegel, Jörg Sander, Xiaowei Xu (1996).
%   "A density-based algorithm for discovering clusters in large spatial
%   databases with noise"
%   in Evangelos Simoudis, Jiawei Han, Usama M. Fayyad.
%   Proceedings of the Second International Conference on Knowledge
%   Discovery and Data Mining (KDD-96). AAAI Press. pp. 226–231.
%   ISBN 1-57735-004-9.
%   http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.71.1980.
%
%   3. Holes in the brain mask are filled using morphomathematical
%   operations.
%
% _________________________________________________________________________
% Copyright (c) Pierre Bellec, Montreal Neurological Institute, 2008.
% Maintainer : pbellec@bic.mni.mcgill.ca
% See licensing information in the code.
% Keywords : medical imaging, t1, mask, segmentation

% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:
%
% The above copyright notice and this permission notice shall be included in
% all copies or substantial portions of the Software.
%
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
% THE SOFTWARE.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Seting up default arguments %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Options
opt_tmp.flag_verbose = 1;

gb_name_structure = 'opt';
gb_list_fields = {'size_sphere','nb_comp_max','fill_holes','region_growing','voxel_size','perc_conf','flag_verbose'};
gb_list_defaults = {25,3,opt_tmp,opt_tmp,[1 1 1],0.5,true};
niak_set_defaults

gb_name_structure = 'opt.region_growing';
gb_list_fields = {'flag_verbose','type_neig_grow','thre_density','nb_iter_max','nb_erosions','nb_clusters_max'};
gb_list_defaults = {opt.flag_verbose,6,0.9,10,0,10};
niak_set_defaults
opt.region_growing.flag_verbose = opt.flag_verbose;

gb_name_structure = 'opt.fill_holes';
gb_list_fields = {'voxel_size','flag_verbose','thresh_dist'};
gb_list_defaults = {opt.voxel_size,opt.flag_verbose,10};
niak_set_defaults

flag_verbose = opt.flag_verbose;


%% Get a intensity-based segmentation
if flag_verbose
    tic;
    fprintf('Deriving a segmentation of the T1 image using Otsu intensity threshold ...\n')
end
opt_mask.fwhm = 0;
mask_head = niak_mask_brain(anat,opt_mask);
if flag_verbose
    fprintf('     Time elapsed %1.3f sec.\n',toc);
end

%% Extract the brain mask using competitive region growing
if flag_verbose
    tic;
    fprintf('Competitive region growing starting from dense white matter regions ...\n')
end
val = sort(anat(mask_head));
mask_conf = anat>val(ceil(perc_conf*length(val)));
clear val
mask_brain = niak_clustering_space_density(mask_conf,mask_head,opt.region_growing);

if flag_verbose    
    fprintf('     Extract the most "spherical" component ...\n')
end

nb_comp = min(nb_comp_max,max(mask_brain(:)));
num_comp = sub_max_sphere(mask_brain,nb_comp,size_sphere,voxel_size);
mask_brain = mask_brain==num_comp;

if flag_verbose
    fprintf('     Time elapsed %1.3f sec.\n',toc);
end

%% Fill the brain
pad_size = ceil((1.5 * opt.fill_holes.thresh_dist)/min(voxel_size));

if pad_size>0
    mask_brain = sub_pad(mask_brain,pad_size);
end

if flag_verbose
    tic;
    fprintf('Filling holes in the brain ...\n')
end

if flag_verbose
    fprintf('     Expanding the brain ...\n')
end

if ~exist('bwdist','file')
    
    opt_m.voxel_size = opt.voxel_size;
    opt_m.pad_size = pad_size;
    mask_brain = niak_morph(~mask_brain,'-successive F',opt_m);
    mask_brain = mask_brain>=(opt.fill_holes.thresh_dist/max(voxel_size));
else
    mask_brain = bwdist(mask_brain);
    mask_brain = mask_brain>=(opt.fill_holes.thresh_dist/max(voxel_size));
end

if flag_verbose
    fprintf('     Finding the outside of the brain ...\n')
end
if ~exist('bwconncomp','file')
    mask_brain = niak_morph(mask_brain,'-successive G');
    mask_brain = round(mask_brain)~=1;
else
    cc = bwconncomp(mask_brain);
    size_roi = cellfun('length',cc.PixelIdxList);
    [val,ind] = max(size_roi);
    mask_brain = false(size(mask_brain));
    mask_brain(cc.PixelIdxList{ind}) = true;
    clear cc
end

if flag_verbose
    fprintf('     Shrinking the brain back...\n')
end
if ~exist('bwdist','file')
    mask_brain = niak_morph(mask_brain,'-successive F',opt_m);
    mask_brain = mask_brain>=((opt.fill_holes.thresh_dist)/max(voxel_size));
else
    mask_brain = bwdist(mask_brain);
    mask_brain = mask_brain>=((opt.fill_holes.thresh_dist)/max(voxel_size));
end

if pad_size>0
    mask_brain = sub_unpad(mask_brain,pad_size);
end

if flag_verbose
    fprintf('     Time elapsed %1.3f sec.\n',toc);
    fprintf('Done !\n')
end

function vol_m = sub_pad(vol,pad_size)
pad_order = [3 2 1];
vol_m = zeros(size(vol)+2*pad_size);
vol_m(pad_size+1:pad_size+size(vol,1),pad_size+1:pad_size+size(vol,2),pad_size+1:pad_size+size(vol,3)) = vol;
for num_d = pad_order
    if num_d == 1
        vol_m(1:pad_size,:,:) = repmat(vol_m(pad_size+1,:,:),[pad_size 1 1]);
        vol_m((size(vol_m,1)-pad_size+1):size(vol_m,1),:,:) = repmat(vol_m(pad_size+size(vol,1),:,:),[pad_size 1 1]);
    elseif num_d == 2
        vol_m(:,1:pad_size,:) = repmat(vol_m(:,pad_size+1,:),[1 pad_size 1]);
        vol_m(:,(size(vol_m,2)-pad_size+1):size(vol_m,2),:) = repmat(vol_m(:,pad_size+size(vol,2),:),[1 pad_size 1]);
    elseif num_d == 3
        vol_m(:,:,1:pad_size) = repmat(vol_m(:,:,pad_size+1),[1 1 pad_size]);
        vol_m(:,:,(size(vol_m,3)-pad_size+1):size(vol_m,3)) = repmat(vol_m(:,:,pad_size+size(vol,3)),[1 1 pad_size]);
    end
end

function vol = sub_unpad(vol_m,pad_size);
siz_vol = size(vol_m)-2*pad_size;
vol = vol_m(pad_size+1:pad_size+siz_vol(1),pad_size+1:pad_size+siz_vol(2),pad_size+1:pad_size+siz_vol(3));

function num_comp = sub_max_sphere(mask,nb_comp,size_sphere,voxel_size)
%% draw a sphere centered in the center of gravity of each region in a
%% mask, and test which proportion of this sphere is included in the mask
sphere_score = zeros([nb_comp 1]);
opt_neig.type_neig = [voxel_size size_sphere];
opt_neig.flag_within_mask = false;
opt_neig.flag_position = false;

for num_c = 1:nb_comp
    % Extract the coordinates of the center of gravity    
    ind = find(mask);
    [x,y,z] = ind2sub(size(mask),ind);
    clear ind
    coord = round(mean([x,y,z],1));
    coord = max(coord,[1 1 1]);
    coord = min(coord,size(mask));
    clear x y z
    indg = sub2ind(size(mask),coord(1),coord(2),coord(3));
    mask_g = false(size(mask));
    mask_g(indg) = true;
    ind_sphere = niak_build_neighbour(mask_g,opt_neig);
    ind_sphere = ind_sphere(ind_sphere>0);
    sphere_score(num_c) = mean(mask(ind_sphere)==num_c);
end

[val,num_comp] = max(sphere_score);