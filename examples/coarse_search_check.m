% Explicit coarse installation check; does not run the dense default Q grid.
cfg = olg_config('compare_DE_vs_full_scan','demo');
cfg.search.stateGridSize = [14 22]; % 308 states, Q step 0.1, both methods.
cfg.search.maxEvaluations = 50;
result = run_olg_experiment(cfg);
