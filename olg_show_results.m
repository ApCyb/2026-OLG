function result=olg_show_results(folder)
% Read completed results only; never resumes or computes trajectories.
data=load(fullfile(folder,'result.mat'),'result'); result=data.result;
result.cfg.output.directory=folder;
disp(result.summary); disp(result.comparison); olg.plot_result(result);
end
