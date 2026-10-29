function d=olg_candidate_diagnostics(theta,x0,signal,cfg)
% Diagnostics only. No SALI/ConDN threshold alters the discovery criterion.
timer=tic; H=cfg.burn+cfg.sample;
d=struct('sali',NaN,'condnDelta',NaN,'condnTraces',[], ...
    'steps',0,'seconds',0,'status','disabled','orbitMatches',false,'tangentSteps',0,'saliCalls',0,'condnCalls',0);
if ~cfg.diagnostics, return; end
try
    [c,~,ids,steps,~,l]=olg.fast.olg_integrate(theta,x0,cfg,true); d.steps=steps;
    assert(isscalar(ids),'OLG:Diagnostics','Diagnostic orbit exited Pi.');
    % Replay uses the same backend and first-step table as the original scan.
    d.orbitMatches=isequal(c,signal(1:H));
    assert(d.orbitMatches,'OLG:Diagnostics','Replayed orbit differs; diagnostics withheld.');
    orbit=[x0; c l]; d.saliCalls=1; [d.sali,d.tangentSteps]=olg.fast.olg_sali_fast(orbit,theta,cfg.beta);
    d.condnCalls=1; [delta,d.condnTraces]=olg.fast.olg_condn_fast(signal(1:H),cfg.condn);
    d.condnDelta=delta(end); d.status='ok';
catch err
    d.status=[err.identifier ': ' err.message];
end
d.seconds=toc(timer);
end
