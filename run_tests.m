function results=run_tests
% Run the local regression suite from the package root.
root=fileparts(mfilename('fullpath')); addpath(root);
results=runtests(fullfile(root,'tests'));
assertSuccess(results);
end
