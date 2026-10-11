function e = evaluate(b,U,cfg)
% Shared, bounded-memory traversal of ALL Q states for both search methods.
t=tic;
if isstruct(U), n=U.count; else, n=size(U,1); end
retain=n<=cfg.search.retainInitialStatesMax;
e=struct('b',b,'score',-Inf,'candidate',false,'candidateCount',0, ...
    'witnessIndex',NaN,'witness',[],'initialStates',[], ...
    'cheapSurvivors',0,'fullSurvivors',0,'trajectories',0, ...
    'orbitSteps',0,'tangentSteps',0,'indicatorCalls',zeros(1,4), ...
    'seconds',0,'plannedStates',n,'completeStateGrid',false, ...
    'retainedInitialStates',retain,'firstCandidateStateIndex',NaN, ...
    'firstCandidateBatchSeconds',NaN);
lastProgress=0;
for first=1:cfg.search.stateBatchSize:n
    last=min(n,first+cfg.search.stateBatchSize-1);
    X=olg.state_block(U,first,last); rows=cell(size(X,1),1);
    if cfg.parallel.enabled
        parfor k=1:size(X,1), rows{k}=olg.trajectory(b,X(k,:),cfg); end
    else
        for k=1:size(X,1), rows{k}=olg.trajectory(b,X(k,:),cfg); end
    end
    R=[rows{:}]; flags=[R.candidate]; [score,w]=max([R.score]);
    hit=find(flags,1); newCandidate=~e.candidate && ~isempty(hit);
    if newCandidate
        w=hit; e.witness=R(w); e.witnessIndex=first+w-1;
        e.firstCandidateStateIndex=e.witnessIndex;
        e.firstCandidateBatchSeconds=toc(t);
    elseif ~e.candidate && score>e.score
        e.witness=R(w); e.witnessIndex=first+w-1;
    end
    e.score=max(e.score,score); e.candidate=e.candidate || any(flags);
    e.candidateCount=e.candidateCount+sum(flags);
    e.cheapSurvivors=e.cheapSurvivors+sum([R.cheapSurvived]);
    e.fullSurvivors=e.fullSurvivors+sum([R.fullSurvived]);
    e.orbitSteps=e.orbitSteps+sum([R.orbitSteps]);
    e.tangentSteps=e.tangentSteps+sum([R.tangentSteps]);
    e.indicatorCalls=e.indicatorCalls+sum(vertcat(R.indicatorCalls),1);
    e.trajectories=last;
    if retain
        for k=1:numel(R), R(k).path=[]; end
        e.initialStates=[e.initialStates R];
    end
    elapsed=toc(t);
    if elapsed-lastProgress>=cfg.search.stateProgressSeconds ...
            || (newCandidate && n>cfg.search.stateBatchSize)
        fprintf('  Q | b=%.8g | %.0f/%.0f states | candidates=%d | %.1f s\n', ...
            b,last,n,e.candidateCount,elapsed);
        lastProgress=elapsed;
        if cfg.output.enabled
            partial=e; partial.seconds=elapsed;
            save(fullfile(cfg.output.directory,'current_parameter.mat'),'partial','-v7.3');
        end
    end
end
e.seconds=toc(t); e.completeStateGrid=e.trajectories==n;
end
