function export_example_results
% Export the latest verified runs as small, portable publication examples.
% This function reads saved data only; it never evaluates the model.
root=fileparts(fileparts(mfilename('fullpath')));
items={'compare_DE_vs_full_scan','demo','demo_search'; ...
    'compare_chaos_indicators','demo','demo_indicators'; ...
    'compare_chaos_indicators','paper','paper_indicators'};
for k=1:size(items,1)
    files=dir(fullfile(root,'results',items{k,1},items{k,2},'*','result.mat'));
    assert(~isempty(files),'OLG:Export','A completed verification run is missing.');
    [~,ix]=max([files.datenum]); source=fullfile(files(ix).folder,files(ix).name);
    data=load(source,'result'); r=data.result;
    if strcmp(r.mode,'compare_DE_vs_full_scan'), r.comparison=olg.compare_runs(r.summary); end
    dest=fullfile(root,'example_results',items{k,3});
    if ~isfolder(dest), mkdir(dest); end
    writetable(r.summary,fullfile(dest,'summary.csv'));
    writetable(r.comparison,fullfile(dest,'comparison.csv'));
    cfg=r.cfg; cfg.output.directory=fullfile('results',cfg.mode,cfg.profile);
    write_json(fullfile(dest,'configuration.json'),cfg);
    write_json(fullfile(dest,'environment.json'),r.environment);
    if strcmp(r.mode,'compare_DE_vs_full_scan')
        write_json(fullfile(dest,'parallel_pool.json'),r.pool);
        for j=1:numel(r.runs)
            run=r.runs(j); prefix=sprintf('%s_rep%03d',run.method,run.repetition);
            writetable(run.ledger,fullfile(dest,[prefix '.csv']));
            if strcmp(run.method,'de')
                backend=run.backend;
                backend.entryPoint=fullfile('vendor','fex18593','differentialevolution.m');
                fields=fieldnames(backend.parameters);
                for f=1:numel(fields)
                    value=backend.parameters.(fields{f});
                    if isnumeric(value) && isscalar(value) && ~isfinite(value)
                        backend.parameters.(fields{f})=num2str(value);
                    end
                end
                write_json(fullfile(dest,[prefix '_backend.json']),backend);
            end
            if ~isempty(run.discovery)
                path=run.discovery.witness.path;
                writetable(array2table([(0:size(path,1)-1)',path], ...
                    'VariableNames',{'Iteration','C','L'}),fullfile(dest,[prefix '_witness.csv']));
                d=run.discovery.witness.rosensteinDetails;
                writetable(table(d.lags,d.divergence,d.pairCounts, ...
                    'VariableNames',{'Lag','MeanLogDistance','PairCount'}), ...
                    fullfile(dest,[prefix '_rosenstein.csv']));
            end
        end
    else
        writetable(array2table(r.timesSeconds,'VariableNames',r.methodNames), ...
            fullfile(dest,'timing_repetitions.csv'));
        path=r.orbit;
        writetable(array2table([(0:size(path,1)-1)',path], ...
            'VariableNames',{'Iteration','C','L'}),fullfile(dest,'common_orbit.csv'));
    end
    r.cfg.output.directory=dest; r.cfg.output.visible=false; r.cfg.output.enabled=true;
    olg.plot_result(r);
end
end

function write_json(path,data)
% JSON has no Infinity literal; retain the intent of the unbounded override.
if isfield(data,'search') && isinf(data.search.maxEvaluations)
    data.search.maxEvaluations='Inf (capped at the number of grid nodes)';
end
fid=fopen(path,'w'); assert(fid~=-1,'OLG:Export','Cannot write JSON.');
cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(data,'PrettyPrint',true));
end
