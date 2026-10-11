function result = olg_show_results(folder)
% Load completed unified results and redraw plots without any simulations.
data=load(fullfile(folder,'result.mat'),'result'); result=data.result;
result.cfg.output.directory=folder;
if strcmp(result.mode,'compare_DE_vs_full_scan'), result.comparison=olg.compare_runs(result.summary); end
disp(result.summary); disp(result.comparison);
olg.plot_result(result);
end
