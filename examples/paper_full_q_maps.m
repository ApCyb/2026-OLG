% Very large: ~12.83 GB raw records per dense Q/b value before compression.
% gridMode remains 'estimate': actual DE runs, then measured b-grid probes.
cfg=olg_config('compare_DE_vs_full_scan','paper','full');
result=run_olg_experiment(cfg);
