function result=timing_experiment(cfg)
% Optimized indicators and Rosenstein at BOTH lengths; no Jacobian FTLE.
t=tic;
[path,status,steps]=olg.orbit(cfg.timing.x0,cfg.horizon.ftle,cfg.model,cfg.timing.b,cfg.detector.maxState);
orbitSeconds=toc(t);
assert(strcmp(status,'survived'),'OLG:TimingOrbit','Common orbit left the domain before the required horizon.');
methods=[cfg.timing.indicators,{'rosenstein_short','rosenstein_long'}]; n=numel(methods);
times=zeros(cfg.timing.repetitions,n); values=times; details=cell(1,n);
for pass=1:cfg.timing.warmupPasses
    for k=1:n, calculate(methods{k}); end
end
for rep=1:cfg.timing.repetitions
    % Match the supplied October 24 timing script's fixed sequential order.
    for k=1:n
        t=tic; [values(rep,k),details{k}]=calculate(methods{k}); times(rep,k)=toc(t);
    end
end
cheapCount=numel(cfg.timing.indicators);
% Preserve supplied table order: cheap indicators, their total, R(N), R(H).
times=[times(:,1:cheapCount),sum(times(:,1:cheapCount),2),times(:,cheapCount+1:end)];
values=[values(:,1:cheapCount),nan(size(values,1),1),values(:,cheapCount+1:end)];
names=[cfg.timing.indicators,{'cheap_total','rosenstein_short','rosenstein_long'}];
ends=[repmat(cfg.horizon.cheap,1,cheapCount+2),cfg.horizon.ftle]';
summary=table(string(names(:)),zeros(numel(names),1),ends,ends,median(times,1)', ...
    min(times,[],1)',max(times,[],1)',values(1,:)', ...
    'VariableNames',{'Indicator','StartIteration','EndIteration','SamplesOrSteps', ...
    'MedianSeconds','MinSeconds','MaxSeconds','Value'});
indicator=strings(0,1); baseline=indicator; ratio=[];
for b=cheapCount+2:cheapCount+3
    for a=1:cheapCount+1
        indicator(end+1,1)=names{a}; baseline(end+1,1)=names{b}; %#ok<AGROW>
        ratio(end+1,1)=median(times(:,b))/median(times(:,a)); %#ok<AGROW>
    end
end
comparison=table(indicator,baseline,ratio,ratio>1, ...
    'VariableNames',{'Indicator','Baseline','BaselineOverIndicatorTime','IndicatorFaster'});
result=struct('mode',cfg.mode,'summary',summary,'comparison',comparison, ...
    'orbit',path,'orbitSteps',steps,'orbitGenerationSeconds',orbitSeconds, ...
    'methodNames',{names},'timesSeconds',times,'values',values,'details',{details});
if cfg.output.enabled
    writetable(comparison,fullfile(cfg.output.directory,'comparison.csv'));
    writetable(array2table(times,'VariableNames',names),fullfile(cfg.output.directory,'timing_repetitions.csv'));
end

    function [value,detail]=calculate(method)
        detail=struct;
        theta=[cfg.model.lambda cfg.model.sigma cfg.timing.b];
        y=path(2:cfg.horizon.cheap+1,1);
        switch method
            case 'zero_one'
                if strcmp(cfg.timing.implementation,'reference')
                    [value,detail]=olg.zero_one(y,cfg.zeroOne);
                elseif strcmp(cfg.timing.zeroOneBackend,'native')
                    [value,kc]=olg.fast.olg_zero_one_native(y,cfg.zeroOne); detail.kc=kc;
                else
                    [value,kc]=olg.fast.olg_zero_one_fft(y,cfg.zeroOne); detail.kc=kc;
                end
            case 'sali'
                if strcmp(cfg.timing.implementation,'reference')
                    value=olg.sali(path(1:cfg.horizon.cheap+1,:),cfg.model,cfg.timing.b);
                else
                    value=olg.fast.olg_sali_fast(path(1:cfg.horizon.cheap+1,:),theta,cfg.model.beta);
                end
            case 'condn'
                if strcmp(cfg.timing.implementation,'reference')
                    [value,detail]=olg.condn(y,cfg.condn);
                else
                    [delta,traces]=olg.fast.olg_condn_fast(y,cfg.condn); value=delta(end); detail.traces=traces;
                end
            otherwise
                H=cfg.horizon.ftle;
                if strcmp(method,'rosenstein_short'), H=cfg.horizon.cheap; end
                opt=cfg.rosenstein; opt.maxPoints=H;
                opt.neighborMethod=cfg.timing.neighborMethod;
                if strcmp(opt.neighborMethod,'auto')
                    if olg.has_native('olg_nearest_mex'), opt.neighborMethod='native'; else, opt.neighborMethod='brute'; end
                end
                detail=olg.fast.olg_rosenstein(path(2:H+1,1),opt);
                detail.samples=H; value=detail.lle;
        end
    end
end
