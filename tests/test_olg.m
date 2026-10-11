function tests=test_olg
tests=functiontests(localfunctions);
end

function testRequestedProfiles(t)
for mode={'compare_DE_vs_full_scan','compare_chaos_indicators'}
    a=olg_config(mode{1},'demo'); b=olg_config(mode{1},'paper');
    olg.validate(a); olg.validate(b);
    verifyEqual(t,[a.horizon.cheap a.horizon.ftle],[1000 2000]);
    verifyEqual(t,[b.horizon.cheap b.horizon.ftle],[5000 10000]);
    if strcmp(mode{1},'compare_DE_vs_full_scan')
        verifyEqual(t,[a.horizon.transient b.horizon.transient],[100 1000]);
    else
        verifyEqual(t,[a.horizon.transient b.horizon.transient],[0 0]);
    end
end
c=olg_config; [B,U]=olg.grids(c);
verifyEqual(t,numel(B),6000); verifyEqual(t,B(1),1.0001,'AbsTol',1e-14);
verifyEqual(t,B(end),1.6); verifyEqual(t,sum(B<=1/c.model.beta),101);
verifyEqual(t,U.shape,[13001 21001]); verifyEqual(t,U.count,273034001);
verifyEqual(t,olg.state_block(U,1,1),[0 0]);
verifyEqual(t,olg.state_block(U,U.count,U.count),[1.3 2.1]);
verifyEqual(t,olg.state_block(U,13001,13002),[1.3 0;0 1e-4]);
c.search.bRange=[1.2 1.3]; c.search.bStep=0.0003;
verifyError(t,@()olg.validate(c),'OLG:Grid');
end

function testOrbitExtensionAndExit(t)
c=olg_config; [a,status,steps]=olg.orbit([0.5 1],1000,c.model,1.54,1e8);
verifyEqual(t,status,'survived'); verifyEqual(t,steps,1000);
[b,~,more]=olg.orbit(a,2000,c.model,1.54,1e8);
[whole,~,total]=olg.orbit([0.5 1],2000,c.model,1.54,1e8);
verifyEqual(t,b,whole); verifyEqual(t,more+steps,total);
[same,~,more]=olg.orbit(a,1000,c.model,1.54,1e8);
verifyEqual(t,same,a); verifyEqual(t,more,0);
[p,status,steps]=olg.orbit([1.5 0],1000,c.model,1.54,1e8);
verifyEqual(t,status,'left_Pi'); verifyEqual(t,steps,1); verifySize(t,p,[1 2]);
end

function testGateAvoidsRosenstein(t)
c=olg_config; c.zeroOne.threshold=1;
r=olg.trajectory(1.54,[0.5 1],c);
verifyEqual(t,r.status,'rejected_zero_one');
verifyEqual(t,r.orbitSteps,1000); verifyEqual(t,r.indicatorCalls,[1 0 0 0]);
verifyEqual(t,r.tangentSteps,0); verifyFalse(t,r.candidate);
r=olg.trajectory(1.54,[0 0],c);
verifyEqual(t,r.status,'exact_origin'); verifyEqual(t,r.indicatorCalls,zeros(1,4));
end

function testKnownCandidateAndRosensteinWindow(t)
c=olg_config; r=olg.trajectory(1.54,[0.5 1],c);
verifyTrue(t,r.candidate); verifyEqual(t,r.orbitSteps,2000);
verifyEqual(t,r.indicatorCalls,[1 0 0 1]); verifyEqual(t,r.tangentSteps,0);
verifySize(t,r.path,[2001 2]); verifyEqual(t,r.rosensteinDetails.samples,2000);
verifyGreaterThan(t,r.values(4),0.005); verifyGreaterThan(t,r.rosensteinDetails.rSquared,0.9);
[K,~]=olg.zero_one(r.path(102:1001,1),c.zeroOne);
verifyEqual(t,r.values(1),K); % Exactly 900 retained observations: x_101,...,x_1000.
end

function testIndicatorRandomStateAndRegularControl(t)
c=olg_config; [path,~,~]=olg.orbit([0.5 1],1000,c.model,1.54,1e8);
before=rng;
[v,d]=olg.condn(path(2:end,1),c.condn);
after=rng; verifyEqual(t,after,before); verifyTrue(t,isfinite(v));
[v2,d2]=olg.condn(path(2:end,1),c.condn);
verifyEqual(t,v2,v); verifyEqual(t,d2.traces,d.traces);
[k,~]=olg.zero_one(sin((1:1000)'*0.31),c.zeroOne);
verifyLessThan(t,k,0.2);
[v,d]=olg.rosenstein(ones(2000,1),c.rosenstein);
verifyTrue(t,isnan(v)); verifyEqual(t,d.status,'constant_signal');
end

function testOptionalGatesAndEquilibrium(t)
c=olg_config; c.filters={'zero_one','sali','condn'};
r=olg.trajectory(1.54,[0.5 1],c);
verifyTrue(t,r.candidate); verifyEqual(t,r.indicatorCalls,[1 1 1 1]);
verifyEqual(t,r.tangentSteps,900);
b=1.2; L=((b*c.model.beta-1)*2^c.model.lambda/b) ...
    ^(1/(c.model.lambda*c.model.sigma-1)); C=L^c.model.sigma/2;
r=olg.trajectory(b,[C L],c);
verifyEqual(t,r.status,'regular_short'); verifyEqual(t,r.indicatorCalls,[0 0 0 0]);
end

function testSearchStopsAtDiscovery(t)
c=small_config;
c.search.bRange=[1.54 1.541]; c.search.bStep=0.0001; c.search.includeLowerEndpoint=true;
c.search.Q=[0.49 0.51;0.99 1.01]; c.search.maxEvaluations=10;
before=rng; r=run_olg_experiment(c); verifyEqual(t,rng,before);
verifyEqual(t,height(r.summary),2); verifyTrue(t,all(r.summary.CandidateFound));
verifyEqual(t,r.summary.Evaluations(2),1);
verifyEqual(t,r.runs(2).ledger.B(1),1.54,'AbsTol',1e-14);
verifyTrue(t,r.summary.FoundDuringInitialization(1));
for k=1:2
    verifyTrue(t,r.runs(k).ledger.Candidate(end)==1);
    verifyEqual(t,r.runs(k).summary.OrbitSteps,sum(r.runs(k).ledger.OrbitSteps));
end
end

function testCensoringAndDEGenerations(t)
c=small_config; c.search.bRange=[1 1.001]; c.search.bStep=0.0001;
c.search.Q=[0 1e-4;0 1e-4]; c.search.maxEvaluations=8;
r=run_olg_experiment(c);
verifyFalse(t,any(r.summary.CandidateFound)); verifyEqual(t,r.summary.Evaluations,[8;8]);
verifyTrue(t,all(isnan(r.summary.FirstCandidateEvaluation)));
verifyTrue(t,all(isnan(r.comparison.GridOverDEEvaluations)));
verifyGreaterThan(t,r.runs(1).ledger.Generation(end),0);
verifyEqual(t,r.runs(2).ledger.B,(1+(1:8)'*0.0001),'AbsTol',1e-14);
end

function testTimingSharesKernelsAndUsesFullHorizons(t)
c=olg_config('compare_chaos_indicators','demo');
c.timing.repetitions=1; c.timing.warmupPasses=0;
c.output.enabled=false; c.output.plots=false;
r=run_olg_experiment(c);
verifyEqual(t,r.summary.EndIteration,[1000;1000;1000;2000;1000]);
verifyEqual(t,r.summary.StartIteration,zeros(5,1));
verifyEqual(t,r.details{4}.samples,2000); verifyEqual(t,r.orbitSteps,2000);
verifyEqual(t,r.timesSeconds(1,5),sum(r.timesSeconds(1,1:3)));
verifyEqual(t,r.values(1,4),olg.rosenstein(r.orbit(2:end,1),c.rosenstein));
end

function c=small_config
c=olg_config; c.parallel.enabled=false; c.output.enabled=false; c.output.plots=false;
c.search.population=4; c.search.stateGridSize=[2 2];
end
