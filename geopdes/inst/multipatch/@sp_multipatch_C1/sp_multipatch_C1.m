% SP_MULTIPATCH_C1: Constructor of the class for multipatch spaces with C1 continuity
%
% BETA VERSION. For now, it will only work with two patches
%
%     sp = sp_multipatch_C1 (spaces, msh, interfaces)
%%%XXXX     sp = sp_multipatch_C1 (spaces, msh, interfaces, boundary_interfaces)
%
% INPUTS:
%
%    spaces:     cell-array of space objects, one for each patch (see sp_scalar, sp_vector)
%    msh:        mesh object that defines the multipatch mesh (see msh_multipatch)
%    interfaces: information of connectivity between patches (see mp_geo_load)
%    vertices: information about interfaces and patches neighbouring each vertex (to be implemented)
%%%XXXX    boundary_interfaces: information of connectivity between boundary patches (see mp_geo_load)
%
% OUTPUT:
%
%    sp: object representing the discrete function space of vector-valued functions, with the following fields and methods:
%
%        FIELD_NAME      (SIZE)                       DESCRIPTION
%        npatch          (scalar)                      number of patches
%        ncomp           (scalar)                      number of components of the functions of the space (always equal to one)
%        ndof            (scalar)                      total number of degrees of freedom after gluing patches together
%        ndof_per_patch  (1 x npatch array)            number of degrees of freedom per patch, without gluing
% interior_dofs_per_patch
% ndof_interior
% ndof_interface
%        sp_patch        (1 x npatch cell-array)       the input spaces, one space object for each patch (see sp_scalar and sp_vector)
%        gnum            (1 x npatch cell-array)       global numbering of the degress of freedom (see mp_interface)
%        constructor     function handle               function handle to construct the same discrete space in a different msh
%
%       METHODS
%       Methods that give a structure with all the functions computed in a certain subset of the mesh
%         sp_evaluate_element_list: compute basis functions (and derivatives) in a given list of elements
%
%       Methods for post-processing, that require a computed vector of degrees of freedom
%         sp_l2_error:    compute the error in L2 norm
%         sp_h1_error:    compute the error in H1 norm
%         sp_h2_error:    compute the error in H2 norm
%         sp_to_vtk:      export the computed solution to a pvd file, using a Cartesian grid of points on each patch
%
%       Methods for basic connectivity operations
%         sp_get_basis_functions: compute the functions that do not vanish in a given list of elements
%         sp_get_cells:           compute the cells on which a list of functions do not vanish
%         sp_get_neighbors:       compute the neighbors, functions that share at least one element with a given one
%
% Copyright (C) 2015, 2017 Rafael Vazquez
%
%    This program is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.

%    This program is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with this program.  If not, see <http://www.gnu.org/licenses/>.

function sp = sp_multipatch_C1 (spaces, msh, geometry, interfaces, boundaries, boundary_interfaces)

  if (~all (cellfun (@(x) isa (x, 'sp_scalar'), spaces)))
    error ('All the spaces in the array should be of the same class')
  end
  aux = struct ([spaces{:}]);

  sp.npatch = numel (spaces);
  if (sp.npatch ~= msh.npatch)
    error ('The list of spaces does not correspond to the mesh')
  end

  if (msh.ndim ~= 2 || msh.rdim ~= 2)
    error ('Only implemented for planar surfaces')
  end
  

   for iptc = 1:numel(geometry)
%     if (any (geometry(iptc).nurbs.order > 2))
%       error ('For now, only bilinear patches are implemented')
%     end
    knots = spaces{iptc}.knots;
    breaks = cellfun (@unique, knots, 'UniformOutput', false);
    mult = cellfun (@histc, knots, breaks, 'UniformOutput', false);
    if (any ([mult{:}] < 2))
      error ('The regularity should be at most degree minus two')
    end
    for idim = 1:2
      if (any (mult{idim}(2:end-1) > spaces{iptc}.degree(idim) - 1))
        error ('The regularity should not be lower than one')
      end
    end
  end
  

  sp.ncomp = spaces{1}.ncomp;
  sp.transform = spaces{1}.transform;
  
  if (~all ([aux.ncomp] == 1))
    error ('The number of components should be the same for all the spaces, and equal to one')  
  end
  for iptc = 1:sp.npatch
    if (~strcmpi (spaces{iptc}.transform, 'grad-preserving'))
      error ('The transform to the physical domain should be the same for all the spaces, and the grad-preserving one')
    end
    if (~strcmpi (spaces{iptc}.space_type, 'spline'))
      error ('C1 continuity is only implemented for splines, not for NURBS')
    end
  end
  
  sp.ndof = 0;
  sp.ndof_per_patch = [aux.ndof];
  sp.sp_patch = spaces;
  
% Assuming that the starting space has degree p and regularity r, 
% r <= p-2, we compute the knot vectors of the auxiliary spaces:
%  knots0: degree p, regularity r+1.
%  knots1: degree p-1, regularity r.

  knots0 = cell (sp.npatch, 1); knots1 = knots0;
  for iptc = 1:sp.npatch
    knots = spaces{iptc}.knots;
    breaks = cellfun (@unique, knots, 'UniformOutput', false);
    for idim = 1:msh.ndim
      mult = histc (knots{idim}, breaks{idim});
      mult0{idim} = mult; mult0{idim}(2:end-1) = mult(2:end-1) - 1;
      mult1{idim} = mult - 1;
    end
    knots0{iptc} = kntbrkdegmult (breaks, spaces{iptc}.degree, mult0);
    knots1{iptc} = kntbrkdegmult (breaks, spaces{iptc}.degree-1, mult1);
  end
  sp.knots0_patches = knots0;
  sp.knots1_patches = knots1;

% Computation of the number of degrees of freedom
% We need to give a global numbering to the C^1 basis functions
% We start numbering those away from the interface (V^1) patch by patch
% And then generate the numbering for the functions close to the interface (V^2)

% Compute the local indices of the functions in V^1
%  and sum them up to get the whole space V^1

% if (numel (interfaces) > 1 || msh.npatch > 2)
%   error ('For now, the implementation only works for two patches')
% end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% I HAVE CHANGED STARTING FROM HERE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% We could store the info of interfaces per patch, as in mp_interface

  sp.ndof_interior = 0;
  [interfaces_all, vertices] = vertices_struct_rafa (boundaries, interfaces, geometry, boundary_interfaces);
  for iptc = 1:sp.npatch
    interior_dofs = 1:spaces{iptc}.ndof;
    for intrfc = 1:numel(interfaces_all)
      patches = [interfaces_all(intrfc).patch1, interfaces_all(intrfc).patch2];
      sides = [interfaces_all(intrfc).side1, interfaces_all(intrfc).side2];
      [is_interface,position] = ismember (iptc, patches);
      if (is_interface)
        sp_bnd = spaces{iptc}.boundary(sides(position));
        interior_dofs = setdiff (interior_dofs, [sp_bnd.dofs, sp_bnd.adjacent_dofs]);
      end
    end
    sp.interior_dofs_per_patch{iptc} = interior_dofs; % An array with the indices
    sp.ndof_interior = sp.ndof_interior + numel (interior_dofs);
  end
  
% EXPECTED OUTPUT FROM compute_coefficients  
% ndof_per_interface: number of edge functions on each interface, array of
%    size 1 x numel(interfaces);
% CC_edges: cell array of size 2 x numel(interfaces), the two corresponds
%   to the two patches on the interface. The matrix CC_edges{ii,jj} has size
%      sp.ndof_per_patch(patch) x ndof_per_interface(jj)
%      with patch = interfaces(jj).patches(ii);
% ndof_per_vertex: number of vertex functions on each vertex. An array of size numel(vertices)
% CC_vertices: cell array of size npatch x numel(vertices)
%    The matrix CC_vertices{ii,jj} has size
%    sp.ndof_per_patch(patch) x ndof_per_vertex{jj}
%      with patch being the index of the ii-th patch containing vertex jj;
%
  
%   [ndof, CC] = compute_coefficients (sp, msh, geometry, interfaces);  
  [ndof_per_interface, CC_edges, ndof_per_vertex, CC_vertices] = ...
    compute_coefficients (sp, msh, geometry, interfaces_all, vertices);
%keyboard
  
  sp.ndof_edges = sum(ndof_per_interface); % Total number of edge functions
  sp.ndof_vertices = sum (ndof_per_vertex); % Total number of vertex functions
%%% FIX : only for one interior vertex
%   sp.ndof_vertices = ndof_per_vertex(1); % Total number of vertex functions
  sp.ndof = sp.ndof_interior + sp.ndof_edges + sp.ndof_vertices;

% Computation of the coefficients for basis change
% The matrix Cpatch{iptc} is a matrix of size ndof_per_patch(iptc) x ndof
% The coefficients for basis change have been stored in CC_*

  Cpatch = cell (sp.npatch, 1);
  numel_interior_dofs = cellfun (@numel, sp.interior_dofs_per_patch);
  for iptc = 1:sp.npatch
    Cpatch{iptc} = sparse (sp.ndof_per_patch(iptc), sp.ndof);
    global_indices = sum (numel_interior_dofs(1:iptc-1)) + (1:numel_interior_dofs(iptc));
    Cpatch{iptc}(sp.interior_dofs_per_patch{iptc}, global_indices) = ...
      speye (numel (sp.interior_dofs_per_patch{iptc}));    
  end

  for intrfc = 1:numel(interfaces_all)
    global_indices = sp.ndof_interior + sum(ndof_per_interface(1:intrfc-1)) + (1:ndof_per_interface(intrfc));
    patches = [interfaces_all(intrfc).patch1 interfaces_all(intrfc).patch2];
    for iptc = 1:numel(patches)
      Cpatch{patches(iptc)}(:,global_indices) = CC_edges{iptc,intrfc};
    end
  end

% Vertices and patches_on_vertex are not defined yet. For now, this only works for one extraordinary point
% The information of which patches share the vertex can be computed with the help of mp_interface
  for ivrt = 1:numel(vertices)
% %%% FIX : only for one interior vertex
%     if (vertices(ivrt).boundary_vertex)
%       continue
%     end
    global_indices = sp.ndof_interior + sp.ndof_edges + sum(ndof_per_vertex(1:ivrt-1)) + (1:ndof_per_vertex(ivrt));
%     global_indices = sp.ndof_interior + sp.ndof_edges + (1:ndof_per_vertex(ivrt));
    for iptc = 1:sp.npatch %patches_on_vertex (TO BE CHANGED)
      Cpatch{iptc}(:,global_indices) = CC_vertices{iptc,ivrt};
    end
  end

%  sp.patches_on_vertex = patches_on_vertex; TO BE DONE
  sp.interfaces = interfaces;
  sp.Cpatch = Cpatch;
  sp.geometry = geometry; % I store this for simplicity
  %keyboard
  
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% I HAVE FINISHED MY CHANGES HERE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


  sp.constructor = @(MSH) sp_multipatch_C1 (patches_constructor(spaces, MSH), MSH, geometry, interfaces);
    function spaux = patches_constructor (spaces, MSH)
      for ipatch = 1:MSH.npatch
        spaux{ipatch} = spaces{ipatch}.constructor(MSH.msh_patch{ipatch});
      end
    end

  sp = class (sp, 'sp_multipatch_C1');
  
end


function [ndof_per_interface, CC_edges, ndof_per_vertex, CC_vertices] = compute_coefficients (space, msh, geometry, interfaces_all, vertices)

%Initialize output variables with correct size
ndof_per_interface = zeros (1, numel(interfaces_all));
ndof_per_vertex = 6*ones(1,numel(vertices));

CC_edges = cell (2, numel (interfaces_all));
CC_edges_discarded = cell (2, numel (interfaces_all));
CC_vertices = cell (space.npatch, numel(vertices));
for ii = 1:space.npatch
  for jj = 1:numel(vertices)
    CC_vertices{ii,jj} = sparse (space.ndof_per_patch(ii), 6);
  end
end

pp = space.sp_patch{1}.degree(1);
kk = numel(msh.msh_patch{1}.breaks{1})-2;
% nn = space.sp_patch{1}.sp_univ(1).ndof;
breaks_m = cellfun (@unique, space.sp_patch{1}.knots, 'UniformOutput', false);
mult = histc(space.sp_patch{1}.knots{1},breaks_m{1});
reg = pp - max(mult(2:end-1));


all_alpha0 = zeros(numel(interfaces_all),2);
all_alpha1 = zeros(numel(interfaces_all),2);
all_beta0 = zeros(numel(interfaces_all),2);
all_beta1 = zeros(numel(interfaces_all),2);

%Computation of CC_edges
for iref = 1:numel(interfaces_all)
  patches = [interfaces_all(iref).patch1 interfaces_all(iref).patch2];
  npatches_on_edge = numel (patches);
  operations = interfaces_all(iref).operations;
% Auxiliary geometry with orientation as in the paper
  geo_local = reorientation_patches (operations, geometry(patches));
  sides = [1 3];

% Compute gluing data  
  geo_map_jac = cell (npatches_on_edge, 1);
  for ii = 1:npatches_on_edge
    brk = cell (1,msh.ndim); 
    grev_pts = cell (1, msh.ndim);
    knt = geo_local(ii).nurbs.knots;
    order = geo_local(ii).nurbs.order;
    for idim = 1:msh.ndim
      grev_pts{idim} = [knt{idim}(order(idim)) (knt{idim}(order(idim))+knt{idim}(end-order(idim)+1))/2 knt{idim}(end-order(idim)+1)];
      brk{idim} = [knt{idim}(order(idim)), grev_pts{idim}(1:end-1) + diff(grev_pts{idim})/2, knt{idim}(end-order(idim)+1)];
    end
    msh_grev = msh_cartesian (brk, grev_pts, [], geo_local(ii), 'boundary', true, 'der2',false);
    msh_side_interior = msh_boundary_side_from_interior (msh_grev, sides(ii));
    msh_side_interior = msh_precompute (msh_side_interior);
    geo_map_jac{ii} = msh_side_interior.geo_map_jac; %rdim x ndim x 1 x n_grev_pts (rdim->physical space, ndim->parametric space)
  end

  [alpha0, alpha1, beta0, beta1] = compute_gluing_data (geo_map_jac, grev_pts, sides);
  clear geo_map_jac msh_grev msh_side_interior grev_pts

 %Saving alphas and betas (first column=R, second column=L)
 % FIX: THIS HAS TO BE RECOMPUTED AFTER REORIENTATION
  all_alpha0(iref,:) = alpha0;
  all_alpha1(iref,:) = alpha1;
  all_beta0(iref,:) = beta0;
  all_beta1(iref,:) = beta1;  

% Compute the Greville points, and the auxiliary mesh and space objects for
%  functions with reduced degree or increased regularity
  for ii = 1:npatches_on_edge
%%    %ind1  = [2 2 1 1]; ind2 = [1 1 2 2]
    ind2 = ceil (sides(ii)/2);
    ind1 = setdiff (1:msh.ndim, ind2);

    brk = cell (1,msh.ndim);
    grev_pts = cell (1, msh.ndim);
    degrees = degree_reorientation (space.sp_patch{patches(ii)}.degree, operations(ii,3));
    degree = degrees(ind1); %space.sp_patch{patch(ii)}.degree(ind1);

    knots = knot_vector_reorientation (space.sp_patch{patches(ii)}.knots, operations(ii,:));
    knots0 = knot_vector_reorientation (space.knots0_patches{patches(ii)}, operations(ii,:));
    knots0 = knots0{ind1}; %space.knots0_patches{patch(ii)}{ind1};
    knots1 = knot_vector_reorientation (space.knots1_patches{patches(ii)}, operations(ii,:));
    knots1 = knots1{ind1}; %space.knots1_patches{patch(ii)}{ind1};
    for idim = 1:msh.ndim
      grev_pts{idim} = aveknt (knots{idim}, degrees(idim)+1);%space.sp_patch{patch(ii)}.degree(idim)+1); 
      grev_pts{idim} = grev_pts{idim}(:)';
      brk{idim} = [knots{idim}(1), grev_pts{idim}(1:end-1) + diff(grev_pts{idim})/2, knots{idim}(end)];
    end
    msh_grev = msh_cartesian (brk, grev_pts, [], geo_local(ii), 'boundary', true, 'der2',false);

% Degree and first length in the direction normal to the interface
    degu = degrees(ind2); %space.sp_patch{patch(ii)}.degree(ind2);
    knt = unique (knots{ind2});
    tau1 = knt(2) - knt(1);

% sp_aux contains the value and derivatives of the basis functions, at the Greville points
    msh_side = msh_eval_boundary_side (msh_grev, sides(ii));
    msh_side_interior = msh_boundary_side_from_interior (msh_grev, sides(ii));
    sp_aux = sp_bspline (knots, degrees, msh_side_interior);

% Univariate spaces for the basis functions N^{p,r+1} (knots0) and N^{p-1,r} (knots1) and N^{p,r} on the interface
    sp0 = sp_bspline (knots0, degree, msh_grev.boundary(sides(ii)));
    sp1 = sp_bspline (knots1, degree-1, msh_grev.boundary(sides(ii)));
    sp0_struct = sp_precompute_param (sp0, msh_grev.boundary(sides(ii)), 'value', true, 'gradient', true);
    sp1_struct = sp_precompute_param (sp1, msh_grev.boundary(sides(ii)), 'value', true, 'gradient', true);

    knotsn = knots{ind1};
    spn = sp_bspline (knotsn, degree, msh_grev.boundary(sides(ii)));
    spn_struct = sp_precompute_param (spn, msh_grev.boundary(sides(ii)), 'value', true, 'gradient', true);

% Matrix for the linear systems, (14)-(16) in Mario's notes
    A = sparse (msh_side.nel, msh_side.nel);
    for jj = 1:msh_side.nel
      A(jj,spn_struct.connectivity(:,jj)) = spn_struct.shape_functions(:,:,jj);
    end

%alphas and betas
    alpha = alpha0(ii)*(1-grev_pts{3-ii}') + alpha1(ii)*grev_pts{3-ii}';
    beta = beta0(ii)*(1-grev_pts{3-ii}') + beta1(ii)*grev_pts{3-ii}';

% RHS and solution of the linear systems, (14)-(16) in Mario's notes
    rhss = sparse (msh_side.nel, sp0_struct.ndof);
    for jj = 1:msh_side.nel
      rhss(jj,sp0_struct.connectivity(:,jj)) = sp0_struct.shape_functions(:,:,jj);
    end
    coeff0 = A \ rhss;
    coeff0(abs(coeff0) < 1e-12) = 0; % Make more sparse

    rhsb = sparse (msh_side.nel, sp0_struct.ndof);
    if (ii == 1) % paper case, (sides(ii) == 1)
      val_grad = sp_aux.sp_univ(1).shape_function_gradients(2);
    elseif (ii == 2) %The other paper case, (sides(ii) == 3)
      val_grad = sp_aux.sp_univ(2).shape_function_gradients(2);
    end
    val = val_grad * (tau1 / degu)^2;
    for jj = 1:msh_side.nel
      val_aux = -val * beta(jj);
      rhsb(jj,sp0_struct.connectivity(:,jj)) = sp0_struct.shape_function_gradients(:,:,:,jj) * val_aux;
    end
    rhsb = rhsb + rhss;
    coeff1 = A \ rhsb;
    coeff1(abs(coeff1) < 1e-12) = 0; % Make more sparse

    rhsc = sparse (msh_side.nel, sp1_struct.ndof);
    val = val_grad* (tau1 / degu); %^2 removed  %WARNING: WE DIVIDED BY tau1/degu, which REQUIRES A SMALL MODIFICATION IN THE REF MASK (ADD MULT. BY 1/2) 
    for jj = 1:msh_side.nel
      val_aux = val * alpha(jj)* (-1)^(ii+1); %with the multipatch settings must be multiplied by -1 for left patch;
      rhsc(jj,sp1_struct.connectivity(:,jj)) = sp1_struct.shape_functions(:,:,jj) * val_aux;
    end
    coeff2 = A \ rhsc;
    coeff2(abs(coeff2) < 1e-12) = 0; % Make more sparse

% Pass the coefficients to the tensor product basis
    ndof_dir = sp_aux.ndof_dir; %space.sp_patch{patch(ii)}.ndof_dir;
    ndof_dir_original = space.sp_patch{patches(ii)}.ndof_dir;
    if (ii == 1)     %(sides(ii) == 1)
      ind0 = sub2ind (ndof_dir, ones(1,spn.ndof), 1:spn.ndof);
      ind1 = sub2ind (ndof_dir, 2*ones(1,spn.ndof), 1:spn.ndof);
    elseif (ii == 2) %(sides(ii) == 3)
      ind0 = sub2ind (ndof_dir, 1:spn.ndof, ones(1,spn.ndof));
      ind1 = sub2ind (ndof_dir, 1:spn.ndof, 2*ones(1,spn.ndof));
    end
    indices_reoriented = indices_reorientation (ndof_dir_original, operations(ii,:));
    ind0_ornt = indices_reoriented(ind0);
    ind1_ornt = indices_reoriented(ind1);

% Store the coefficients in CC_edges, and compute the number of functions
    ndof_edge = sp0_struct.ndof + sp1_struct.ndof;
    trace_functions = 4:sp0_struct.ndof-3;
    deriv_functions = sp0_struct.ndof + (3:sp1_struct.ndof-2);
    active_functions = union (trace_functions, deriv_functions);
    discarded_functions = setdiff (1:ndof_edge, active_functions);

    CC = sparse (space.ndof_per_patch(patches(ii)), ndof_edge);
    CC(ind0_ornt,1:sp0_struct.ndof) = coeff0;
    CC(ind1_ornt,1:sp0_struct.ndof) = coeff1;
    CC(ind1_ornt,sp0_struct.ndof+(1:sp1_struct.ndof)) = coeff2;

    ndof_per_interface(iref) = numel(active_functions);    
    CC_edges{ii,iref} = sparse (space.ndof_per_patch(patches(ii)), ndof_per_interface(iref));
    CC_edges{ii,iref} = CC(:,active_functions);
    CC_edges_discarded{ii,iref} = CC(:,discarded_functions);
  end
end


%We assume that the local numbering of interfaces and patches is such that
%vertices(kver).interface(im) is the interface between
%vertices(kver).patches(im) and vertices(kver).patches(im+1)
MM = cell(2,numel(vertices));
V = cell(numel(vertices),1);
E = cell(numel(vertices),1);
sides = [1 4; 2 3; 1 2; 4 3]; %on i-th row the indices of the endpoints of the i-th side (bottom-up, left-right)

for kver = 1:numel(vertices)
%   if (vertices(kver).boundary_vertex)
%     continue
%   end
  edges = vertices(kver).edges;
  patches = vertices(kver).patches;
  valence_e = vertices(kver).valence_e;
  valence_p = vertices(kver).valence_p;
  operations = vertices(kver).patch_reorientation;
  edge_orientation = vertices(kver).edge_orientation;
  
  geo_local = reorientation_patches (operations, geometry(patches));

% Precompute the derivatives and compute sigma
  sigma = 0;
  for iptc = 1:valence_p
    knots = space.sp_patch{iptc}.knots;
    for idim = 1:msh.ndim
      brk{idim}=[knots{idim}(1) knots{idim}(end)];
    end
    msh_pts_der1 = msh_cartesian (brk, {0 0}, [], geo_local(iptc),'boundary', true, 'der2', true);
    msh_der = msh_precompute (msh_pts_der1);
    derivatives_new1{iptc} = msh_der.geo_map_jac; %rdim x ndim x (n_pts{1}x n_pts{2}) (rdim->physical space, ndim->parametric space)
    derivatives_new2{iptc} = msh_der.geo_map_der2; %rdim x ndim x ndim x n_pts{1} x n_pts{2}
    
    sigma = sigma + norm (derivatives_new1{iptc},2); % FIX: choose which norm
  end
  sigma = pp*(kk+1)*valence_p/sigma;
  
  for ipatch = 1:valence_p
    prev_edge = ipatch;
    next_edge = mod(ipatch, valence_e) + 1;

% Compute gluing data, and edge functions from CC_edges_discarded
    if (edge_orientation(prev_edge) == 1)
      alpha_prev = all_alpha0(edges(prev_edge),2);
      beta_prev = all_beta0(edges(prev_edge),2);
      alpha_der_prev = -all_alpha0(edges(prev_edge),2) + all_alpha1(edges(prev_edge),2);
      beta_der_prev = -all_beta0(edges(prev_edge),2) + all_beta1(edges(prev_edge),2);
      E_prev = CC_edges_discarded{2,edges(prev_edge)}(:,[1 2 3 7 8]);
    else
      alpha_prev = all_alpha1(edges(prev_edge),1);
      beta_prev = -all_beta1(edges(prev_edge),1);
      alpha_der_prev = all_alpha0(edges(prev_edge),1) - all_alpha1(edges(prev_edge),1);
      beta_der_prev = -all_beta0(edges(prev_edge),1) + all_beta1(edges(prev_edge),1);
      E_prev = CC_edges_discarded{1,edges(prev_edge)}(:,[6 5 4 10 9]);
      E_prev(:,[4 5]) = -E_prev(:,[4 5]);
    end
    if (edge_orientation(next_edge) == 1)
      alpha_next = all_alpha0(edges(next_edge),1);
      beta_next = all_beta0(edges(next_edge),1);
      alpha_der_next = -all_alpha0(edges(next_edge),1) + all_alpha1(edges(next_edge),1);
      beta_der_next = -all_beta0(edges(next_edge),1) + all_beta1(edges(next_edge),1);
      E_next = CC_edges_discarded{1,edges(next_edge)}(:,[1 2 3 7 8]);
    else
      alpha_next = all_alpha1(edges(next_edge),2);
      beta_next = -all_beta1(edges(next_edge),2);
      alpha_der_next = all_alpha0(edges(next_edge),2) - all_alpha1(edges(next_edge),2);
      beta_der_next = -all_beta0(edges(next_edge),2) + all_beta1(edges(next_edge),2);
      E_next = CC_edges_discarded{2,edges(next_edge)}(:,[6 5 4 10 9]);
      E_next(:,[4 5]) = -E_next(:,[4 5]);
    end
    
    Du_F = derivatives_new1{ipatch}(:,1);
    Dv_F = derivatives_new1{ipatch}(:,2);
    Duu_F = derivatives_new2{ipatch}(:,1,1);
    Duv_F = derivatives_new2{ipatch}(:,1,2);
    Dvv_F = derivatives_new2{ipatch}(:,2,2);
    
% Edge information
    t0_prev = Du_F;
    t0_next = Dv_F;
    t0p_prev = Duu_F;
    t0p_next = Dvv_F;

    d0_prev = -(Dv_F + beta_prev * Du_F) / alpha_prev;
    d0_next =  (Du_F + beta_next * Dv_F) / alpha_next;
    d0p_prev = ( alpha_der_prev * (Dv_F + beta_prev*Du_F) - ...
                 alpha_prev * (Duv_F + beta_der_prev*Du_F + beta_prev*Duu_F)) / alpha_prev^2;
    d0p_next = (-alpha_der_next * (Du_F + beta_next*Dv_F) + ...
                 alpha_next * (Duv_F + beta_der_next*Dv_F + beta_next*Dvv_F)) / alpha_next^2;

% Compute M and V matrices
    ndof = space.sp_patch{patches(ipatch)}.ndof;
    M_prev = sparse (5,6); M_next = sparse (5,6);
    VV = sparse (ndof,6);
    
    ndof_dir = space.sp_patch{patches(ipatch)}.ndof_dir;
    all_indices = indices_reorientation (ndof_dir, operations(ipatch,:));
    corner_4dofs = all_indices(1:2,1:2);
    jfun = 1;
    for j1 = 0:2
      for j2 = 0:2-j1
        mat_deltas = [(j1==2)*(j2==0), (j1==1)*(j2==1); (j1==1)*(j2==1), (j1==0)*(j2==2)];
        vec_deltas = [(j1==1)*(j2==0); (j1==0)*(j2==1)];
        d00 = (j1==0)*(j2==0);
        %M_{i_{m-1},i}
        d10_a = vec_deltas.'*t0_prev;
        d20_a = t0_prev.'*mat_deltas*t0_prev + vec_deltas.'*t0p_prev;
        d01_a = vec_deltas.'*d0_prev;
        d11_a = t0_prev.'*mat_deltas*d0_prev + vec_deltas.'*d0p_prev;
 
        %M_{i_{m+1},i}
        d10_b = vec_deltas.'*t0_next;
        d20_b = t0_next.'*mat_deltas*t0_next + vec_deltas.'*t0p_next;
        d01_b = vec_deltas.'*d0_next;
        d11_b = t0_next.'*mat_deltas*d0_next + vec_deltas.'*d0p_next;
        if (reg < pp-2)
          M_prev(:,jfun) = sigma^(j1+j2)*[d00, ...
                                          d00+d10_a/(pp*(kk+1)), ...
                                          d00+2*d10_a/(pp*(kk+1))+d20_a/(pp*(pp-1)*(kk+1)^2), ...
                                          d01_a/(pp*(kk+1)), ...
                                          d01_a/(pp*(kk+1))+d11_a/(pp*(pp-1)*(kk+1)^2)].';
          M_next(:,jfun) = sigma^(j1+j2)*[d00, ...
                                          d00+d10_b/(pp*(kk+1)), ...
                                          d00+2*d10_b/(pp*(kk+1))+d20_b/(pp*(pp-1)*(kk+1)^2), ...
                                          d01_b/(pp*(kk+1)), ...
                                          d01_b/(pp*(kk+1))+d11_b/(pp*(pp-1)*(kk+1)^2)].';
        else
          M_prev(:,jfun) = sigma^(j1+j2)*[d00, ...
                                          d00+d10_a/(pp*(kk+1)), ...
                                          d00+3*d10_a/(pp*(kk+1))+2*d20_a/(pp*(pp-1)*(kk+1)^2), ...
                                          d01_a/(pp*(kk+1)), ...
                                          d01_a/(pp*(kk+1))+d11_a/(pp*(pp-1)*(kk+1)^2)].';
          M_next(:,jfun) = sigma^(j1+j2)*[d00, ...
                                          d00+d10_b/(pp*(kk+1)), ...
                                          d00+3*d10_b/(pp*(kk+1))+2*d20_b/(pp*(pp-1)*(kk+1)^2), ...
                                          d01_b/(pp*(kk+1)), ...
                                          d01_b/(pp*(kk+1))+d11_b/(pp*(pp-1)*(kk+1)^2)].';
        end
        %V_{i_m,i}  
        d11_c = t0_prev.'*mat_deltas*t0_next + vec_deltas.'*Duv_F;
        VV(corner_4dofs,jfun) = sigma^(j1+j2)*[d00, ...
                                               d00+d10_a/(pp*(kk+1)), ...
                                               d00+d10_b/(pp*(kk+1)), ...
                                               d00+(d10_a+d10_b+d11_c/(pp*(kk+1)))/(pp*(kk+1))]'; 
        jfun = jfun+1;
      end
    end

    CC_vertices{patches(ipatch),kver} = E_prev*M_prev + E_next*M_next - VV;
  end

end


% % Computation of CC_vertices
% % Compute for each patch all the derivatives we possibly need to compute t,d, and sigma
% % FIX: this would be done inside the vertex loop, after reorientation
% brk = cell (1,msh.ndim);
% for iptc = 1:space.npatch
%   knots = space.sp_patch{iptc}.knots;
%   for idim = 1:msh.ndim
%     brk{idim}=[knots{idim}(1) knots{idim}(end)]; %is this correct?
%   end
%   %the following points correspond to the four vertices of the patch
%   pts{1} = [0 1]';
%   pts{2} = [0 1]';%pts{2}=[0 1/2 1]'
%   msh_pts_der1 = msh_cartesian (brk, pts, [], geometry(iptc),'boundary', true, 'der2', true);
%   msh_der = msh_precompute (msh_pts_der1);
%   derivatives1{iptc} = msh_der.geo_map_jac; %rdim x ndim x (n_pts{1}x n_pts{2}) (rdim->physical space, ndim->parametric space)
%   derivatives2{iptc} = msh_der.geo_map_der2; %rdim x ndim x ndim x n_pts{1} x n_pts{2}
% end
% 
% for kver = 1:numel(vertices)
%   %Everything must be updated by using interfaces_all instead of interfaces TO DO
%   ver_patches = []; %vector with indices of patches containing the vertex
%   ver_patches_nabla = {}; %cell array containing jacobians
%   ver_ind = []; %vector containing local index of vertex in the patch
%   valence_e = vertices(kver).valence_e;
%   valence_p = vertices(kver).valence_p;
%   patches = vertices(kver).patches;
%     
%   if (~vertices(kver).boundary_vertex)
%     
% % 1=RIGHT PATCH 2=LEFT PATCH (true also for alphas and betas, but not for CC_edges and CC_edges_discarded)    
%     for iedge = 1:valence_e %cycle over all the interfaces containing the vertex
%       inter = vertices(kver).edges(iedge); %global index of the interface 
%       patch_ind1 = interfaces_all(inter).patch1; %global index of left patch of iedge-th interface
%       patch_ind2 = interfaces_all(inter).patch2; %global index of right patch of iedge-th interface
% %       vertex_ind1 = sides(interfaces_all(inter).side1,vertices(kver).ind(iedge)); %local index of vertex in left patch
% %       vertex_ind2 = sides(interfaces_all(inter).side2,vertices(kver).ind(iedge)); %local index of vertex in right patch
%       vertex_ind1 = 1; vertex_ind2 = 1; % FIX: This must depend on the orientation
%       ver_patches = [ver_patches patch_ind1 patch_ind2];
%       ver_ind = [ver_ind vertex_ind1 vertex_ind2];
%         %compute t(0) and t'(0), d(0) and d'(0)
%       switch vertex_ind1
%         case 1 %vertex (0,0)
%           Du_F00 = derivatives1{patch_ind1}(:,1,1);
%           Dv_F00 = derivatives1{patch_ind1}(:,2,1);
%           Duv_F00 = derivatives2{patch_ind1}(:,1,2,1);
%           Dvv_F00 = derivatives2{patch_ind1}(:,2,2,1);
%       end
%         %Store the jacobian of F for the left patch
%       ver_patches_nabla{2*iedge-1} = [Du_F00 Dv_F00];
% 
%       t0(iedge,:) = Dv_F00;
%       t0p(iedge,:) = Dvv_F00;
%       d0(iedge,:) = (Du_F00 + (all_beta0(inter,1)*(1-0) + all_beta1(inter,1)*0)*Dv_F00) / ...
%             (all_alpha0(inter,1)*(1-0) + all_alpha1(inter,1)*0);
%       d0p(iedge,:) = (-(-all_alpha0(inter,1) + all_alpha1(inter,1))*(Du_F00 + (all_beta0(inter,1)*(1-0) + all_beta1(inter,1)*0)*Dv_F00) +...
%                    (all_alpha0(inter,1)*(1-0) + all_alpha1(inter,1)*0) * ...
%                    (Duv_F00 + (-all_beta0(inter,1) + all_beta1(inter,1))*Dv_F00 + ...
%                    (all_beta0(inter,1)*(1-0) + all_beta1(inter,1)*0)*Dvv_F00)) / ...
%                    (all_alpha0(inter,1)*(1-0)+all_alpha1(inter,1)*0)^2;  
%       mix_der2(2*iedge-1,:) = Duv_F00;
%       %We need to get the jacobian also for the right patch
%       switch vertex_ind2
%         case 1 %vertex (0,0)
%           Du_F00 = derivatives1{patch_ind2}(:,1,1);
%           Dv_F00 = derivatives1{patch_ind2}(:,2,1);
%           Duv_F00 = derivatives2{patch_ind2}(:,1,2,1);
%       end
%       ver_patches_nabla{2*iedge} = [Du_F00 Dv_F00];
%       mix_der2(2*iedge,:) = Duv_F00;
%         
%       %Pick the correct part of CC_edges_discarded %TO BE FIXED
%       if (vertices(kver).edge_orientation(iedge) == 1) %the vertex is the left/bottom endpoint of im-th interface
%         E{kver}{iedge,1} = CC_edges_discarded{1,inter}(:,[1 2 3 7 8]); %part of the matrix corresponding to edge functions close to the vertex
%         E{kver}{iedge,2} = CC_edges_discarded{2,inter}(:,[1 2 3 7 8]);
% %       else %the vertex is the right/top endpoint of im-th interface
% %         E{kver}{im,1}=CC_edges_discarded{1,inter}(:,[4 5 6 9 10]);
% %         E{kver}{im,2}=CC_edges_discarded{2,inter}(:,[4 5 6 9 10]);
%       end
%     end
%     [ver_patches, ind_patch_sigma, ind_patch_rep] = unique (ver_patches, 'stable');
%     mix_der2_n = mix_der2(ind_patch_sigma,:);
%     %ver_ind=unique(ver_ind,'rows','stable');
%     
%     %ind_patch_sigma contains the positions of the elements of ver_patches
%     %originally (each of them is present twice, the first one is considered)
%     
%     %if the number of patches coincides with the number of interfaces, 
%     %we add one fictional interface coinciding with the first one
%     %(just for coding-numbering reasons)
% %     if numel(ver_patches)==ninterfaces_ver
% %         t0(ninterfaces_ver+1,:)=t0(1,:);
% %         t0p(ninterfaces_ver+1,:)=t0p(1,:);
% %         d0(ninterfaces_ver+1,:)=d0(1,:);
% %         d0p(ninterfaces_ver+1,:)=d0p(1,:);
% %         E{kver}{ninterfaces_ver+1,1}=E{kver}{1,1};
% %         E{kver}{ninterfaces_ver+1,2}=E{kver}{1,2};
% %     end
%     
%     %computing sigma % FIX: ver_patches_nabla needs to be changed for multiple vertices
%     sigma = 0;
%     for im = 1:valence_p % FIX: is this the number of interfaces?
%       sigma = sigma + norm(ver_patches_nabla{ind_patch_sigma(im)},2);
%     end
%     sigma = 1/(sigma/(pp*(kk+1)*valence_p));
%     %computing matrices MM and V
%     for ipatch = 1:valence_p %FIX: cycle over the patches containing the vertex
%         
%         %assemble matrix (not final: Ms and Vs, then updated with the "discarded parts" of edge functions)
%       n1 = space.sp_patch{patches(ipatch)}.ndof_dir(1); %dimension of tensor-product space in the patch (dir 1)
%       n2 = space.sp_patch{patches(ipatch)}.ndof_dir(2); %dimension of tensor-product space in the patch (dir 2)
% %       V{kver}{im} = zeros(n1*n2,6);
%       MM1 = zeros(5,6); MM2 = zeros(5,6);
%       VV = zeros(n1*n2,6);
%       im_edges = ceil(find(ind_patch_rep==ipatch)/2); %indices of the edges containing the vertex (in the list of edges containing the vertex)
%       if (ipatch == 1)  %works only if the interfaces and patches are ordered in clockwise order
%         im_edges = flip (im_edges); %this is done to have always the interface to the right of the patch in iedge1
%       end
%       iedge1 = im_edges(1); iedge2 = im_edges(2);
% 
%       corner_4dofs = [1 2 n2+1 n2+2];
%       jfun = 1;
%       for j1 = 0:2
%         for j2 = 0:2-j1 %the following computations work in the standard case
%           mat_deltas = [(j1==2)*(j2==0), (j1==1)*(j2==1); (j1==1)*(j2==1), (j1==0)*(j2==2)];
%           vec_deltas = [(j1==1)*(j2==0), (j1==0)*(j2==1)];
%           d00 = (j1==0)*(j2==0);
%           %M_{i_{m-1},i}
%           d10_a = vec_deltas*t0(iedge1,:)';
%           d20_a = t0(iedge1,:)*mat_deltas*t0(iedge1,:)' + vec_deltas*t0p(iedge1,:)';
%           d01_a = vec_deltas*d0(iedge1,:)';
%           d11_a = t0(iedge1,:)*mat_deltas*d0(iedge1,:)' + vec_deltas*d0p(iedge1,:)';
% 
%           %M_{i_{m+1},i}
%           d10_b = vec_deltas*t0(iedge2,:)';
%           d20_b = t0(iedge2,:)*mat_deltas*t0(iedge2,:)' + vec_deltas*t0p(iedge2,:)';
%           d01_b = vec_deltas*d0(iedge2,:)';
%           d11_b = t0(iedge2,:)*mat_deltas*d0(iedge2,:)' + vec_deltas*d0p(iedge2,:)';  
%           if (reg < pp-2)
%             MM1(:,jfun) = sigma^(j1+j2)*[d00, ...
%                                          d00+d10_a/(pp*(kk+1)), ...
%                                          d00+2*d10_a/(pp*(kk+1))+d20_a/(pp*(pp-1)*(kk+1)^2), ...
%                                          d01_a/(pp*(kk+1)), ...
%                                          d01_a/(pp*(kk+1))+d11_a/(pp*(pp-1)*(kk+1)^2)].';
%             MM2(:,jfun) = sigma^(j1+j2)*[d00, ...
%                                          d00+d10_b/(pp*(kk+1)), ...
%                                          d00+2*d10_b/(pp*(kk+1))+d20_b/(pp*(pp-1)*(kk+1)^2), ...
%                                          d01_b/(pp*(kk+1)), ...
%                                          d01_b/(pp*(kk+1))+d11_b/(pp*(pp-1)*(kk+1)^2)].';
%           else
%             MM1(:,jfun) = sigma^(j1+j2)*[d00, ...
%                                          d00+d10_a/(pp*(kk+1)), ...
%                                          d00+3*d10_a/(pp*(kk+1))+2*d20_a/(pp*(pp-1)*(kk+1)^2), ...
%                                          d01_a/(pp*(kk+1)), ...
%                                          d01_a/(pp*(kk+1))+d11_a/(pp*(pp-1)*(kk+1)^2)].';
%             MM2(:,jfun) = sigma^(j1+j2)*[d00, ...
%                                          d00+d10_b/(pp*(kk+1)), ...
%                                          d00+3*d10_b/(pp*(kk+1))+2*d20_b/(pp*(pp-1)*(kk+1)^2), ...
%                                          d01_b/(pp*(kk+1)), ...
%                                          d01_b/(pp*(kk+1))+d11_b/(pp*(pp-1)*(kk+1)^2)].';
%           end
%           %V_{i_m,i}  
%           d11_c = t0(iedge1,:)*mat_deltas*t0(iedge2,:)' + vec_deltas*mix_der2_n(ipatch,:)';
%           VV(corner_4dofs,jfun) = sigma^(j1+j2)*[d00, ...
%                                                  d00+d10_a/(pp*(kk+1)), ...
%                                                  d00+d10_b/(pp*(kk+1)), ...
%                                                  d00+(d10_a+d10_b+d11_c/(pp*(kk+1)))/(pp*(kk+1))]'; 
%           jfun = jfun+1;
%         end
%       end
%       % Check which patch of the edge function we are considering
%       if (interfaces_all(vertices(kver).edges(iedge1)).patch2 == patches(ipatch))%the considered patch is the second patch edge iedge1
%         E1 = E{kver}{iedge1,2};
%       else
%         E1 = E{kver}{iedge1,1};
%       end
%       if (interfaces_all(vertices(kver).edges(iedge2)).patch2 == patches(ipatch))%the considered patch is the second patch of edge iedge2
%         E2 = E{kver}{iedge2,2};
%       else
%         E2 = E{kver}{iedge2,1};
%       end
% % %       XX1 = E1; XX1(:,4) = -XX1(:,4); XX1(:,5) = -XX1(:,5);
% % %       XX2 = E2; XX2(:,4) = -XX2(:,4); XX2(:,5) = -XX2(:,5);
% %       CC_vertices{ver_patches(ipatch),kver} = E1*MM{1,kver}{ipatch} + E2*MM{2,kver}{ipatch} - V{kver}{ipatch};
%       CC_vertices{patches(ipatch),1} = E1*MM1 + E2*MM2 - VV;
% % %       CC_vertices{ver_patches(ipatch),kver} = XX1*MM1 + XX2*MM2 - VV;
%       %csi2=[1 9 17 25 33 41 49 57];
%       %csi1=1:8;
% %       M1aux{ipatch} = E1 * MM1;
% %       M2aux{ipatch} = E2 * MM2;
% %       Vaux{ipatch} = VV;
%     end
%   end
% 
% end

end

function [alpha0, alpha1, beta0, beta1] = compute_gluing_data (geo_map_jac, grev_pts, side)

  if (numel (geo_map_jac) == 1)
% FIX: alpha1 and beta1 do not exist. They should be empty, but give an error in all_alpha
    alpha0 = [1 1];
    alpha1 = [1 1];
    beta0 = [0 0]; 
    beta1 = [0 0];
    return
  end

  %STEP 3 - Assembling and solving G^1 conditions system  %this must depend on orientation!
  if (side(2)==1 || side(2)==2)
    v = grev_pts{2}(:);
  else
    v = grev_pts{1}(:);
  end
  ngrev = numel(v);
  DuFR_x = reshape(geo_map_jac{1}(1,1,:,:),ngrev,1); %column vector
  DuFR_y = reshape(geo_map_jac{1}(2,1,:,:),ngrev,1); %column vector
  DvFL_x = reshape(geo_map_jac{2}(1,2,:,:),ngrev,1); %column vector
  DvFL_y = reshape(geo_map_jac{2}(2,2,:,:),ngrev,1); %column vector
  DvFR_x = reshape(geo_map_jac{1}(1,2,:,:),ngrev,1); %column vector
  DvFR_y = reshape(geo_map_jac{1}(2,2,:,:),ngrev,1); %column vector
  
  A_full = [(1-v).*DvFL_x v.*DvFL_x (1-v).*DuFR_x v.*DuFR_x (1-v).^2.*DvFR_x 2*(1-v).*v.*DvFR_x v.^2.*DvFR_x;...
       (1-v).*DvFL_y v.*DvFL_y (1-v).*DuFR_y v.*DuFR_y (1-v).^2.*DvFR_y 2*(1-v).*v.*DvFR_y v.^2.*DvFR_y];
  if (rank(A_full)==6)
    A = A_full(:,2:end);
    b = -A_full(:,1);
    sols = A\b;
    alpha0_n(1) = 1; %R
    alpha1_n(1) = sols(1); %R
    alpha0_n(2) = sols(2); %L
    alpha1_n(2) = sols(3); %L
    beta0_n = sols(4);
    beta1_n = sols(5);
    beta2_n = sols(6);
  else
    A = A_full(:,3:end); % FIX: not a square matrix
    b = -sum(A_full(:,1:2),2);
    sols = A\b;
    alpha0_n(1) = 1; %R
    alpha1_n(1) = 1; %R
    alpha0_n(2) = sols(1); %L
    alpha1_n(2) = sols(2); %L
    beta0_n = sols(3);
    beta1_n = sols(4);
    beta2_n = sols(5);     
  end
 
 %keyboard
 %STEP 4 - Normalizing the alphas
 %C1=((alpha1_n(1)-alpha0_n(1))^2)/3+((alpha1_n(2)-alpha0_n(2))^2)/3 + (alpha1_n(1)-alpha0_n(1))*alpha0_n(1)+(alpha1_n(2)-alpha0_n(2))*alpha0_n(2)...
 %   +alpha0_n(1)^2+alpha0_n(2)^2;
 %C2=(alpha1_n(1)-alpha0_n(1))-(alpha1_n(2)-alpha0_n(2))+2*alpha0_n(1)-2*alpha0_n(2);
 %gamma=-C2/(2*C1);
  C1 = alpha0_n(2)^2+alpha0_n(2)*alpha1_n(2)+alpha1_n(2)^2+alpha0_n(1)^2+alpha0_n(1)*alpha1_n(1)+alpha1_n(1)^2;
  C2 = alpha0_n(2)+alpha1_n(2)+alpha0_n(1)+alpha1_n(1);
  gamma = 3*C2/(2*C1);
  alpha0(1) = alpha0_n(1)*gamma; %R
  alpha1(1) = alpha1_n(1)*gamma; %R
  alpha0(2) = alpha0_n(2)*gamma; %L
  alpha1(2) = alpha1_n(2)*gamma; %L
  bbeta0 = beta0_n*gamma;
  bbeta1 = beta1_n*gamma;
  bbeta2 = beta2_n*gamma;
 
 %STEP 5 - Computing the betas
 %alphas and beta evaluated at 0,1,1/2
  alpha_R_0 = alpha0(1); %alpha_R(0)
  alpha_R_1 = alpha1(1); %alpha_R(1)
  alpha_R_12 = (alpha0(1)+alpha1(1))/2; %alpha_R(1/2)
  alpha_L_0 = alpha0(2); %alpha_L(0)
  alpha_L_1 = alpha1(2); %alpha_L(1)
  alpha_L_12 = (alpha0(2)+alpha1(2))/2; %alpha_L(1/2)  
  beta_0 = bbeta0; %beta(0)
  beta_1 = bbeta2; %beta(1)
  beta_12 = (bbeta0+bbeta2)/4+bbeta1/2; %beta(1/2)
 
  %Computing the matrix of the system considering the relationship between beta^L, beta^R and beta
  M = [alpha_R_0 0 alpha_L_0 0; ...
       0 alpha_R_1 0 alpha_L_1; ...
       alpha_R_12/2 alpha_R_12/2 alpha_L_12/2 alpha_L_12/2];
 
  if (rank(M)==3)
     
 %Computing beta1_R, beta0_L, beta1_L in terms of beta0_R
    quant1 = (-alpha_L_12/2 + (alpha_L_0*alpha_R_12)/(2*alpha_R_0)) / ...
      (-(alpha_L_1*alpha_R_12)/(2*alpha_R_1) + alpha_L_12/2);
    quant2 = (beta_12-(beta_0*alpha_R_12)/(2*alpha_R_0) - (beta_1*alpha_R_12)/(2*alpha_R_1)) / ...
      (-(alpha_L_1*alpha_R_12)/(2*alpha_R_1) + alpha_L_12/2); 
 
 %beta1_R=a+b*beta0_R,  beta0_L=c+d*beta0_R,  beta1_L=e+f*beta0_R, where
    a = quant2; b = quant1;
    c = beta_0/alpha_R_0; d = -alpha_L_0/alpha_R_0;
    e = (beta_1-alpha_L_1*quant2)/alpha_R_1; f = -alpha_L_1*quant1/alpha_R_1;
      
 %We determine beta0_R by minimizing the sum of the norms of beta_R and beta_L
    C1 = ((b-1)^2)/3 + (b-1) + ((f-d)^2)/3 + (f-d)*d + d^2 + 1;
    C2 = 2*a*(b-1)/3 + a + 2*(e-c)*(f-d)/3 + (e-c)*d + (f-d)*c + 2*c*d;
    beta0(1) = -C2/(2*C1); %R
    beta1(1) = a + b*beta0(1); %R
    beta0(2) = c + d*beta0(1); %L
    beta1(2) = e + f*beta0(1); %L

  else
 %Computing beta0_L in terms of beta0_R and beta1_L in terms of beta1_R: 
 %beta0_R=a+b*beta0_L,  beta1_R=c+d*beta1_L, where
    a = beta_0/alpha_R_0; b = -alpha_L_0/alpha_R_0;
    c = beta_1/alpha_R_1; d = -alpha_L_1/alpha_R_1;
 
 %We determine beta0_R and beta_1_R by minimizing the sum of the norms of beta_R and beta_L
 %The resuting system is
    M2 = [2*(1+b^2) 1+b*d; 1+b*d 2*(1+d^2)];
    M2b = [-b*c-2*a*b; -a*d-2*c*d];
    sol = M2\M2b;
    beta0(1)= sol(1); %R
    beta1(1)= sol(2); %R
    beta0(2)= a + b*beta0(1); %L
    beta1(2)= c + d*beta1(1); %L
  end 
  
end

% Functions to deal with general orientation of the patches
function geo_reoriented = reorientation_patches (operations, geometry)
  nrb_patches = [geometry.nurbs];
  for ii = 1:numel(nrb_patches)
    if (operations(ii,1))
      nrb_patches(ii) = nrbreverse (nrb_patches(ii), 1);
    end
    if (operations(ii,2))
      nrb_patches(ii) = nrbreverse (nrb_patches(ii), 2);
    end
    if (operations(ii,3))
      nrb_patches(ii) = nrbtransp (nrb_patches(ii));
    end
  end

  [geo_reoriented, ~, local_interface] = mp_geo_load (nrb_patches);
% FIX: this check can be removed once everything is working
  if (numel (nrb_patches) == 2)
    if (local_interface.side1 ~= 1 || local_interface.side2 ~= 3 || local_interface.ornt ~= 1)
      error('The reorientation is wrong')
    end
  end
end

function knots = knot_vector_reorientation (knots, operations)
  if (operations(1))
    knots{1} = sort (1 - knots{1});
  end
  if (operations(2))
    knots{2} = sort (1-knots{2});
  end
  if (operations(3))
    knots([2 1]) = knots([1 2]);
  end
end

function degree = degree_reorientation (degree, transposition)
  if (transposition)
    degree = degree([2 1]);
  end
end

function indices = indices_reorientation (ndof_dir, operations)
  ndof = prod (ndof_dir);
  indices = reshape (1:ndof, ndof_dir);
  if (operations(1))
    indices = flipud (indices);
  end
  if (operations(2))
    indices = fliplr (indices);
  end
  if (operations(3))
    indices = indices.';
  end   
end
