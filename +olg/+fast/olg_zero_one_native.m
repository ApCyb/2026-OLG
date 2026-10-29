function [K,kc]=olg_zero_one_native(y,cfg)
% Double-precision native implementation of the same finite-sample test.
assert(olg.has_native('olg_zero_one_native_mex'),'OLG:NativeMissing', ...
    'Run build_olg_fast before selecting a native implementation.');
[K,kc]=olg.fast.olg_zero_one_native_mex(double(y(:)),double(cfg.cValues(:).'), ...
    double(floor(numel(y)*cfg.lagFraction)));
kc=reshape(kc,size(cfg.cValues));
end
