function verify_release
% Longer integration verification: timing profiles, parallel equivalence,
% paper positive control, and the full b scan on an explicitly coarse Q grid.
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root);
for profile={'demo','paper'}
    c=olg_config('compare_chaos_indicators',profile{1});
    c.output.visible=false;
    result=run_olg_experiment(c);
    assert(result.details{4}.samples==c.horizon.ftle);
    assert(result.summary.Value(4)>0.005);
end
c=olg_config('compare_DE_vs_full_scan','paper');
c.parallel.enabled=false;
r=olg.trajectory(1.54,[0.5 1],c);
assert(r.candidate && r.rosensteinDetails.samples==10000 && r.orbitSteps==10000);
fprintf('Paper positive control passed: K=%.9g, Rosenstein=%.9g, R2=%.9g.\n', ...
    r.values(1),r.values(4),r.rosensteinDetails.rSquared);
c=olg_config; c.search.stateGridSize=[3 3]; [~,U]=olg.grids(c);
c.parallel.enabled=false; serial=olg.evaluate(1.54,U,c);
c.parallel.enabled=true; olg.pool(c.parallel,U.count); parallel=olg.evaluate(1.54,U,c);
assert(isequaln(vertcat(serial.initialStates.values),vertcat(parallel.initialStates.values)));
assert(isequal([serial.initialStates.candidate],[parallel.initialStates.candidate]));
assert(serial.orbitSteps==parallel.orbitSteps);
fprintf('Serial/thread-pool numerical equivalence passed.\n');
c.filters={'zero_one','sali','condn'}; U=[0.5 1;0.49 1];
c.parallel.enabled=false; serial=olg.evaluate(1.54,U,c);
c.parallel.enabled=true; parallel=olg.evaluate(1.54,U,c);
assert(isequaln(vertcat(serial.initialStates.values),vertcat(parallel.initialStates.values)));
assert(isequal([serial.initialStates.candidate],[parallel.initialStates.candidate]));
fprintf('Optional SALI/ConDN gates are identical with serial and thread-pool evaluation.\n');
c=olg_config('compare_DE_vs_full_scan','demo'); c.output.visible=false;
% Explicit coarse integration check, NOT the default 273-million-state run.
c.search.stateGridSize=[14 22];
result=run_olg_experiment(c);
assert(all(result.summary.CandidateFound));
assert(numel(result.bValues)==6000);
fprintf('Coarse verification search completed; saved under %s\n',result.cfg.output.directory);
end
