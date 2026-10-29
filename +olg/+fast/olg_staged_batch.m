function out=olg_staged_batch(theta,U,ids,cfg)
full=strcmp(cfg.phaseScan,'full'); timer=tic;
if full
    [history,last,alive,steps,origins,~,detail]=olg.fast.olg_integrate(theta,U,cfg);
else
    [history,last,alive,steps,origins]=olg.fast.olg_integrate(theta,U,cfg); detail=[];
end
out=struct('trajectories',size(U,1),'stage1Steps',steps,'stage2Steps',0, ...
    'zeroOneCalls',0,'rosensteinCalls',0,'survivors',origins+numel(alive), ...
    'nonzeroSurvivors',numel(alive),'candidate',false,'candidateCount',0,'path',struct(), ...
    'phaseIndex',NaN,'score',-1,'screeningDeferred',0,'firstCandidate',struct(), ...
    'integrationSeconds',toc(timer),'zeroOneSeconds',0,'confirmationSeconds',0, ...
    'diagnosticsSeconds',0,'diagnosticSteps',0,'records',struct(),'registry',struct([]),'tangentSteps',0,'saliCalls',0,'condnCalls',0);
if full
    n=size(U,1);
    out.records=struct('id',uint32(ids),'status',uint8(detail(:,4)), ...
        'attractor',zeros(n,1,'uint32'),'period',zeros(n,1,'uint16'), ...
        'steps',uint32(detail(:,3)),'last',detail(:,1:2), ...
        'K',nan(n,1,'single'),'LLE',nan(n,1,'single'), ...
        'SALI',nan(n,1,'single'),'ConDN',nan(n,1,'single'));
    if any(detail(:,4)==1)
        [out.registry,id]=olg.fast.olg_register_cycle(out.registry,[0 0],cfg.basinClusterTol);
        out.records.attractor(detail(:,4)==1)=uint32(id); out.records.period(detail(:,4)==1)=1;
    end
end
for j=1:numel(alive)
    r=olg.fast.olg_staged_finish(theta,U(alive(j),:),history(:,j),last(j,:),cfg);
    out.stage2Steps=out.stage2Steps+r.stage2Steps;
    for field={'zeroOneSeconds','confirmationSeconds','diagnosticsSeconds','diagnosticSteps','tangentSteps','saliCalls','condnCalls'}
        out.(field{1})=out.(field{1})+r.(field{1});
    end
    out.zeroOneCalls=out.zeroOneCalls+r.zeroOneCalls; out.rosensteinCalls=out.rosensteinCalls+r.rosensteinCalls;
    if ~r.survived
        out.survivors=out.survivors-1; out.nonzeroSurvivors=out.nonzeroSurvivors-1;
    end
    if r.survived && (isempty(fieldnames(out.path)) || r.score>out.score)
        out.path=r; out.score=r.score; out.phaseIndex=ids(alive(j));
    end
    if r.candidate
        out.candidate=true; out.candidateCount=out.candidateCount+1;
        if isempty(fieldnames(out.firstCandidate))
            out.firstCandidate=struct('path',r,'phaseIndex',ids(alive(j)),'localPosition',alive(j));
        end
    end
    if full
        k=alive(j); code=8;
        if r.candidate
            code=9;
        elseif ~r.survived
            code=11;
        elseif strcmp(r.status,'indicator_failure')
            code=12;
        else
            cycle=olg.fast.olg_regular_cycle(history(:,j),theta(2),cfg);
            if ~isempty(cycle)
                [out.registry,id]=olg.fast.olg_register_cycle(out.registry,cycle,cfg.basinClusterTol);
                out.records.attractor(k)=uint32(id); out.records.period(k)=size(cycle,1);
                code=6+(size(cycle,1)>1);
            elseif r.rosensteinCalls>0
                code=10;
            end
        end
        out.records.status(k)=uint8(code); out.records.steps(k)=uint32(r.steps);
        out.records.last(k,:)=r.last; out.records.K(k)=single(r.K); out.records.LLE(k)=single(r.rosenstein);
        if r.candidate && ~isempty(fieldnames(r.diagnostics))
            out.records.SALI(k)=single(r.diagnostics.sali); out.records.ConDN(k)=single(r.diagnostics.condnDelta);
        end
    elseif r.candidate
        out.screeningDeferred=numel(alive)-j; break;
    end
end
if ~full && out.candidate
    out.path=out.firstCandidate.path; out.phaseIndex=out.firstCandidate.phaseIndex; out.score=out.path.score;
end
end
