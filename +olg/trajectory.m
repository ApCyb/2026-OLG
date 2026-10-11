function r = trajectory(b, x0, cfg)
% One state: cheap orbit -> regularity screen -> ordered gates -> long FTLE.
% No analytic b_crit exclusion is used. The full FTLE path reuses cheap steps.
r=struct('x0',x0,'candidate',false,'status','unclassified','period',NaN, ...
    'cheapSurvived',false,'fullSurvived',false,'score',-2, ...
    'orbitSteps',0,'tangentSteps',0,'indicatorCalls',zeros(1,4), ...
    'indicatorSeconds',zeros(1,4),'values',nan(1,4),'rosensteinDetails',struct,'path',[]);
if all(x0==0), r.status='exact_origin'; r.score=0; return; end
[path,status,steps]=olg.orbit(x0,cfg.horizon.cheap,cfg.model,b,cfg.detector.maxState);
r.orbitSteps=steps; r.status=status;
if ~strcmp(status,'survived'), r.score=-2+steps/cfg.horizon.ftle; return; end
r.cheapSurvived=true;
short=path(cfg.horizon.transient+1:end,:);
r.period=regular_period(short,cfg.detector);
if isfinite(r.period), r.status='regular_short'; r.score=0; return; end
names={'zero_one','sali','condn','ftle'}; quality=1;
for k=1:numel(cfg.filters)
    name=cfg.filters{k}; id=find(strcmp(names,name)); t=tic;
    r.values(id)=olg.indicator(name,short,cfg,b);
    r.indicatorSeconds(id)=toc(t); r.indicatorCalls(id)=1;
    if strcmp(name,'sali'), r.tangentSteps=r.tangentSteps+size(short,1)-1; end
    [pass,q]=gate(name,r.values(id),cfg);
    quality=min(quality,q); r.score=1+quality;
    if ~pass, r.status=['rejected_' name]; return; end
end
[path,status,steps]=olg.orbit(path,cfg.horizon.ftle,cfg.model,b,cfg.detector.maxState);
r.orbitSteps=r.orbitSteps+steps; r.status=status;
if ~strcmp(status,'survived'), r.score=-2+r.orbitSteps/cfg.horizon.ftle; return; end
r.fullSurvived=true;
r.period=regular_period(path(cfg.horizon.transient+1:end,:),cfg.detector);
if isfinite(r.period), r.status='regular_long'; r.score=0; return; end
t=tic; [r.values(4),r.rosensteinDetails]=olg.indicator('ftle',path,cfg,b);
r.indicatorSeconds(4)=toc(t); r.indicatorCalls(4)=1;
r.candidate=isfinite(r.values(4)) && r.values(4)>=cfg.detector.ftleThreshold ...
    && r.rosensteinDetails.rSquared>=cfg.rosenstein.minR2;
if r.candidate
    r.status='chaos_candidate'; r.score=3+0.5*tanh(r.values(4)); r.path=path;
elseif isfinite(r.values(4))
    r.status='rejected_ftle'; r.score=2+0.5*tanh(r.values(4));
else
    r.status='invalid_ftle'; r.score=-2;
end
end

function p = regular_period(path,c)
p=NaN; count=size(path,1); window=min(count-1,max(128,4*c.maxPeriod));
scale=max(1,max(abs(path(end-window:end,:)),[],'all'));
for k=1:min(c.maxPeriod,floor((count-1)/5))
    n=min(window,count-k);
    if max(abs(path(end-n+1:end,:)-path(end-n+1-k:end-k,:)),[],'all')<=c.regularTolerance*scale
        p=k; return;
    end
end
end

function [pass,q] = gate(name,v,c)
if ~isfinite(v), pass=false; q=0; return; end
switch name
    case 'zero_one'
        pass=v>=c.zeroOne.threshold;
        q=max(0,min(1,(v+1)/(c.zeroOne.threshold+1)));
    case 'sali'
        pass=v<=c.sali.threshold;
        q=max(0,min(1,-log10(max(v,realmin))/-log10(c.sali.threshold)));
    case 'condn'
        pass=v>c.condn.threshold;
        q=1/(1+exp(-(v-c.condn.threshold)));
end
end
