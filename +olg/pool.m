function info = pool(cfg,taskCount)
% One thread worker per physical CPU core in automatic mode; never more
% workers than independent initial-state trajectories. Numeric overrides
% remain available. Pool startup is outside each method's search timer.
info=struct('requestedWorkers',0,'actualWorkers',0,'physicalCores',NaN, ...
    'performanceCores',NaN,'computationalThreads',NaN,'poolType','none');
if ~cfg.enabled, return; end
if ~license('test','Distrib_Computing_Toolbox')
    error('OLG:ParallelLicense','Parallel Computing Toolbox unavailable. Set cfg.parallel.enabled=false.');
end
info.computationalThreads=maxNumCompThreads;
info.physicalCores=info.computationalThreads;
if ismac
    [status,value]=system('sysctl -n hw.physicalcpu');
    if status==0 && isfinite(str2double(value)), info.physicalCores=str2double(value); end
    [status,value]=system('sysctl -n hw.perflevel0.physicalcpu');
    if status==0 && isfinite(str2double(value)), info.performanceCores=str2double(value); end
end
automatic=(ischar(cfg.workers) || isstring(cfg.workers)) && strcmpi(cfg.workers,'auto');
if automatic
    requested=info.physicalCores;
else
    validateattributes(cfg.workers,{'numeric'},{'scalar','integer','positive','finite'});
    requested=double(cfg.workers);
end
requested=min(requested,taskCount); info.requestedWorkers=requested;
pool=gcp('nocreate');
resize=isfield(cfg,'resizePool') && cfg.resizePool;
if ~isempty(pool) && resize && (pool.NumWorkers~=requested || ~isa(pool,'parallel.ThreadPool'))
    if isprop(pool,'Busy') && pool.Busy
        error('OLG:PoolBusy','Existing pool is busy. Finish or stop its work before resizing it.');
    end
    fprintf('Resizing parallel pool: %d -> %d thread workers.\n',pool.NumWorkers,requested);
    delete(pool); pool=[];
end
if isempty(pool), pool=parpool('Threads',requested); end
info.actualWorkers=pool.NumWorkers; info.poolType=class(pool);
fprintf('OLG parallel pool: %d workers (%d physical cores, %d parallel tasks available).\n', ...
    info.actualWorkers,info.physicalCores,taskCount);
end
