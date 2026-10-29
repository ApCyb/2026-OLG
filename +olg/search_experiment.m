function result=search_experiment(cfg)
[B,U]=olg.grids(cfg); f=olg.fast_config(cfg);
signature=olg.fast.olg_protocol(f,U); signature.engine='FEX18593-1.16.0';
if cfg.output.enabled
    file=fullfile(cfg.output.directory,'configuration.mat');
    if cfg.output.resume && isfile(file)
        old=load(file,'signature');
        assert(isequaln(signature,old.signature),'OLG:ResumeMismatch','Use a new output directory for changed settings.');
    end
    olg.fast.olg_atomic_save(file,struct('cfg',cfg,'signature',signature));
end
pool=olg.fast.olg_parallel_pool(f,olg.phase_tasks(f,U.count));
cfg.preparedFast=f; budget=min(numel(B),cfg.search.maxEvaluations);
fprintf('b grid: %d nodes, first %.8g; Q: %.0f states; grid mode: %s.\n',numel(B),B(1),U.count,cfg.search.gridMode);
runs={};
for rep=1:cfg.search.repetitions
    methods={'de'};
    if strcmp(cfg.search.gridMode,'full_scan')
        methods={'de','full_scan'}; if mod(rep,2)==0, methods=fliplr(methods); end
    end
    for m=1:numel(methods)
        runs{end+1}=olg.search(methods{m},rep,B,U,budget,cfg); %#ok<AGROW>
    end
end
R=[runs{:}]; summaries=arrayfun(@(r)r.summary,R,'UniformOutput',false); summary=vertcat(summaries{:});
result=struct('mode',cfg.mode,'runs',R,'summary',summary,'comparison',table, ...
    'bValues',B,'initialStates',U,'criticalB',1/cfg.model.beta,'pool',pool);
result.resolvedBackends=struct('integrator',f.integrator,'zeroOneBackend',f.zeroOneBackend, ...
    'neighborMethod',f.rosenstein.neighborMethod,'poolType',f.poolType);
if strcmp(cfg.search.gridMode,'estimate')
    result=olg.grid_cost_estimate(result,cfg);
    result.comparisonKind='measured_DE_estimated_grid_cost';
else
    result.comparison=olg.compare_runs(summary); result.comparisonKind='measured_DE_measured_full_scan';
end
if cfg.output.enabled
    writetable(result.comparison,fullfile(cfg.output.directory,'comparison.csv'));
end
end
