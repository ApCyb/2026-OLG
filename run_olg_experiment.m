function result=run_olg_experiment(cfg)
% Unified October 24 experiments. Stable output directory enables resume.
if nargin==0, cfg=olg_config; end
olg.validate(cfg);
if cfg.output.enabled
    if ~isfolder(cfg.output.directory), mkdir(cfg.output.directory); end
    [~,folder]=fileattrib(cfg.output.directory); cfg.output.directory=folder.Name;
end
if strcmp(cfg.mode,'compare_DE_vs_full_scan')
    result=olg.search_experiment(cfg);
else
    result=olg.timing_experiment(cfg);
end
result.cfg=cfg;
result.environment=struct('matlab',version,'computer',computer, ...
    'created',char(datetime('now','Format','yyyyMMdd''T''HHmmss')));
if cfg.output.enabled
    olg.fast.olg_atomic_save(fullfile(cfg.output.directory,'result.mat'),struct('result',result));
    writetable(result.summary,fullfile(cfg.output.directory,'summary.csv'));
    fprintf('Results saved: %s\n',cfg.output.directory);
end
disp(result.summary);
if cfg.output.plots, olg.plot_result(result); end
end
