% Dense Q default: 273034001 states for EACH parameter evaluation.
% For an installation check, use coarse_search_check.m instead.
cfg = olg_config('compare_DE_vs_full_scan','paper');
result = run_olg_experiment(cfg);
