% Dense Q default: 273034001 states for EACH parameter evaluation.
% For an installation check, use coarse_search_check.m instead.
% Run from the package root; the full 6000-node grid remains available.
cfg = olg_config('compare_DE_vs_full_scan','demo');
result = run_olg_experiment(cfg);
