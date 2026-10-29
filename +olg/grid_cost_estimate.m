function result=grid_cost_estimate(result,cfg)
% Measured probes and explicitly hypothetical ascending-grid extrapolations.
f=cfg.preparedFast; f.bValues=result.bValues;
plan=olg.fast.olg_staged_probe_plan(f); probes=struct([]);
for j=1:height(plan)
    checkpoint='';
    if cfg.output.enabled
        checkpoint=fullfile(cfg.output.directory,'grid_probes',sprintf('b_%06d.mat',plan.gridIndex(j)));
    end
    e=olg.evaluate(plan.b_L(j),result.initialStates,cfg,checkpoint);
    row=struct('gridIndex',plan.gridIndex(j),'b_L',plan.b_L(j), ...
        'firstPrefix',plan.firstPrefix(j),'regime',plan.regime(j), ...
        'candidate',e.candidate,'seconds',e.seconds,'trajectories',e.trajectories, ...
        'steps',e.steps,'zeroOneCalls',e.zeroOneCalls,'rosensteinCalls',e.rosensteinCalls, ...
        'exhaustedPhasePool',e.exhaustedPhasePool,'integrationWorkerSeconds',e.integrationSeconds, ...
        'zeroOneWorkerSeconds',e.zeroOneSeconds,'confirmationWorkerSeconds',e.confirmationSeconds, ...
        'diagnosticsWorkerSeconds',e.diagnosticsSeconds,'firstCandidateSeconds',NaN);
    if e.candidate, row.firstCandidateSeconds=e.firstCandidate.seconds; end
    probes=[probes;row]; %#ok<AGROW>
    if cfg.output.enabled, writetable(struct2table(probes),fullfile(cfg.output.directory,'grid_probes.csv')); end
end
P=struct2table(probes); B=result.bValues;
[~,target]=min(abs(B-cfg.search.historicalCandidateB)); assumed=target;
firstCandidates=P.gridIndex(P.firstPrefix & P.candidate);
if ~isempty(firstCandidates), assumed=min(firstCandidates); end
simple=assumed*mean(P.seconds(P.firstPrefix & P.gridIndex<=assumed));
edges=[-Inf cfg.search.gridRegimeBreaks(:)' Inf]; stratified=0; strata=struct([]);
for k=1:numel(edges)-1
    count=sum(B>=edges(k) & B<edges(k+1) & (1:numel(B))'<=assumed);
    measured=P.seconds(P.regime==k & P.gridIndex<=assumed);
    estimate=0; if count>0, estimate=count*mean(measured); end
    stratified=stratified+estimate;
    strata=[strata;struct('regime',k,'firstB',edges(k),'nextBExclusive',edges(k+1), ...
        'assumedEvaluations',count,'measuredProbes',numel(measured), ...
        'meanProbeSeconds',mean(measured),'estimatedSeconds',estimate)]; %#ok<AGROW>
end
targetRow=find(P.gridIndex==target,1); targetCandidate=NaN;
if ~isempty(targetRow), targetCandidate=double(P.candidate(targetRow)); end
estimates=table(["first_nodes_extrapolation";"regime_probes_extrapolation"], ...
    repmat(assumed,2,1),[simple;stratified],repmat(cfg.search.historicalCandidateB,2,1), ...
    repmat(target,2,1),repmat(any(P.candidate & P.gridIndex<target),2,1), ...
    repmat(~isempty(targetRow),2,1),repmat(targetCandidate,2,1), ...
    'VariableNames',{'estimateType','assumedEvaluations','estimatedSearchSeconds', ...
    'historicalCandidateB','historicalStoppingIndex','observedEarlierCandidate', ...
    'historicalBChecked','candidateAtHistoricalBUnderNewProtocol'});
S=result.summary; meanNew=mean(S.UniqueEvaluations); meanRequests=mean(S.Evaluations); meanTime=mean(S.ElapsedSeconds);
if ~all(S.CandidateFound), meanNew=NaN; meanRequests=NaN; meanTime=NaN; end
estimates.evaluationRatioToMeanDE=estimates.assumedEvaluations/meanNew;
estimates.requestRatioToMeanDE=estimates.assumedEvaluations/meanRequests;
estimates.timeRatioToMeanDE=estimates.estimatedSearchSeconds/meanTime;
result.probes=P; result.gridStrata=struct2table(strata); result.gridEstimates=estimates;
result.comparison=estimates;
result.deSummary=table(height(S),sum(S.CandidateFound),mean(S.CandidateFound), ...
    mean(S.Evaluations),mean(S.UniqueEvaluations),mean(S.CacheHits),mean(S.ElapsedSeconds), ...
    'VariableNames',{'completedRuns','successes','successRate','meanEvaluationsUsed', ...
    'meanUniqueEvaluations','meanCacheHits','meanSearchSecondsUsed'});
result.deSummary.meanFirstCandidateSearchSecondsSuccessfulOnly=mean(S.FirstCandidateSeconds(S.CandidateFound));
if cfg.output.enabled
    writetable(S,fullfile(cfg.output.directory,'actual_de_runs.csv'));
    writetable(result.deSummary,fullfile(cfg.output.directory,'de_summary.csv'));
    writetable(estimates,fullfile(cfg.output.directory,'estimated_grid_cost.csv'));
    writetable(result.gridStrata,fullfile(cfg.output.directory,'grid_cost_strata.csv'));
end
fprintf('Grid costs are EXTRAPOLATIONS from measured probes; no completed ascending scan is claimed.\n');
end
