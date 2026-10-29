function cfg=olg_prepare_fast(cfg)
% Resolve automatic backend before checkpoint fingerprinting.
cfg.runtimeFingerprint=struct('matlab',version,'computer',computer);
if strcmp(cfg.integrator,'auto')
    if olg.has_native('olg_integrate_mex'), cfg.integrator='native'; else, cfg.integrator='matlab'; end
end
if strcmp(cfg.integrator,'native')
    assert(olg.has_native('olg_integrate_mex'),'OLG:Build','Run build_olg_fast first.');
    try
        % Zero-state ABI probe: no trajectories or random draws.
        [~,~,~,~,~,~,~]=olg.fast.olg_integrate_mex(zeros(0,2),zeros(0,2), ...
            [cfg.lambda cfg.sigma 1],cfg.beta,1,cfg.maxState,0);
    catch err
        if strcmp(err.identifier,'OLG:NativeArgs')
            error('OLG:RebuildNative','Integrator ABI changed: rebuild this release with build_olg_fast.');
        end
        rethrow(err);
    end
end
if strcmp(cfg.rosenstein.neighborMethod,'auto')
    if olg.has_native('olg_nearest_mex'), cfg.rosenstein.neighborMethod='native';
    else, cfg.rosenstein.neighborMethod='brute'; end
end
if strcmp(cfg.zeroOneBackend,'native')
    assert(olg.has_native('olg_zero_one_native_mex'),'OLG:Build','Run build_olg_fast first.');
end
needsProcesses=strcmp(cfg.integrator,'native') || strcmp(cfg.rosenstein.neighborMethod,'native') || strcmp(cfg.zeroOneBackend,'native');
if strcmpi(cfg.poolType,'auto')
    if needsProcesses, cfg.poolType='Processes'; else, cfg.poolType='Threads'; end
end
assert(~needsProcesses || ~strcmpi(cfg.poolType,'Threads'),'OLG:NativePool', ...
    'MEX kernels require Processes in MATLAB R2024a. Set poolType=auto or Processes.');
if cfg.usePhaseLookup
    step=cfg.stateStep; if isscalar(step), step=[step step]; end
    n=round(diff(cfg.Q,1,2)./step(:));
    c=cfg.Q(1,1)+(0:n(1))'*step(1); l=cfg.Q(2,1)+(0:n(2))'*step(2);
    cfg.phaseLookup=struct('c',c,'l',l,'cPower',c.^cfg.lambda,'lPower',l.^cfg.sigma);
end
end
