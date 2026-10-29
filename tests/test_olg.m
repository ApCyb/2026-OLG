function tests=test_olg
tests=functiontests(localfunctions);
end

function testProfilesAndFullGrid(t)
c=olg_config('compare_DE_vs_full_scan','paper'); olg.validate(c);
verifyEqual(t,[c.horizon.transient,c.horizon.cheap-c.horizon.transient,c.horizon.ftle],[1000 4000 10000]);
[B,U]=olg.grids(c); verifyEqual(t,numel(B),6001); verifyEqual(t,B(1),1); verifyEqual(t,B(end),1.6);
verifyEqual(t,U.count,273034001); verifyEqual(t,U.shape,[13001 21001]);
verifyEqual(t,sum(B<=1/c.model.beta),102); verifyEqual(t,c.search.repetitions,5);
verifyEqual(t,c.search.gridMode,'estimate');
c.search.stateGridSize=[14 22]; [~,small]=olg.grids(c);
points=olg.state_block(small,1,small.count);
verifyEqual(t,size(unique(points,'rows'),1),small.count);
verifyEqual(t,min(points),[0 0]); verifyEqual(t,max(points),[1.3 2.1],'AbsTol',1e-14);
b=olg_config('compare_chaos_indicators','paper'); olg.validate(b);
verifyEqual(t,b.horizon.transient,0); verifyEqual(t,b.timing.neighborMethod,'brute');
end

function testOrbitAndOptimizedKernels(t)
c=olg_config('compare_DE_vs_full_scan','paper'); c.parallel.enabled=false;
f=olg.fast_config(c); f.useParallel=false;
[orbit,status,steps]=olg.orbit([.5 1],10000,c.model,1.54,c.detector.maxState);
verifyEqual(t,status,'survived'); verifyEqual(t,steps,10000);
y=orbit(2:5001,1);
[k,~]=olg.fast.olg_zero_one_fft(y,c.zeroOne); [ref,~]=olg.zero_one(y,c.zeroOne);
verifyEqual(t,k,ref,'AbsTol',1e-8);
old=rng; [delta,traces]=olg.fast.olg_condn_fast(y,c.condn); verifyEqual(t,rng,old);
[reference,detail]=olg.condn(y,c.condn);
verifyEqual(t,delta(end),reference,'AbsTol',1e-8); verifyEqual(t,traces,detail.traces,'AbsTol',1e-8);
for N=[1 15 16 17 31 32]
    fast=olg.fast.olg_sali_fast(orbit(1:N+1,:),[3.01 1.03 1.54],.99);
    slow=olg.sali(orbit(1:N+1,:),c.model,1.54); verifyEqual(t,fast,slow,'AbsTol',1e-10);
end
r=olg.fast.olg_staged_batch([3.01 1.03 1.54],[.5 1],1,f);
verifyTrue(t,r.candidate); verifyEqual(t,r.path.rosensteinPoints,10000);
verifyTrue(t,r.path.diagnostics.orbitMatches); verifyEqual(t,r.diagnosticSteps,5000);
verifyEqual(t,r.path.diagnostics.status,'ok');
verifyEqual(t,r.tangentSteps,5000); verifyEqual(t,[r.saliCalls,r.condnCalls],[1 1]);
end

function testNativeEquivalentIndicatorsAndNeighbors(t)
assumeTrue(t,olg.has_native('olg_nearest_mex') && olg.has_native('olg_zero_one_native_mex'));
c=olg_config; old=rng; restore=onCleanup(@()rng(old)); rng(13);
for N=[4000 5000]
    signals={ones(N,1),sin((1:N)'/7),randn(N,1)};
    for j=1:3
        [a,ka]=olg.fast.olg_zero_one_fft(signals{j},c.zeroOne);
        [b,kb]=olg.fast.olg_zero_one_native(signals{j},c.zeroOne);
        verifyEqual(t,a,b,'AbsTol',1e-8); verifyEqual(t,ka,kb,'AbsTol',1e-8);
    end
end
for Y={randn(100,3),randi(4,100,3),zeros(80,3)}
    X=Y{1}; n=size(X,1); expected=zeros(n,1);
    for i=1:n
        d=sum((X-X(i,:)).^2,2); d(abs((1:n)'-i)<=7 | d<=eps)=Inf;
        [v,index]=min(d); if isfinite(v), expected(i)=index; end
    end
    verifyEqual(t,olg.fast.olg_nearest_mex(X,7),expected);
end
end

function testNativeIntegrationAndBackendPool(t)
assumeTrue(t,olg.has_native('olg_integrate_mex'));
c=small_config; f=olg.fast_config(c); f.burn=0; f.sample=20;
U=[.5 1;.1 .2;1.3 0];
[a,la,ia,sa]=olg.fast.olg_integrate([3.01 1.03 1.54],U,f);
f.integrator='native'; [b,lb,ib,sb]=olg.fast.olg_integrate([3.01 1.03 1.54],U,f);
verifyEqual(t,ia,ib); verifyEqual(t,sa,sb);
verifyEqual(t,a,b,'AbsTol',1e-8); verifyEqual(t,la,lb,'AbsTol',1e-8);
c.runtime.integrator='native'; c.parallel.poolType='Threads';
verifyError(t,@()olg.fast_config(c),'OLG:NativePool');
end

function testSearchCacheResumeAndCensoring(t)
c=small_config; c.output.enabled=true; c.output.directory=tempname;
c.search.Q=[0 .0001;0 .0001]; c.search.stateGridSize=[];
c.search.bRange=[1 1.002]; c.search.maxEvaluations=21;
a=run_olg_experiment(c);
verifyFalse(t,any(a.summary.CandidateFound)); verifyEqual(t,a.summary.Evaluations,[21;21]);
verifyGreaterThan(t,a.summary.CacheHits(1),0);
verifyTrue(t,all(a.runs(1).ledger.Trajectories(a.runs(1).ledger.CacheHit)==0));
b=run_olg_experiment(c); verifyEqual(t,a.summary,b.summary);
verifyEqual(t,a.runs(1).ledger,b.runs(1).ledger);
% Resume a saved mid-generation ledger by replaying native DE objective values.
p=fullfile(c.output.directory,'de_rep001','optimizer.mat'); saved=load(p,'state');
saved.state.ledger=saved.state.ledger(1:7,:); saved.state.completed=false; saved.state.out=[];
saved.state.controllerSeconds=0;
olg.fast.olg_atomic_save(p,saved);
d=run_olg_experiment(c);
verifyEqual(t,d.runs(1).ledger.B,a.runs(1).ledger.B);
verifyEqual(t,d.runs(1).ledger.Score,a.runs(1).ledger.Score);
verifyEqual(t,d.summary.OrbitSteps,a.summary.OrbitSteps);
uncached=c; uncached.search.cacheParameters=false; uncached.output.directory=tempname;
u=run_olg_experiment(uncached);
verifyEqual(t,u.runs(1).ledger.B,a.runs(1).ledger.B);
verifyEqual(t,u.runs(1).ledger.Score,a.runs(1).ledger.Score);
verifyGreaterThan(t,u.summary.OrbitSteps(1),a.summary.OrbitSteps(1));
changed=c; changed.zeroOne.threshold=.81;
verifyError(t,@()run_olg_experiment(changed),'OLG:ResumeMismatch');
end

function testCandidateStopAndRealGridComparison(t)
c=small_config; c.search.bRange=[1.54 1.541]; c.search.stateGridSize=[3 3];
c.search.Q=[.49 .51;.99 1.01]; c.search.maxEvaluations=10;
a=run_olg_experiment(c);
verifyTrue(t,all(a.summary.CandidateFound)); verifyEqual(t,a.summary.Evaluations,[1;1]);
verifyTrue(t,a.summary.FoundDuringInitialization(1));
verifyTrue(t,all(isfinite(a.comparison.GridOverDEWallTime)));
end

function testEstimatedGridIsLabeled(t)
c=small_config; c.search.gridMode='estimate'; c.search.bRange=[1.54 1.541];
c.search.historicalCandidateB=1.5405; c.search.gridFirstProbeCount=2;
c.search.gridProbesPerRegime=1; c.search.gridRegimeBreaks=[1.5402 1.5404];
c.search.Q=[.49 .51;.99 1.01]; c.search.stateGridSize=[2 2];
a=run_olg_experiment(c);
verifyEqual(t,height(a.summary),1); verifyEqual(t,a.summary.Method,"de");
verifyEqual(t,a.comparisonKind,'measured_DE_estimated_grid_cost');
verifyEqual(t,height(a.gridEstimates),2); verifyTrue(t,all(a.gridEstimates.assumedEvaluations==1));
end

function testTimingHasOnlyRosensteinAtBothHorizons(t)
c=olg_config('compare_chaos_indicators','demo'); c.output.enabled=false; c.output.plots=false;
c.timing.repetitions=1; c.timing.warmupPasses=0;
a=run_olg_experiment(c);
verifyEqual(t,a.summary.EndIteration,[1000;1000;1000;1000;1000;2000]);
verifyEqual(t,a.methodNames(end-1:end),{'rosenstein_short','rosenstein_long'});
verifyFalse(t,any(contains(lower(a.summary.Indicator),'jacobian')));
verifyEqual(t,a.timesSeconds(1,4),sum(a.timesSeconds(1,1:3)));
verifyEqual(t,a.details{4}.samples,1000); verifyEqual(t,a.details{5}.samples,2000);
end

function testResumePendingQAndCensoredEstimates(t)
c=small_config; c.output.enabled=true; c.output.directory=tempname;
c.search.Q=[0 .0001;0 .0001]; c.search.stateGridSize=[];
c.search.bRange=[1 1.002]; c.search.maxEvaluations=1;
f=olg.fast_config(c); [~,g]=olg.grids(c); f.evalCheckpoint=[tempname '.mat'];
th=[3.01 1.03 1];
complete=olg.fast.olg_staged_evaluate(th,g,f);
saved=load(f.evalCheckpoint); [U,ids]=olg.fast.olg_phase_points(g,1:2);
first=olg.fast.olg_staged_batch(th,U,ids,f);
for name={'trajectories','stage1Steps','stage2Steps','zeroOneCalls','rosensteinCalls', ...
        'survivors','nonzeroSurvivors','screeningDeferred','integrationSeconds','zeroOneSeconds', ...
        'confirmationSeconds','diagnosticsSeconds','diagnosticSteps','tangentSteps','saliCalls','condnCalls'}
    saved.s.(name{1})=first.(name{1});
end
saved.s.nextPosition=3; saved.s.seconds=.25;
saved.s.path=first.path; saved.s.score=first.score; saved.s.phaseIndex=first.phaseIndex;
saved.s.candidate=false;
olg.fast.olg_atomic_save(f.evalCheckpoint,saved);
resumed=olg.fast.olg_staged_evaluate(th,g,f);
verifyEqual(t,resumed.trajectories,complete.trajectories);
verifyEqual(t,resumed.steps,complete.steps); verifyGreaterThanOrEqual(t,resumed.seconds,.25);
c.search.gridMode='estimate'; c.search.historicalCandidateB=1.001;
c.search.gridFirstProbeCount=1; c.search.gridProbesPerRegime=1;
c.search.gridRegimeBreaks=[1.0004 1.0007];
a=run_olg_experiment(c);
verifyFalse(t,any(a.summary.CandidateFound));
verifyTrue(t,all(isnan(a.gridEstimates.timeRatioToMeanDE)));
end

function c=small_config
c=olg_config; c.parallel.enabled=false; c.output.enabled=false; c.output.plots=false;
c.search.gridMode='full_scan'; c.search.repetitions=1; c.search.population=4;
c.search.stateOrder='lex'; c.search.stateChunkSize=2; c.search.stateBatchSize=4;
c.search.diagnostics=false; c.rosenstein.neighborMethod='brute';
end
