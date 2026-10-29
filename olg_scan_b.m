function result=olg_scan_b(b,cfg)
% Evaluate one parameter without running DE or estimating grid-search cost.
if nargin<2, cfg=olg_config('compare_DE_vs_full_scan','paper','full'); end
validateattributes(b,{'numeric'},{'scalar','real','finite','positive'});
assert(strcmp(cfg.mode,'compare_DE_vs_full_scan'),'OLG:Mode','Use the search configuration for a single-b scan.');
v=cfg; v.search.gridMode='full_scan'; olg.validate(v);
f=olg.fast_config(cfg); [~,grid]=olg.grids(cfg);
parallel=olg.fast.olg_parallel_pool(f,olg.phase_tasks(f,grid.count));
folder='';
if cfg.output.enabled
    folder=fullfile(cfg.output.directory,['b_' num2hex(double(b))]);
    if ~isfolder(folder), mkdir(folder); end
    [~,attr]=fileattrib(folder); folder=attr.Name;
    f.evalCheckpoint=fullfile(folder,'evaluation.mat');
end
result=olg.fast.olg_staged_evaluate([f.lambda f.sigma b],grid,f);
result.grid=grid; result.pool=parallel;
if cfg.output.enabled
    olg.fast.olg_atomic_save(fullfile(folder,'result.mat'),struct('result',result,'cfg',cfg,'grid',grid));
end
fprintf('b_L=%.8g | %s | Q %.0f/%.0f | candidate=%d | %.3f committed s\n', ...
    b,f.phaseScan,result.trajectories,grid.count,result.candidate,result.seconds);
end
