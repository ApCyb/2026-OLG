function r=olg_finish_reference(theta,x0,series,last,cfg)
% First H map updates are already computed. Extend, rather than restart.
H=cfg.burn+cfg.sample;
r=struct('initial',x0,'status','zero_one_rejected','survived',true, ...
    'steps',H,'stage1Steps',H,'stage2Steps',0,'zeroOneCalls',1,'rosensteinCalls',0, ...
    'K',NaN,'ftle',NaN,'rosenstein',NaN,'rosensteinR2',NaN, ...
    'rosensteinPoints',0,'confirmation',struct(),'candidate',false,'score',0, ...
    'last',last,'stage1Passed',false,'series',[]);
r.K=olg.fast.olg_zero_one_fft_reference(series(cfg.burn+1:H),cfg);
if ~isfinite(r.K), r.status='indicator_failure'; return; end
r.score=max(0,min(1,r.K));
if r.K<cfg.KThreshold, return; end
r.stage1Passed=true;
series(cfg.confirmHorizon,1)=0; c=last(1); l=last(2);
for t=H+1:cfg.confirmHorizon
    cn=l^theta(2)-c; ln=theta(3)*(cfg.beta*l-c^theta(1));
    r.steps=t; r.stage2Steps=t-H; r.last=[cn ln];
    if cn<0 || ln<0, r.status='confirmation_exit_pi'; r.survived=false; r.score=0; return; end
    if ~isfinite(cn) || ~isfinite(ln)
        r.status='confirmation_numerical_failure'; r.survived=false; r.score=0; return;
    end
    if cn>cfg.maxState || ln>cfg.maxState
        r.status='confirmation_safety_stop'; r.survived=false; r.score=0; return;
    end
    c=cn; l=ln; series(t)=c;
end
r.rosensteinCalls=1; opt=cfg.rosenstein; opt.maxPoints=cfg.confirmHorizon;
rr=olg.fast.olg_rosenstein_reference(series,opt);
r.rosenstein=rr.lle; r.ftle=rr.lle; r.rosensteinR2=rr.r2;
r.rosensteinPoints=numel(series); r.confirmation=rr;
r.candidate=rr.valid && rr.lle>=cfg.LEThreshold;
if r.candidate
    r.status='chaotic_candidate'; r.series=series;
    r.score=1+r.K*(1-exp(-rr.lle/cfg.LEScale));
else
    r.status='rosenstein_rejected';
end
end
