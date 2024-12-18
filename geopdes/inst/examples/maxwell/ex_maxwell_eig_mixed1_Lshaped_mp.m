% EX_MAXWELL_EIG_MIXED1_LSHAPED_MP: solve Maxwell eigenproblem in the multipatch L-shaped domain with the first mixed formulation.

% 1) PHYSICAL DATA OF THE PROBLEM
clear problem_data 
% Physical domain, defined as NURBS map given in a text file
problem_data.geo_name = 'geo_Lshaped_mp.txt';
%problem_data.geo_name = 'geo_Lshaped_mp_b.txt';
%problem_data.geo_name = 'geo_Lshaped_mp_c.txt';

% Type of boundary conditions
problem_data.nmnn_sides   = [];
problem_data.drchlt_sides = [1 2 3 4 5 6];

% Physical parameters
problem_data.c_elec_perm = @(x, y) ones(size(x));
problem_data.c_magn_perm = @(x, y) ones(size(x));

% 2) CHOICE OF THE DISCRETIZATION PARAMETERS
clear method_data 
method_data.degree     = [3 3];     % Degree of the bsplines
method_data.regularity = [2 2];     % Regularity of the splines
method_data.nsub       = [6 6];     % Number of subdivisions
method_data.nquad      = [4 4];     % Points for the Gaussian quadrature rule

% 3) CALL TO THE SOLVER
[geometry, msh, space, sp_mul, eigv, eigf] = ...
                  mp_solve_maxwell_eig_mixed1 (problem_data, method_data);

% 4) POSTPROCESSING
[eigv, perm] = sort (abs(eigv));

fprintf ('First computed eigenvalues: \n')
disp (eigv(1:5))

figure
sp_plot_solution (eigf(1:space.ndof,perm(8)), space, geometry, [30 30])
title ('8^{th} eigenfunction')

%!demo
%! ex_maxwell_eig_mixed1_Lshaped_mp

%!test
%! problem_data.geo_name = 'geo_Lshaped_mp.txt';
%! problem_data.nmnn_sides   = [];
%! problem_data.drchlt_sides = [1 2 3 4 5 6];
%! problem_data.c_elec_perm = @(x, y) ones(size(x));
%! problem_data.c_magn_perm = @(x, y) ones(size(x));
%! method_data.degree     = [3 3];     % Degree of the bsplines
%! method_data.regularity = [2 2];     % Regularity of the splines
%! method_data.nsub       = [6 6];     % Number of subdivisions
%! method_data.nquad      = [4 4];     % Points for the Gaussian quadrature rule
%! [geometry, msh, space, sp_mul, eigv, eigf] = ...
%!                   mp_solve_maxwell_eig_mixed1 (problem_data, method_data);
%! [eigv, perm] = sort (eigv);
%! assert (msh.nel, 108)
%! assert (space.ndof, 416)
%! assert (sp_mul.ndof, 225)
%! assert (eigv(1:5), [1.47383596756687; 3.53401518183127; 9.86961195350075; 9.86961195350077; 11.38946326693307], 1e-13)

%!test
%! problem_data.geo_name = 'geo_Lshaped_mp_b.txt';
%! problem_data.nmnn_sides   = [];
%! problem_data.drchlt_sides = [1 2 3 4 5 6];
%! problem_data.c_elec_perm = @(x, y) ones(size(x));
%! problem_data.c_magn_perm = @(x, y) ones(size(x));
%! method_data.degree     = [3 3];     % Degree of the bsplines
%! method_data.regularity = [2 2];     % Regularity of the splines
%! method_data.nsub       = [6 6];     % Number of subdivisions
%! method_data.nquad      = [4 4];     % Points for the Gaussian quadrature rule
%! [geometry, msh, space, sp_mul, eigv, eigf] = ...
%!                   mp_solve_maxwell_eig_mixed1 (problem_data, method_data);
%! [eigv, perm] = sort (eigv);
%! assert (msh.nel, 108)
%! assert (space.ndof, 416)
%! assert (sp_mul.ndof, 225)
%! assert (eigv(1:5), [1.47383596756687; 3.53401518183127; 9.86961195350075; 9.86961195350077; 11.38946326693307], 1e-13)

%!test
%! problem_data.geo_name = 'geo_Lshaped_mp_c.txt';
%! problem_data.nmnn_sides   = [];
%! problem_data.drchlt_sides = [1 2 3 4 5 6];
%! problem_data.c_elec_perm = @(x, y) ones(size(x));
%! problem_data.c_magn_perm = @(x, y) ones(size(x));
%! method_data.degree     = [3 3];     % Degree of the bsplines
%! method_data.regularity = [2 2];     % Regularity of the splines
%! method_data.nsub       = [6 6];     % Number of subdivisions
%! method_data.nquad      = [4 4];     % Points for the Gaussian quadrature rule
%! [geometry, msh, space, sp_mul, eigv, eigf] = ...
%!                   mp_solve_maxwell_eig_mixed1 (problem_data, method_data);
%! [eigv, perm] = sort (eigv);
%! eigv = eigv(eigv>0 & eigv<Inf);
%! assert (msh.nel, 108)
%! assert (space.ndof, 416)
%! assert (sp_mul.ndof, 225)
%! assert (eigv(1:5), [1.47383596756687; 3.53401518183127; 9.86961195350075; 9.86961195350077; 11.38946326693307], 1e-13)
