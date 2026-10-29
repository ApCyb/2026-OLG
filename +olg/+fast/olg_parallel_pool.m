function info = olg_parallel_pool(cfg,taskCount)
% One thread worker per physical CPU core in automatic mode; never more
% workers than independent initial-state trajectories. Numeric overrides
% remain available. Pool startup is outside each method's search timer.
info=struct('requestedWorkers',0,'actualWorkers',0,'physicalCores',NaN, ...
    'performanceCores',NaN,'computationalThreads',NaN,'poolType','none');
if ~cfg.useParallel, return; end
if ~license('test','Distrib_Computing_Toolbox')
    error('OLG:ParallelLicense','Parallel Computing Toolbox unavailable. Set useParallel=false.');
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
poolType='Threads'; if isfield(cfg,'poolType'), poolType=cfg.poolType; end
wrongType=~isempty(pool) && (isa(pool,'parallel.ThreadPool')~=strcmpi(poolType,'Threads'));
resize=isfield(cfg,'resizePool') && cfg.resizePool;
if ~isempty(pool) && resize && (pool.NumWorkers~=requested || wrongType)
    if isprop(pool,'Busy') && pool.Busy
        error('OLG:PoolBusy','Existing pool is busy. Finish or stop its work before resizing it.');
    end
    fprintf('Resizing parallel pool: %d -> %d %s workers.\n',pool.NumWorkers,requested,poolType);
    delete(pool); pool=[];
end
if isempty(pool), pool=parpool(poolType,requested); end
assert(isa(pool,'parallel.ThreadPool')==strcmpi(poolType,'Threads'), ...
    'OLG:PoolType','Existing pool is incompatible. Enable resizePool or close it.');
info.actualWorkers=pool.NumWorkers; info.poolType=class(pool);
units='trajectories per evaluation';
if isfield(cfg,'evaluationMode') && strcmp(cfg.evaluationMode,'staged')
    units='worker chunks per batch';
end
fprintf('OLG parallel pool: %d workers (%d physical cores, %d %s).\n', ...
    info.actualWorkers,info.physicalCores,taskCount,units);
end
