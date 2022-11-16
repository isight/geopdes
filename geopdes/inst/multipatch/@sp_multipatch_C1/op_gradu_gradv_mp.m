% OP_GRADU_GRADV_MP: assemble the stiffness matrix A = [a(i,j)], a(i,j) = (epsilon grad u_j, grad v_i), in a multipatch domain.
%
%   mat = op_gradu_gradv_mp (spu, spv, msh, [epsilon], [patches]);
%
% INPUT:
%
%   spu:     object representing the space of trial functions (see sp_multipatch_C1)
%   spv:     object representing the space of test functions (see sp_multipatch_C1)
%   msh:     object defining the domain partition and the quadrature rule (see msh_multipatch)
%   epsilon: function handle to compute the diffusion coefficient. Equal to one if left empty.
%   patches: list of patches where the integrals have to be computed. By default, all patches are selected.
%
% OUTPUT:
%
%   mat:    assembled stiffness matrix
% 
% Copyright (C) 2015, 2016, 2017, 2022 Rafael Vazquez
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

function A = op_gradu_gradv_mp (spu, spv, msh, coeff, patch_list)

  if (nargin < 5)
    patch_list = 1:msh.npatch;
  end

  if ((spu.npatch ~= spv.npatch) || (spu.npatch ~= msh.npatch))
    error ('op_gradu_gradv_mp: the number of patches does not coincide')
  end

  A = sparse (spv.ndof, spu.ndof);

  for iptc = patch_list
    if (nargin < 4 || isempty (coeff))
      Ap = op_gradu_gradv_tp (spu.sp_patch{iptc}, spv.sp_patch{iptc}, msh.msh_patch{iptc});
    else
      Ap = op_gradu_gradv_tp (spu.sp_patch{iptc}, spv.sp_patch{iptc}, msh.msh_patch{iptc}, coeff);
    end
    
    A(spv.Cpatch_cols{iptc},spu.Cpatch_cols{iptc}) = ...
      A(spv.Cpatch_cols{iptc},spu.Cpatch_cols{iptc}) + spv.Cpatch{iptc}.' * Ap * spu.Cpatch{iptc};
  end

end
