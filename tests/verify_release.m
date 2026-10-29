function verify_release
% Small real integration runs; NEVER launch the default dense Q search here.
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root);
assert(olg.has_native('olg_integrate_mex') && olg.has_native('olg_zero_one_native_mex') ...
    && olg.has_native('olg_nearest_mex'),'OLG:Build','Run build_olg_fast before verify_release.');
for profile={'demo','paper'}
    c=olg_config('compare_chaos_indicators',profile{1}); c.output.visible=false;
    c.output.directory=fullfile(root,'results','release_20261026',['timing_' profile{1}]);
    result=run_olg_experiment(c);
    assert(height(result.summary)==6 && result.summary.Value(end)>.005);
end
% Real comparison over a small full Q grid and narrowed b interval.
c=olg_config('compare_DE_vs_full_scan','demo'); c.output.visible=false;
c.search.Q=[.49 .51;.99 1.01]; c.search.stateGridSize=[3 3];
c.search.bRange=[1.53 1.55]; c.search.gridMode='full_scan'; c.search.repetitions=2;
c.search.stateChunkSize=2; c.search.stateBatchSize=4; c.search.firstHitBatchSize=2; c.parallel.workers=2;
c.rosenstein.neighborMethod='brute';
c.output.directory=fullfile(root,'results','release_20261026','measured_threads');
a=run_olg_experiment(c); assert(all(a.summary.CandidateFound));
again=run_olg_experiment(c); assert(isequaln(a.summary,again.summary));
% Candidate chunk equivalence for serial versus thread workers.
f=olg.fast_config(c); [~,g]=olg.grids(c); f.useParallel=false;
a=olg.fast.olg_staged_evaluate([3.01 1.03 1.54],g,f);
f.useParallel=true; b=olg.fast.olg_staged_evaluate([3.01 1.03 1.54],g,f);
assert(a.score==b.score && a.steps==b.steps && a.trajectories==b.trajectories);
% Same small experiment with compiled components and process workers.
c.runtime.integrator='native'; c.runtime.zeroOneBackend='native';
c.rosenstein.neighborMethod='native'; c.parallel.poolType='auto';
c.search.gridMode='estimate'; c.search.historicalCandidateB=1.54;
c.search.gridFirstProbeCount=2; c.search.gridProbesPerRegime=1;
c.search.gridRegimeBreaks=[1.535 1.54 1.545];
c.output.directory=fullfile(root,'results','release_20261026','estimated_processes');
r=run_olg_experiment(c); assert(all(r.summary.CandidateFound));
assert(strcmp(r.pool.poolType,'parallel.ProcessPool'));
f=olg.fast_config(c); f.useParallel=false;
a=olg.fast.olg_staged_evaluate([3.01 1.03 1.54],g,f);
f.useParallel=true; b=olg.fast.olg_staged_evaluate([3.01 1.03 1.54],g,f);
assert(a.score==b.score && a.steps==b.steps && a.trajectories==b.trajectories);
loaded=olg_show_results(c.output.directory); assert(isequaln(r.summary,loaded.summary));
% Single-b paper-horizon scans on all 308 coarse Q nodes.
q=olg_config('compare_DE_vs_full_scan','paper','first_hit');
q.search.stateGridSize=[14 22]; q.search.stateChunkSize=32; q.search.stateBatchSize=64;
q.search.firstHitBatchSize=16; q.runtime.integrator='native'; q.runtime.zeroOneBackend='native';
q.parallel.enabled=false; q.output.visible=false;
q.output.directory=fullfile(root,'results','release_20261026','q_first_hit');
a=olg_scan_b(1.54,q); assert(a.candidate && a.trajectories<308);
q.search.phaseScan='full'; q.output.directory=fullfile(root,'results','release_20261026','q_full_serial');
b=olg_scan_b(1.54,q); assert(b.trajectories==308 && b.screeningDeferred==0);
assert(b.firstCandidate.seconds<b.seconds && all(b.statusCounts>=0));
preview=olg_plot_phase_map(b.basinFolder,false); assert(preview.complete);
q.parallel.enabled=true; q.parallel.workers=2;
q.output.directory=fullfile(root,'results','release_20261026','q_full_processes');
d=olg_scan_b(1.54,q); assert(d.candidateCount==b.candidateCount && isequal(d.statusCounts,b.statusCounts));
olg_plot_phase_map(d.basinFolder,false);
fprintf('Timing, Q modes, maps, threads/processes and restart checks passed on explicit small grids.\n');
end
