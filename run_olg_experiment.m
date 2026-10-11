function result = run_olg_experiment(cfg)
%RUN_OLG_EXPERIMENT Validate configuration and run one selected experiment.
% Each invocation writes a new run subdirectory; previous data are retained.
if nargin == 0, cfg = olg_config; end
olg.validate(cfg);
if cfg.output.enabled
    parent = cfg.output.directory;
    if ~isfolder(parent), mkdir(parent); end
    [~,suffix] = fileparts(tempname(parent));
    cfg.output.directory = fullfile(parent, ...
        [char(datetime('now','Format','yyyyMMdd_HHmmss')) '_' suffix]);
    mkdir(cfg.output.directory);
    [~,folder]=fileattrib(cfg.output.directory);
    cfg.output.directory=folder.Name; % DE runs inside a private temporary folder.
end
switch cfg.mode
    case 'compare_DE_vs_full_scan'
        result = olg.search_experiment(cfg);
    case 'compare_chaos_indicators'
        result = olg.timing_experiment(cfg);
end
result.cfg = cfg;
result.environment = struct('matlab',version,'computer',computer, ...
    'created',char(datetime('now','Format','yyyyMMdd''T''HHmmss')));
if cfg.output.enabled
    save(fullfile(cfg.output.directory,'result.mat'),'result','-v7.3');
    writetable(result.summary,fullfile(cfg.output.directory,'summary.csv'));
    fprintf('Results saved: %s\n',cfg.output.directory);
end
disp(result.summary);
if cfg.output.plots
    olg.plot_result(result);
end
end
