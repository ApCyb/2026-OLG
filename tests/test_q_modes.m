function tests=test_q_modes
tests=functiontests(localfunctions);
end
function testShuffleCoverage(t)
c=olg_config; before=rng; [~,g]=olg.grids(c); verifyEqual(t,rng,before);
bad=c; bad.phaseScan='full'; verifyError(t,@()olg.validate(bad),'OLG:LegacyFields');
verifyEqual(t,g.order,'shuffle'); verifyEqual(t,g.count,273034001);
for N=[1 2 3 4 37 308 1025 10000]
    ids=olg.fast.olg_shuffle_ids(1:N,N,max(1,ceil(log2(N)/2)),g.keys);
    verifyEqual(t,sort(ids),(1:N)');
end
[U,a]=olg.fast.olg_phase_points(g,1:100000);
verifyEqual(t,numel(unique(a)),100000); verifyTrue(t,all(U>=0,'all'));
verifyTrue(t,all(U(:,1)<=1.3 & U(:,2)<=2.1));
[~,b]=olg.fast.olg_phase_points(g,1:100000); verifyEqual(t,a,b);
c.search.stateSeed=c.search.stateSeed+1; [~,other]=olg.grids(c);
[~,b]=olg.fast.olg_phase_points(other,1:100000); verifyNotEqual(t,a,b);
end
function testAdaptiveBatchesAndFirstOrderedWitness(t)
c=small_config('first_hit'); c.search.firstHitBatchSize=2;
c.search.Q=[.49 .51;.99 1.01]; c.search.stateStep=[.01 .01];
f=olg.fast_config(c); [~,g]=olg.grids(c); f.searchPrefixSeconds=13;
r=olg.fast.olg_staged_evaluate([3.01 1.03 1.54],g,f);
verifyTrue(t,r.candidate); verifyEqual(t,r.trajectories,2);
verifyEqual(t,r.firstCandidate.phasePosition,1);
verifyEqual(t,r.phaseIndices,r.firstCandidate.phaseIndex);
verifyEqual(t,r.paths.initial,r.firstCandidate.path.initial);
verifyEqual(t,r.firstCandidate.searchSeconds,13+r.firstCandidate.seconds);
end
function testFullRecordsMapAndResume(t)
c=small_config('full'); c.search.Q=[0 1.3;0 2.1]; c.search.stateGridSize=[14 22];
c.search.stateChunkSize=32; c.search.stateBatchSize=64;
r=olg_scan_b(1.54,c); verifyTrue(t,r.candidate); verifyTrue(t,r.exhaustedPhasePool);
verifyEqual(t,r.trajectories,308); verifyEqual(t,sum(r.statusCounts),308);
verifyEqual(t,r.screeningDeferred,0); verifyGreaterThan(t,r.candidateCount,1);
verifyLessThan(t,r.firstCandidate.seconds,r.seconds);
files=dir(fullfile(r.basinFolder,'batch_*.mat')); ids=[]; status=[]; attractor=[];
for j=1:numel(files)
    data=load(fullfile(files(j).folder,files(j).name));
    ids=[ids;double(data.records.id)]; status=[status;data.records.status]; %#ok<AGROW>
    attractor=[attractor;data.records.attractor]; %#ok<AGROW>
    verifyClass(t,data.records.K,'single'); verifyClass(t,data.records.steps,'uint32');
end
verifyEqual(t,sort(ids),(1:308)'); verifyEqual(t,sum(status==9),r.candidateCount);
verifyFalse(t,any(status==5)); verifyTrue(t,all(attractor(status==9)==0));
verifyTrue(t,all(attractor(ismember(status,[1 6 7]))>0));
p=olg_plot_phase_map(r.basinFolder,false,100); verifyTrue(t,p.complete); verifyEqual(t,nnz(p.status),308);
a=olg_scan_b(1.54,c); verifyEqual(t,a.seconds,r.seconds); verifyEqual(t,a.statusCounts,r.statusCounts);
% A mismatched orphan record must be ignored by the map reader.
orphan=fullfile(r.basinFolder,'batch_999999999999.mat');
copyfile(fullfile(files(1).folder,files(1).name),orphan);
p=olg_plot_phase_map(r.basinFolder,false,100); verifyEqual(t,p.committedNodes,308);
end
function testCycleLabelsAndNativeDetails(t)
c=small_config('full'); f=olg.fast_config(c);
r=olg.fast.olg_regular_cycle(repmat([.2;.4;.3],200,1),1.03,f);
r2=olg.fast.olg_regular_cycle(repmat([.4;.3;.2],200,1),1.03,f);
[reg,a]=olg.fast.olg_register_cycle(struct([]),r,f.basinClusterTol);
[~,b]=olg.fast.olg_register_cycle(reg,r2,f.basinClusterTol); verifyEqual(t,a,b);
f.burn=0; f.sample=20; U=[0 0;1.3 0;.5 1];
[~,~,~,~,~,~,d]=olg.fast.olg_integrate([3.01 1.03 1.54],U,f);
verifyEqual(t,d(1,4),1); verifyEqual(t,d(2,4),2);
if olg.has_native('olg_integrate_mex')
    f.integrator='native'; [~,~,~,~,~,~,n]=olg.fast.olg_integrate([3.01 1.03 1.54],U,f);
    verifyEqual(t,d(:,3:4),n(:,3:4)); verifyEqual(t,d(:,1:2),n(:,1:2),'AbsTol',1e-8);
end
end
function testFullDEFirstTimeAndCheckpointRejection(t)
c=small_config('full'); c.search.Q=[.49 .51;.99 1.01]; c.search.stateGridSize=[3 3];
c.search.bRange=[1.54 1.541]; c.search.gridMode='full_scan'; c.search.repetitions=1;
c.search.population=4; c.search.stateChunkSize=2; c.search.stateBatchSize=4;
a=run_olg_experiment(c); verifyTrue(t,all(a.summary.CandidateFound));
verifyTrue(t,all(a.summary.ElapsedSeconds>a.summary.FirstCandidateSeconds));
verifyTrue(t,all(a.runs(1).ledger.CompleteStateGrid));
b=run_olg_experiment(c); verifyEqual(t,a.summary,b.summary);
% Simulate an optimizer interruption after Q committed but before its callback did.
p=fullfile(c.output.directory,'de_rep001','optimizer.mat'); x=load(p);
x.state.ledger=x.state.ledger([],:); x.state.discovery=[]; x.state.completed=false; x.state.out=[];
olg.fast.olg_atomic_save(p,x);
r=run_olg_experiment(c);
verifyEqual(t,r.summary.FirstCandidateSeconds(1),a.summary.FirstCandidateSeconds(1));
verifyGreaterThanOrEqual(t,r.summary.ElapsedSeconds(1),r.summary.FirstCandidateSeconds(1));
c.search.stateOrder='lex'; verifyError(t,@()run_olg_experiment(c),'OLG:ResumeMismatch');
end
function testResumeFullAfterCandidateBeforeEnd(t)
c=small_config('full'); c.search.Q=[0 1.3;0 2.1]; c.search.stateGridSize=[14 22];
c.search.stateChunkSize=32; c.search.stateBatchSize=64;
f=olg.fast_config(c); [~,g]=olg.grids(c); f.evalCheckpoint=[tempname '.mat'];
% Build an actual first-batch state, then restore the original full signature.
limited=g; limited.maxPoints=64;
a=olg.fast.olg_staged_evaluate([3.01 1.03 1.54],limited,f);
verifyTrue(t,a.candidate); verifyEqual(t,a.trajectories,64);
x=load(f.evalCheckpoint); signature=struct('theta',[3.01 1.03 1.54], ...
    'protocol',olg.fast.olg_protocol(f,g));
x.signature=signature; olg.fast.olg_atomic_save(f.evalCheckpoint,x);
m=load(fullfile(a.basinFolder,'metadata.mat')); m.grid=g; m.signature=signature;
olg.fast.olg_atomic_save(fullfile(a.basinFolder,'metadata.mat'),m);
b=olg.fast.olg_staged_evaluate([3.01 1.03 1.54],g,f);
verifyTrue(t,b.exhaustedPhasePool); verifyEqual(t,b.trajectories,308);
verifyEqual(t,b.firstCandidate.seconds,a.firstCandidate.seconds);
verifyEqual(t,b.firstCandidate.searchSeconds,a.firstCandidate.searchSeconds);
p=olg_plot_phase_map(b.basinFolder,false,100); verifyTrue(t,p.complete);
verifyEqual(t,sum(p.statusCounts),308);
end

function c=small_config(mode)
c=olg_config('compare_DE_vs_full_scan','demo',mode);
c.parallel.enabled=false; c.output.plots=false; c.output.visible=false;
c.output.directory=tempname; c.search.diagnostics=false;
c.search.stateChunkSize=2; c.search.stateBatchSize=4; c.search.firstHitBatchSize=2;
c.rosenstein.neighborMethod='brute';
end
