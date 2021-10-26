function [u_drchlt, drchlt_dofs] = sp_bilaplacian_drchlt_C1 (space, msh, refs, h, dudn)

% refs should be the whole boundary, for now
M = spalloc (space.ndof, space.ndof, space.ndof);
rhs = zeros (space.ndof, 1);

M2 = spalloc (space.ndof, space.ndof, space.ndof);
rhs2 = zeros (space.ndof, 1);

drchlt_dofs = [];
drchlt_dofs2 = [];

boundaries = msh.boundaries;
for iref = refs
  href = @(varargin) h(varargin{:}, iref);
  for bnd_side = 1:boundaries(iref).nsides
    iptc_bnd = sum([boundaries(1:iref-1).nsides]) + bnd_side;
    iptc = boundaries(iref).patches(bnd_side);
    iside = boundaries(iref).faces(bnd_side);

    msh_side = msh_eval_boundary_side (msh.msh_patch{iptc}, iside);
    msh_side_from_interior = msh_boundary_side_from_interior (msh.msh_patch{iptc}, iside);
    sp_bnd = space.sp_patch{iptc}.constructor (msh_side_from_interior);
    sp_bnd_struct = sp_precompute (sp_bnd, msh_side_from_interior, 'value', true, 'gradient', true);

    [~,icol] = find (space.Cpatch{iptc}(sp_bnd.boundary(iside).dofs,:));
    [~,jcol] = find (space.Cpatch{iptc}(sp_bnd.boundary(iside).adjacent_dofs,:));
    
    drchlt_dofs = union (drchlt_dofs, icol);
    drchlt_dofs2 = union (drchlt_dofs2, jcol);
    
    for idim = 1:msh.rdim
      x{idim} = reshape (msh_side.geo_map(idim,:,:), msh_side.nqn, msh_side.nel);
    end
    coeff_at_qnodes = ones (size(x{1}));
    dudn_at_qnodes = dudn (x{:},iref);

    M = M + space.Cpatch{iptc}.' * op_u_v (sp_bnd_struct, sp_bnd_struct, msh_side, coeff_at_qnodes) * space.Cpatch{iptc};
    rhs = rhs + space.Cpatch{iptc}.' * op_f_v (sp_bnd_struct, msh_side, href(x{:}));
    
    M2 = M2 + space.Cpatch{iptc}.' * op_gradu_n_gradv_n (sp_bnd_struct, sp_bnd_struct, msh_side, coeff_at_qnodes) * space.Cpatch{iptc};
    rhs2 = rhs2 + space.Cpatch{iptc}.' * op_gradv_n_f (sp_bnd_struct, msh_side, dudn_at_qnodes); % I am missing the other part of the vector. It is in M2 :-)
    
  end
end

u_drchlt = M(drchlt_dofs, drchlt_dofs) \ rhs(drchlt_dofs, 1);

uu = sparse (space.ndof, 1);
uu(drchlt_dofs) = u_drchlt;

drchlt_dofs2 = setdiff (drchlt_dofs2, drchlt_dofs);
rhs2 = rhs2 - M2 * uu;
u_drchlt2 = M2(drchlt_dofs2, drchlt_dofs2) \ rhs2(drchlt_dofs2);

uu(drchlt_dofs2) = u_drchlt2;

drchlt_dofs = union (drchlt_dofs, drchlt_dofs2);
u_drchlt = uu(drchlt_dofs);

end