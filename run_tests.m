function results=run_tests
% Run portable checks; optional MEX tests explicitly skip when not built.
root=fileparts(mfilename('fullpath')); addpath(root);
results=runtests(fullfile(root,'tests'));
assert(~any([results.Failed]),'OLG:Tests','One or more tests failed.');
if any([results.Incomplete])
    fprintf('%d optional checks skipped/incomplete; inspect the test report.\n',sum([results.Incomplete]));
end
end
