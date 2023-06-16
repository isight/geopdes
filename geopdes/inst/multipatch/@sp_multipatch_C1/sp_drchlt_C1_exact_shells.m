function [u_drchlt, drchlt_dofs, kernel_info] = sp_drchlt_C1_exact_shells (space, msh, refs, uex)

% TODO: IT WILL ALWAYS USE ALL THE COMPONENTS ON EACH SIDE (leave it like that)

% refs should be the whole boundary, for now
error ('This function is not implemented correctly yet')

M = spalloc (msh.rdim*space.ndof, msh.rdim*space.ndof, msh.rdim*space.ndof);
rhs = zeros (msh.rdim*space.ndof, 1);

drchlt_dofs = [];

boundaries = msh.boundaries;
for iref = 1:numel(refs)
%   href = @(varargin) h(varargin{:}, iref);
  for bnd_side = 1:boundaries(refs(iref)).nsides
    iptc = boundaries(refs(iref)).patches(bnd_side);
    iside = boundaries(refs(iref)).faces(bnd_side);

    msh_side = msh.msh_patch{iptc}.boundary(iside);
    sp_bnd = space.sp_patch{iptc}.boundary(iside);

    Cpatch_bnd = space.Cpatch{iptc}(sp_bnd.dofs,:);
    [~,icol] = find (Cpatch_bnd);
    
    drchlt_dofs = union (drchlt_dofs, icol);
    
    M_scalar = Cpatch_bnd.' * op_u_v_tp (sp_bnd, sp_bnd, msh_side) * Cpatch_bnd;
    M = M + blkdiag (M_scalar, M_scalar, M_scalar);
    Cpatch_vector = blkdiag (Cpatch_bnd, Cpatch_bnd, Cpatch_bnd);
    rhs = rhs + Cpatch_vector.' * op_f_v_tp_vector (sp_bnd, msh_side, uex);
  end
end

dofs_to_remove = [];
vertices_numbers = [];
row_indices = [];
count_vert = 0;
count_fun = 0;

% Check the kernel of vertex functions on Dirichlet boundary vertices
% Pick up the basis function with the max. abs. coeff in the kernel, 
%  remove it from drchlt_dofs, and add the function in the kernel into the
%  internal part (it goes in the output)
B_change_local = [];
n_boundaries = numel(msh.boundaries); % number of boundary edges
global_refs = numel(space.interfaces) - n_boundaries + refs; % global numbering of Dirichlet boundary edges

for iv = 1 : numel(space.vertices)
  % Loop just over Dirichlet boundary vertices
  if ~isempty(intersect(global_refs, space.vertices(iv).edges))
    if (space.vertices(iv).boundary_vertex)
      patches = space.vertices(iv).patches([1 end]);

      operations = space.vertices(iv).patch_reorientation([1 end], :);
      indices_loc_R = indices_reorientation(space.sp_patch{patches(1)}.ndof_dir, operations(1, :));
      indices_loc_L = indices_reorientation(space.sp_patch{patches(2)}.ndof_dir, operations(2, :));
      indices_loc_R = indices_loc_R(:);
      indices_loc_L = indices_loc_L(:);

      Cpatch_ind_R = indices_loc_R([1 2 3]);
%       Cpatch_ind_L = indices_loc_L([1 space.sp_patch{patches(1)}.ndof_dir(1)+1 2*space.sp_patch{patches(1)}.ndof_dir(1)+1]);
      Cpatch_ind_L = indices_loc_L([space.sp_patch{patches(1)}.ndof_dir(1)+1 2*space.sp_patch{patches(1)}.ndof_dir(1)+1]);

      M_ker = [space.Cpatch{patches(1)}(Cpatch_ind_R, space.dofs_on_vertex{iv}); ...
               space.Cpatch{patches(2)}(Cpatch_ind_L, space.dofs_on_vertex{iv})];

      ker = null(full(M_ker));
      if (~isempty(ker))
        nfun = size(ker,2);
        [~, ind] = max(abs(ker)); % TODO: NOT A GOOD CHOICE (it may be repeated)

        row_inds = count_vert*6 + (1:6);
        B_change_local = blkdiag (B_change_local, ker);

        dofs_on_vertex = space.dofs_on_vertex{iv};
        vertices_numbers(count_fun+(1:nfun)) = iv;
        dofs_to_remove(count_fun+(1:nfun)) = dofs_on_vertex(ind);
        row_indices(row_inds) = dofs_on_vertex;
        count_vert = count_vert + 1;
        count_fun  = count_fun + nfun;
      end
    end
  end
end

kernel_info = struct ('vertices_numbers', vertices_numbers, 'all_vertex_dofs', row_indices, 'quasi_interior_dofs', dofs_to_remove, 'B_change_local', sparse(B_change_local));

drchlt_dofs = setdiff(drchlt_dofs, dofs_to_remove);
drchlt_dofs = [drchlt_dofs(:); drchlt_dofs(:)+space.ndof; drchlt_dofs(:)+2*space.ndof];

u_drchlt = M(drchlt_dofs,drchlt_dofs) \ rhs(drchlt_dofs);

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
