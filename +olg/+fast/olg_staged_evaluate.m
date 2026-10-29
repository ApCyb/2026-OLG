function e=olg_staged_evaluate(theta,grid,cfg)
% Complete virtual-grid traversal, bounded memory, periodic restart state.
full=strcmp(cfg.phaseScan,'full');
timer=tic; signature=struct('theta',theta,'protocol',olg.fast.olg_protocol(cfg,grid));
s=struct('nextPosition',1,'trajectories',0,'stage1Steps',0,'stage2Steps',0, ...
    'zeroOneCalls',0,'rosensteinCalls',0,'survivors',0,'nonzeroSurvivors',0, ...
    'score',-1,'path',struct(),'phaseIndex',NaN,'candidate',false, ...
    'screeningDeferred',0,'seconds',0,'integrationSeconds',0,'zeroOneSeconds',0, ...
    'confirmationSeconds',0,'diagnosticsSeconds',0,'diagnosticSteps',0, ...
    'batchNumber',0,'candidateCount',0,'firstCandidate',struct(), ...
    'registry',struct([]),'statusCounts',zeros(13,1),'scanId','','tangentSteps',0,'saliCalls',0,'condnCalls',0);
file=''; if isfield(cfg,'evalCheckpoint'), file=cfg.evalCheckpoint; end
if ~isempty(file) && cfg.resume && isfile(file)
    saved=load(file,'signature','s');
    assert(isequaln(saved.signature,signature),'OLG:ResumeMismatch', ...
        'Checkpoint protocol differs. Use a new outputDir or restore its configuration.');
    s=saved.s;
end
basinFolder='';
if full
    assert(~isempty(file),'OLG:FullOutput','Full scan requires evalCheckpoint for per-node records.');
    [parent,name]=fileparts(file); basinFolder=fullfile(parent,[name '_basin']);
    if isempty(s.scanId)
        s.scanId=char(java.util.UUID.randomUUID);
        olg.fast.olg_atomic_save(fullfile(basinFolder,'metadata.mat'),struct('grid',grid, ...
            'theta',theta,'signature',signature,'scanId',s.scanId, ...
            'checkpoint',file,'labels',{olg.fast.olg_phase_legend()}));
    end
end
alreadyFinished=(~full && s.candidate) || s.nextPosition>grid.maxPoints;
priorSeconds=s.seconds; saveClock=tic; progressClock=tic;

if cfg.useParallel && ~alreadyFinished
    % Transfer lookup tables/configuration once per parameter, not once per
    % each of the thousands of batches in a full Q traversal.
    workerContext=parallel.pool.Constant(cfg);
    releaseContext=onCleanup(@()delete(workerContext));
end
while s.nextPosition<=grid.maxPoints && (full || ~s.candidate)
    start=s.nextPosition;
    batchSize=cfg.phaseBatchSize;
    if ~full
        batchSize=min(batchSize,cfg.firstHitBatchSize*2^min(s.batchNumber,30));
    end
    % Start with short tasks for responsive discovery, then restore throughput.
    taskCount=max(1,ceil(cfg.phaseBatchSize/cfg.phaseChunkSize));
    chunkSize=min(cfg.phaseChunkSize,max(1,ceil(batchSize/taskCount)));
    stop=min(start+batchSize-1,grid.maxPoints);
    starts=(start:chunkSize:stop)'; chunks=cell(numel(starts),1);
    if cfg.useParallel
        parfor j=1:numel(starts)
            [U,ids]=olg.fast.olg_phase_points(grid,starts(j):min(starts(j)+chunkSize-1,stop));
            chunks{j}=olg.fast.olg_staged_batch(theta,U,ids,workerContext.Value);
        end
    else
        for j=1:numel(starts)
            [U,ids]=olg.fast.olg_phase_points(grid,starts(j):min(starts(j)+chunkSize-1,stop));
            chunks{j}=olg.fast.olg_staged_batch(theta,U,ids,cfg);
        end
    end
    for j=1:numel(chunks)
        b=chunks{j};
        for field={'trajectories','stage1Steps','stage2Steps','zeroOneCalls', ...
                'rosensteinCalls','candidateCount','survivors','nonzeroSurvivors','screeningDeferred', ...
                'integrationSeconds','zeroOneSeconds','confirmationSeconds','diagnosticsSeconds','diagnosticSteps','tangentSteps','saliCalls','condnCalls'}
            s.(field{1})=s.(field{1})+b.(field{1});
        end
        if ~isempty(fieldnames(b.path)) && (isempty(fieldnames(s.path)) || b.score>s.score)
            s.path=b.path; s.score=b.score; s.phaseIndex=b.phaseIndex;
        end
        if isempty(fieldnames(s.firstCandidate)) && b.candidate
            s.firstCandidate=b.firstCandidate;
            s.firstCandidate.phasePosition=starts(j)+b.firstCandidate.localPosition-1;
            % Observable completion of the parallel batch, not a worker CPU time.
            s.firstCandidate.seconds=priorSeconds+toc(timer);
            prefix=0; if isfield(cfg,'searchPrefixSeconds'), prefix=cfg.searchPrefixSeconds; end
            s.firstCandidate.searchSeconds=prefix+s.firstCandidate.seconds;
        end
        s.candidate=s.candidate || b.candidate;
    end
    if full
        s=olg.fast.olg_commit_phase_batch(basinFolder,chunks,s,start,stop,cfg);
    elseif s.candidate
        s.path=s.firstCandidate.path; s.phaseIndex=s.firstCandidate.phaseIndex;
        s.score=s.path.score;
    end
    s.nextPosition=stop+1; s.batchNumber=s.batchNumber+1; s.seconds=priorSeconds+toc(timer);
    if ~isempty(file) && (full || toc(saveClock)>=cfg.phaseCheckpointSeconds || s.candidate || stop==grid.maxPoints)
        olg.fast.olg_atomic_save(file,struct('signature',signature,'s',s)); saveClock=tic;
    end
    if cfg.phaseProgressSeconds>0 && (toc(progressClock)>=cfg.phaseProgressSeconds || s.candidate)
        fprintf('    b_L=%.7g | Q: %d/%d (%.4f%%) | 0-1: %d | Rosenstein: %d | %.1f s\n', ...
            theta(3),s.trajectories,grid.maxPoints,100*s.trajectories/grid.maxPoints, ...
            s.zeroOneCalls,s.rosensteinCalls,s.seconds); progressClock=tic;
    end
    if ~full && s.candidate, break; end
end
if ~alreadyFinished
    s.seconds=priorSeconds+toc(timer);
    if ~isempty(file), olg.fast.olg_atomic_save(file,struct('signature',signature,'s',s)); end
end
paths=s.path; witness=NaN; states=zeros(0,2); ids=[];
if ~isempty(fieldnames(paths)), witness=1; states=paths.initial; ids=s.phaseIndex; end
e=struct('theta',theta,'score',s.score,'objective',-s.score,'paths',paths, ...
    'candidate',s.candidate,'candidateCount',s.candidateCount,'witness',witness, ...
    'steps',s.stage1Steps+s.stage2Steps+s.diagnosticSteps,'trajectories',s.trajectories, ...
    'nonzeroSurvivors',s.nonzeroSurvivors,'survivorFraction',s.survivors/max(1,s.trajectories), ...
    'seconds',s.seconds,'initialStates',states,'phaseIndices',ids, ...
    'stage1Steps',s.stage1Steps,'stage2Steps',s.stage2Steps, ...
    'zeroOneCalls',s.zeroOneCalls,'rosensteinCalls',s.rosensteinCalls, ...
    'screeningDeferred',s.screeningDeferred,'exhaustedPhasePool',s.nextPosition>grid.maxPoints, ...
    'integrationSeconds',s.integrationSeconds,'zeroOneSeconds',s.zeroOneSeconds, ...
    'confirmationSeconds',s.confirmationSeconds,'diagnosticsSeconds',s.diagnosticsSeconds, ...
    'diagnosticSteps',s.diagnosticSteps,'phaseScan',cfg.phaseScan, ...
    'firstCandidate',s.firstCandidate,'basinFolder',basinFolder, ...
    'statusCounts',s.statusCounts,'regularRegistry',s.registry, ...
    'tangentSteps',s.tangentSteps,'saliCalls',s.saliCalls,'condnCalls',s.condnCalls);
end
