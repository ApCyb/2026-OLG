function result = search_experiment(cfg)
[B,U]=olg.grids(cfg);
pool=olg.pool(cfg.parallel,min(U.count,cfg.search.stateBatchSize));
budget=min(numel(B),cfg.search.maxEvaluations);
critical=1/cfg.model.beta;
fprintf('b grid: %d nodes in %s%.8g, %.8g], h=%.8g; budget=%d per method.\n', ...
    numel(B),left_bracket(cfg.search.includeLowerEndpoint), ...
    cfg.search.bRange(1),cfg.search.bRange(2),cfg.search.bStep,budget);
fprintf('b <= 1/beta: %d nodes; b > 1/beta: %d nodes. No analytical exclusion is applied.\n', ...
    sum(B<=critical),sum(B>critical));
fprintf('Q: %d x %d = %.0f initial states; batches of %d; full traversal per b.\n', ...
    U.shape(1),U.shape(2),U.count,cfg.search.stateBatchSize);
runs=cell(2*cfg.search.repetitions,1); row=0;
% Alternate execution order across repetitions to reduce a fixed order effect.
for rep=1:cfg.search.repetitions
    methods={'de','full_scan'};
    if mod(rep,2)==0, methods=fliplr(methods); end
    for m=1:2
        row=row+1; name=methods{m};
        runs{row}=olg.search(name,rep,B,U,budget,cfg);
    end
end
R=[runs{:}]; summaries=arrayfun(@(r)r.summary,R,'UniformOutput',false);
summary=vertcat(summaries{:});
comparison=olg.compare_runs(summary);
result=struct('mode',cfg.mode,'runs',R,'summary',summary,'comparison',comparison, ...
    'bValues',B,'initialStates',U,'criticalB',critical,'pool',pool);
if cfg.output.enabled
    writetable(comparison,fullfile(cfg.output.directory,'comparison.csv'));
end
end

function s=left_bracket(include)
if include, s='['; else, s='('; end
end
