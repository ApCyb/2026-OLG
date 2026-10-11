function result = timing_experiment(cfg)
% One common orbit; serial measurements, no parfor and no search.
t=tic;
[path,status,steps]=olg.orbit(cfg.timing.x0,cfg.horizon.ftle, ...
    cfg.model,cfg.timing.b,cfg.detector.maxState);
orbitSeconds=toc(t);
if ~strcmp(status,'survived')
    error('OLG:TimingOrbit','Common orbit stopped at iteration %d: %s.',steps,status);
end
short=path(cfg.horizon.transient+1:cfg.horizon.cheap+1,:);
methods=[cfg.timing.indicators,{'ftle'}]; n=numel(methods);
times=zeros(cfg.timing.repetitions,n); values=times; details=cell(1,n);
for warm=1:cfg.timing.warmupPasses
    for m=1:n
        if strcmp(methods{m},'ftle'), p=path; else, p=short; end
        olg.indicator(methods{m},p,cfg,cfg.timing.b);
    end
end
for rep=1:cfg.timing.repetitions
    % Rotate serial order to avoid always measuring a method first/last.
    order=circshift(1:n,[0 mod(rep-1,n)]);
    for m=order
        if strcmp(methods{m},'ftle'), p=path; else, p=short; end
        t=tic;
        [values(rep,m),details{m}]=olg.indicator(methods{m},p,cfg,cfg.timing.b);
        times(rep,m)=toc(t);
    end
end
% Combined row is the sum within each measured repetition, not another call.
times=[times,sum(times(:,1:n-1),2)]; values=[values,nan(size(values,1),1)];
names=[methods,{'cheap_total'}];
displayNames=names; displayNames{n}='rosenstein_lle';
starts=[repmat(cfg.horizon.transient,1,n-1),0,cfg.horizon.transient]';
ends=[repmat(cfg.horizon.cheap,1,n-1),cfg.horizon.ftle,cfg.horizon.cheap]';
summary=table(string(displayNames(:)),starts,ends,ends-starts,median(times,1)', ...
    min(times,[],1)',max(times,[],1)',values(1,:)', ...
    'VariableNames',{'Indicator','StartIteration','EndIteration','SamplesOrSteps', ...
    'MedianSeconds','MinSeconds','MaxSeconds','Value'});
fast=[1:n-1,n+1]; ratios=median(times(:,n))./median(times(:,fast),1);
comparison=table(string(names(fast))',ratios',ratios'>1, ...
    'VariableNames',{'Indicator','RosensteinOverIndicatorTime','IndicatorFaster'});
result=struct('mode',cfg.mode,'summary',summary,'comparison',comparison, ...
    'orbit',path,'orbitSteps',steps,'orbitGenerationSeconds',orbitSeconds, ...
    'methodNames',{names},'timesSeconds',times,'values',values,'details',{details});
if cfg.output.enabled
    writetable(comparison,fullfile(cfg.output.directory,'comparison.csv'));
    writetable(array2table(times,'VariableNames',names), ...
        fullfile(cfg.output.directory,'timing_repetitions.csv'));
end
end
