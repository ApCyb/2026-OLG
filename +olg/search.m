function out = search(method,rep,B,U,budget,cfg)
% The external DE engine and the scan use the same evaluator and ledger.
% Every objective call, including initialization and duplicates, is charged.
s=cfg.search;
names={'Evaluation','Generation','B','Score','Candidate','CandidateCount', ...
    'CheapSurvivors','FullSurvivors','Trajectories','OrbitSteps','TangentSteps', ...
    'ZeroOneCalls','SALICalls','ConDNCalls','FTLECalls','EvaluationSeconds', ...
    'ElapsedSeconds','WitnessC','WitnessL','K01','SALI','ConDN','RosensteinLLE','RosensteinR2', ...
    'PlannedStates','CompleteStateGrid','FirstCandidateStateIndex','FirstCandidateDetectionSeconds'};
ledger=zeros(budget,numel(names)); count=0; clock=tic; discovery=[];
if strcmp(method,'de')
    backend=olg.fex_de(B,s,budget,rep,@record_evaluation);
elseif strcmp(method,'full_scan')
    backend=struct('name','Ascending full grid scan');
    for j=1:budget
        [~,candidate]=record_evaluation(B(j),0);
        if candidate, break; end
    end
else
    error('OLG:Method','Unknown search method.');
end
elapsed=toc(clock); ledger=array2table(ledger(1:count,:),'VariableNames',names);
found=~isempty(discovery); bFound=NaN; firstEval=NaN; firstSeconds=NaN;
if found
    bFound=discovery.b; firstEval=count; firstSeconds=ledger.FirstCandidateDetectionSeconds(end);
    reason="candidate_found";
else
    reason="budget_exhausted";
end
summary=table(string(method),rep,found,reason,count, ...
    firstEval,firstSeconds,bFound, ...
    strcmp(method,'de') && found && count<=s.population, ...
    sum(ledger.OrbitSteps),sum(ledger.TangentSteps),sum(ledger.EvaluationSeconds), ...
    elapsed,sum(ledger.FTLECalls),sum(ledger.B<=1/cfg.model.beta),sum(ledger.Trajectories), ...
    'VariableNames',{'Method','Repetition','CandidateFound','StopReason','Evaluations', ...
    'FirstCandidateEvaluation','FirstCandidateSeconds','CandidateB','FoundDuringInitialization', ...
    'OrbitSteps','TangentSteps','EvaluationSeconds','ElapsedSeconds','FTLECalls','LowRegionEvaluations','Trajectories'});
out=struct('method',method,'repetition',rep,'ledger',ledger,'discovery',discovery, ...
    'summary',summary,'completed',true,'backend',backend);
if cfg.output.enabled
    writetable(ledger,fullfile(cfg.output.directory,sprintf('%s_rep%03d.csv',method,rep)));
    save(fullfile(cfg.output.directory,sprintf('%s_rep%03d_completed.mat',method,rep)),'out','-v7.3');
end

    function [score,candidate]=record_evaluation(b,generation)
        parameterStart=toc(clock);
        e=olg.evaluate(b,U,cfg); count=count+1; i=count;
        score=e.score; candidate=e.candidate;
        w=e.witness; fitR2=NaN;
        if isfield(w.rosensteinDetails,'rSquared'), fitR2=w.rosensteinDetails.rSquared; end
        ledger(i,:)=[i,generation,b,e.score,e.candidate,e.candidateCount, ...
            e.cheapSurvivors,e.fullSurvivors,e.trajectories,e.orbitSteps,e.tangentSteps, ...
            e.indicatorCalls,e.seconds,toc(clock),w.x0,w.values,fitR2, ...
            e.plannedStates,e.completeStateGrid,e.firstCandidateStateIndex, ...
            parameterStart+e.firstCandidateBatchSeconds];
        if i==1 || mod(i,s.progressEvery)==0 || e.candidate
            fprintf('%s | repetition %d | %d/%d | b=%.8g | candidate=%d | %.2f s\n', ...
                method,rep,i,budget,b,e.candidate,ledger(i,17));
        end
        if e.candidate, discovery=e; end
        if cfg.output.enabled && (mod(i,s.progressEvery)==0 || e.candidate || i==budget)
            checkpoint=struct('cfg',cfg,'method',method,'repetition',rep, ...
                'ledger',array2table(ledger(1:i,:),'VariableNames',names), ...
                'discovery',discovery,'completed',logical(e.candidate || i==budget));
            save(fullfile(cfg.output.directory,sprintf('%s_rep%03d.mat',method,rep)), ...
                'checkpoint','-v7.3');
        end
    end
end
