% EX_MAXWELL_EIG_MIXED1_CUBE: solve Maxwell eigenproblem in the unit cube, with the first mixed formulation.

% 1) PHYSICAL DATA OF THE PROBLEM
clear problem_data 
% Physical domain, defined as NURBS map given in a text file
problem_data.geo_name = 'geo_cube.txt';

% Type of boundary conditions
problem_data.nmnn_sides   = [];
problem_data.drchlt_sides = [1 2 3 4 5 6];

% Physical parameters
problem_data.c_elec_perm = @(x, y, z) ones(size(x));
problem_data.c_magn_perm = @(x, y, z) ones(size(x));

% 2) CHOICE OF THE DISCRETIZATION PARAMETERS
clear method_data 
method_data.degree     = [2 2 2]; % Degree of the bsplines
method_data.regularity = [1 1 1]; % Regularity of the splines
method_data.nsub       = [4 4 4]; % Number of subdivisions
method_data.nquad      = [3 3 3]; % Points for the Gaussian quadrature rule

% 3) CALL TO THE SOLVER
[geometry, msh, space, sp_mul, eigv, eigf] = ...
                    solve_maxwell_eig_mixed1 (problem_data, method_data);

% 4) POSTPROCESSING
[eigv, perm] = sort (abs(eigv));

fprintf ('First computed eigenvalues: \n')
disp (eigv(1:5))

%!demo
%! ex_maxwell_eig_mixed1_cube

%!test
%! problem_data.geo_name = 'geo_cube.txt';
%! problem_data.nmnn_sides   = [];
%! problem_data.drchlt_sides = [1 2 3 4 5 6];
%! problem_data.c_elec_perm = @(x, y, z) ones(size(x));
%! problem_data.c_magn_perm = @(x, y, z) ones(size(x));
%! method_data.degree     = [2 2 2]; % Degree of the bsplines
%! method_data.regularity = [1 1 1]; % Regularity of the splines
%! method_data.nsub       = [4 4 4]; % Number of subdivisions
%! method_data.nquad      = [3 3 3]; % Points for the Gaussian quadrature rule
%! [geometry, msh, space, sp_mul, eigv, eigf] = solve_maxwell_eig_mixed1 (problem_data, method_data);
%! [eigv, perm] = sort (eigv);
%! eigv = eigv(eigv>0 & eigv<Inf);
%! assert (msh.nel, 64)
%! assert (space.ndof, 540)
%! assert (sp_mul.ndof, 216)
%! assert (eigv(1:11)/pi^2, [2.00119983107630 2.00119983107631 2.00119983107631 ...
%! 3.00179974661447 3.00179974661447 5.05344726123167 5.05344726123167 5.05344726123167 5.05344726123167 5.05344726123167 5.05344726123167]', 1e-13)%! assert (nzeros, 64)
