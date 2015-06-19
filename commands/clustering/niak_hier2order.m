function order = niak_hier2order(hier,nb_clust);
% Order objects based on a hierarchy.
% 
% SYNTAX :
% ORDER = NIAK_HIER2ORDER(HIER,NB_CLUST)
% 
% _________________________________________________________________________
% INPUTS :
% HIER (2D array) defines a hierarchy (see NIAK_HIERARCHICAL_CLUSTERING)
% NB_CLUST (integer, default: max) the number of clusters generated from 
%   the partition
% _________________________________________________________________________
% OUTPUTS :
% ORDER (vector) defines a permutation on the objects as defined by HIER 
%   when splitting the objects backward.
%
% _________________________________________________________________________
% COMMENTS :
% If an order is requested on a number of clusters smaller than the number 
% units, the order refers to the numbering of clusters generated by 
% NIAK_THRESHOLD_HIERARCHY
%
% Copyright (c) Pierre Bellec, Montreal Neurological Institute, 2008-2010.
% Centre de recherche de l'institut de gériatrie de Montréal, 
% Department of Computer Science and Operations Research
% University of Montreal, Québec, Canada, 2010-2014
% Maintainer : pierre.bellec@criugm.qc.ca
% See licensing information in the code.
% Keywords : hierarchical clustering

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

n = size(hier,1);
if nargin > 1
    if nb_clust > n+1
        nb_clust = n+1;
    end
end
if size(hier,2) == 3
    hier = [hier(:,3) hier(:,1) hier(:,2) ((n+2):(2*n+1))'];
end

order = hier(n,4);

i = n;
for i = n:-1:1
    ind = find(order==hier(i,4));
    order2 = [];
    if ind > 1
        order2 = order(1:ind-1);
    end
    order2 = [order2 ; hier(i,2:3)'];
    if ind <length(order)
        order2 = [order2 ; order(ind+1:length(order))];
    end
    order = order2;
    i = i-1;
end

if nargin > 1
    opt_t.thresh = nb_clust;
    part = niak_threshold_hierarchy(hier,opt_t);
    order2 = zeros(nb_clust,1);
    for cc = 1:nb_clust    
        ind = find(part==cc,1);
        order2(cc) = find(order==ind);        
    end    
    [val,order] = sort(order2);    
end