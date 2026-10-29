function out=search(method,rep,B,U,budget,cfg)
% Restartable FEX DE / ascending scan; cached objectives are explicitly charged.
f=cfg.preparedFast; signature=olg.fast.olg_protocol(f,U);
signature.engine='FEX18593-1.16.0'; signature.method=method; signature.rep=rep;
folder=''; file='';
if cfg.output.enabled
    folder=fullfile(cfg.output.directory,sprintf('%s_rep%03d',method,rep));
    if ~isfolder(folder), mkdir(folder); end
    file=fullfile(folder,'optimizer.mat');
end
L=table; discovery=[]; controllerSeconds=0; backend=struct('name','Ascending full scan');
if cfg.output.enabled && cfg.output.resume && isfile(file)
    saved=load(file,'state');
    assert(isequaln(saved.state.signature,signature),'OLG:ResumeMismatch','Search configuration differs. Use a new output directory.');
    L=saved.state.ledger; discovery=saved.state.discovery;
    controllerSeconds=saved.state.controllerSeconds;
    if saved.state.completed, out=saved.state.out; return; end
end
cursor=0; clock=tic; cacheData=cell(budget,1);
if strcmp(method,'de')
    backend=olg.fex_de(B,cfg.search,budget,rep,@visit);
elseif isempty(discovery)
    for j=height(L)+1:budget
        cursor=j-1;
        [~,candidate]=visit(B(j),0);
        if candidate, break; end
    end
end
controllerSeconds=controllerSeconds+toc(clock);
found=~isempty(discovery); reason="budget_exhausted";
firstEval=NaN; firstSeconds=NaN; bFound=NaN;
if found
    reason="candidate_found"; firstEval=height(L); bFound=discovery.theta(3);
    firstSeconds=L.FirstCandidateSearchSeconds(end);
end
elapsed=sum(L.EvaluationSeconds)+controllerSeconds;
summary=table(string(method),rep,found,reason,height(L),firstEval,firstSeconds,bFound, ...
    strcmp(method,'de') && found && height(L)<=cfg.search.population, ...
    sum(L.OrbitSteps),sum(L.TangentSteps),sum(L.EvaluationSeconds),elapsed, ...
    sum(L.FTLECalls),sum(L.B<=1/cfg.model.beta),sum(L.Trajectories), ...
    sum(~L.CacheHit),sum(L.CacheHit),sum(L.IntegrationWorkerSeconds), ...
    sum(L.ZeroOneWorkerSeconds),sum(L.ConfirmationWorkerSeconds),sum(L.DiagnosticsWorkerSeconds), ...
    'VariableNames',{'Method','Repetition','CandidateFound','StopReason','Evaluations', ...
    'FirstCandidateEvaluation','FirstCandidateSeconds','CandidateB','FoundDuringInitialization', ...
    'OrbitSteps','TangentSteps','EvaluationSeconds','ElapsedSeconds','FTLECalls','LowRegionEvaluations', ...
    'Trajectories','UniqueEvaluations','CacheHits','IntegrationWorkerSeconds','ZeroOneWorkerSeconds', ...
    'ConfirmationWorkerSeconds','DiagnosticsWorkerSeconds'});
summary.FirstCandidateSearchSeconds=firstSeconds;
summary.PhaseScan=string(cfg.search.phaseScan);
out=struct('method',method,'repetition',rep,'ledger',L,'discovery',discovery, ...
    'summary',summary,'completed',true,'backend',backend);
if cfg.output.enabled
    writetable(L,fullfile(cfg.output.directory,sprintf('%s_rep%03d.csv',method,rep)));
    olg.fast.olg_atomic_save(fullfile(cfg.output.directory,sprintf('%s_rep%03d_completed.mat',method,rep)),struct('out',out));
    persist(true,out);
end

    function [value,candidate]=visit(b,generation)
        cursor=cursor+1; i=cursor;
        if i<=height(L)
            assert(b==L.B(i) && generation==L.Generation(i), ...
                'OLG:ReplayMismatch','Native DE replay differs from the saved proposal sequence.');
            value=L.Score(i); candidate=logical(L.Candidate(i)); return;
        end
        controllerSeconds=controllerSeconds+toc(clock);
        % Commit the controller prefix before a potentially hours-long Q scan.
        if cfg.output.enabled, persist(false,[]); end
        prior=[];
        if cfg.search.cacheParameters && ~isempty(L)
            prior=find(L.B==b & ~L.CacheHit & ~L.Candidate & L.CompleteStateGrid,1);
        end
        cacheHit=~isempty(prior); checkpoint='';
        if ~isempty(folder), checkpoint=fullfile(folder,sprintf('evaluation_%06d.mat',i)); end
        if cacheHit
            cacheClock=tic;
            if cfg.output.enabled
                assert(isfile(fullfile(folder,sprintf('evaluation_%06d.mat',prior))), ...
                    'OLG:MissingCache','A completed negative checkpoint is missing.');
                e=olg.evaluate(b,U,cfg,fullfile(folder,sprintf('evaluation_%06d.mat',prior)));
            else
                e=cacheData{prior};
            end
            assert(~e.candidate && e.exhaustedPhasePool,'OLG:IncompleteCache','Only complete negative results may be cached.');
            for name={'steps','trajectories','stage1Steps','stage2Steps','zeroOneCalls','rosensteinCalls', ...
                    'integrationSeconds','zeroOneSeconds','confirmationSeconds','diagnosticsSeconds','diagnosticSteps','tangentSteps','saliCalls','condnCalls'}
                e.(name{1})=0;
            end
            e.seconds=toc(cacheClock);
        else
            evalCfg=cfg; evalCfg.preparedFast.searchPrefixSeconds=sum(L_value('EvaluationSeconds'))+controllerSeconds;
            e=olg.evaluate(b,U,evalCfg,checkpoint);
            assert(e.candidate || e.exhaustedPhasePool,'OLG:IncompleteEvaluation','A negative must exhaust Q.');
            if ~cfg.output.enabled, cacheData{i}=e; end
        end
        clock=tic; value=e.score; candidate=e.candidate;
        k=NaN; lle=NaN; fitR2=NaN; sali=NaN; condn=NaN; status="not_candidate";
        c0=NaN; l0=NaN; witnessIndex=NaN;
        if ~isempty(fieldnames(e.paths))
            p=e.paths; k=p.K; lle=p.rosenstein; fitR2=p.rosensteinR2;
            c0=p.initial(1); l0=p.initial(2); witnessIndex=e.phaseIndices;
            if candidate && ~isempty(fieldnames(p.diagnostics))
                sali=p.diagnostics.sali; condn=p.diagnostics.condnDelta; status=string(p.diagnostics.status);
            end
        end
        spent=sum(L_value('EvaluationSeconds'))+e.seconds+controllerSeconds;
        firstSearch=NaN; firstPosition=NaN; firstIndex=NaN;
        if candidate
            firstSearch=e.firstCandidate.searchSeconds;
            firstPosition=e.firstCandidate.phasePosition; firstIndex=e.firstCandidate.phaseIndex;
        end
        row=table(i,generation,b,e.score,candidate,e.candidateCount,e.nonzeroSurvivors, ...
            e.trajectories,e.steps,e.tangentSteps,e.zeroOneCalls,e.saliCalls,e.condnCalls,e.rosensteinCalls,e.seconds,spent, ...
            c0,l0,k,sali,condn,lle,fitR2,U.count,e.exhaustedPhasePool,witnessIndex,cacheHit, ...
            e.integrationSeconds,e.zeroOneSeconds,e.confirmationSeconds,e.diagnosticsSeconds, ...
            e.diagnosticSteps,e.screeningDeferred,status,firstSearch,firstPosition,firstIndex,string(e.basinFolder), ...
            'VariableNames',{'Evaluation','Generation','B','Score','Candidate','CandidateCount','CheapSurvivors', ...
            'Trajectories','OrbitSteps','TangentSteps','ZeroOneCalls','SALICalls','ConDNCalls','FTLECalls', ...
            'EvaluationSeconds','ElapsedSeconds','WitnessC','WitnessL','K01','SALI','ConDN','RosensteinLLE', ...
            'RosensteinR2','PlannedStates','CompleteStateGrid','WitnessPhaseIndex','CacheHit', ...
            'IntegrationWorkerSeconds','ZeroOneWorkerSeconds','ConfirmationWorkerSeconds', ...
            'DiagnosticsWorkerSeconds','DiagnosticSteps','ScreeningDeferred','DiagnosticsStatus', ...
            'FirstCandidateSearchSeconds','FirstCandidatePhasePosition','FirstCandidatePhaseIndex','BasinFolder'});
        if isempty(L), L=row; else, L=[L;row]; end
        if candidate, discovery=e; end
        controllerSeconds=controllerSeconds+toc(clock); clock=tic;
        if cfg.output.enabled, persist(false,[]); end
        if i==1 || mod(i,cfg.search.progressEvery)==0 || candidate
            fprintf('%s | rep %d | %d/%d requests | b=%.8g | candidate=%d | cache=%d | %.2f committed s\n', ...
                method,rep,i,budget,b,candidate,cacheHit,spent);
        end
    end
    function values=L_value(name)
        if isempty(L), values=[]; else, values=L.(name); end
    end
    function persist(completed,result)
        state=struct('signature',signature,'ledger',L,'discovery',discovery, ...
            'controllerSeconds',controllerSeconds,'completed',completed,'out',result);
        olg.fast.olg_atomic_save(file,struct('state',state));
    end
end
