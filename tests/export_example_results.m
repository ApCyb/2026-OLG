function export_example_results
% Export completed October 26 integration checks, never launch simulations.
root=fileparts(fileparts(mfilename('fullpath')));
for item={'timing_demo','timing_paper','measured_threads','estimated_processes'}
    name=item{1}; source=fullfile(root,'results','release_20261026',name,'result.mat');
    data=load(source,'result'); r=data.result;
    dest=fullfile(root,'example_results','release_20261026',name);
    if ~isfolder(dest), mkdir(dest); end
    writetable(r.summary,fullfile(dest,'summary.csv'));
    writetable(r.comparison,fullfile(dest,'comparison.csv'));
    c=r.cfg; c.output.directory=fullfile('results','release_20261026',name);
    if isinf(c.search.maxEvaluations), c.search.maxEvaluations='Inf, capped at b-grid size'; end
    json(fullfile(dest,'configuration.json'),c);
    json(fullfile(dest,'environment.json'),r.environment);
    if strcmp(r.mode,'compare_DE_vs_full_scan')
        json(fullfile(dest,'parallel_pool.json'),r.pool);
        for k=1:numel(r.runs)
            run=r.runs(k); prefix=sprintf('%s_rep%03d',run.method,run.repetition);
            writetable(run.ledger,fullfile(dest,[prefix '.csv']));
            if strcmp(run.method,'de')
                backend=run.backend; backend.entryPoint='vendor/fex18593/differentialevolution.m';
                fields=fieldnames(backend.parameters);
                for f=1:numel(fields)
                    value=backend.parameters.(fields{f});
                    if isnumeric(value) && isscalar(value) && ~isfinite(value), backend.parameters.(fields{f})=num2str(value); end
                end
                json(fullfile(dest,[prefix '_backend.json']),backend);
            end
            if ~isempty(run.discovery)
                d=run.discovery.paths;
                writetable(table((1:numel(d.series))',d.series,'VariableNames',{'Iteration','C'}), ...
                    fullfile(dest,[prefix '_witness_C.csv']));
                q=d.confirmation;
                writetable(table(q.lags,q.divergence,q.pairs, ...
                    'VariableNames',{'Lag','MeanLogDistance','PairCount'}),fullfile(dest,[prefix '_rosenstein.csv']));
                json(fullfile(dest,[prefix '_diagnostics.json']),d.diagnostics);
            end
        end
        if isfield(r,'gridEstimates')
            writetable(r.probes,fullfile(dest,'grid_probes.csv'));
            writetable(r.gridEstimates,fullfile(dest,'estimated_grid_cost.csv'));
            writetable(r.gridStrata,fullfile(dest,'grid_cost_strata.csv'));
        end
    else
        writetable(array2table(r.timesSeconds,'VariableNames',r.methodNames),fullfile(dest,'timing_repetitions.csv'));
    end
    r.cfg.output.enabled=true; r.cfg.output.visible=false; r.cfg.output.directory=dest;
    olg.plot_result(r);
end
% Small full maps are portable read-only examples; preserve checkpoint/basin names.
for name={'q_first_hit','q_full_serial','q_full_processes'}
    input=fullfile(root,'results','release_20261026',name{1});
    files=dir(fullfile(input,'b_*','result.mat')); assert(numel(files)==1);
    data=load(fullfile(files(1).folder,'result.mat')); r=data.result;
    dest=fullfile(root,'example_results','release_20261026',name{1});
    if ~isfolder(dest), mkdir(dest); end
    info=table(string(r.phaseScan),r.trajectories,r.candidateCount,r.firstCandidate.seconds,r.seconds, ...
        'VariableNames',{'PhaseScan','Trajectories','Candidates','FirstCandidateSeconds','TotalSeconds'});
    writetable(info,fullfile(dest,'summary.csv'));
    cfg=data.cfg; cfg.output.directory=fullfile('results','release_20261026',name{1});
    if isinf(cfg.search.maxEvaluations), cfg.search.maxEvaluations='Inf, capped at b-grid size'; end
    json(fullfile(dest,'configuration.json'),cfg);
    if strcmp(r.phaseScan,'full')
        copyfile(fullfile(files(1).folder,'evaluation.mat'),fullfile(dest,'evaluation.mat'));
        basin=fullfile(dest,'evaluation_basin');
        copyfile(fullfile(files(1).folder,'evaluation_basin'),basin);
        olg_plot_phase_map(basin,false);
    end
end
end
function json(file,data)
f=fopen(file,'w'); assert(f~=-1,'OLG:Export','Cannot open JSON output.');
cleanup=onCleanup(@()fclose(f)); fprintf(f,'%s\n',jsonencode(data,'PrettyPrint',true));
end
