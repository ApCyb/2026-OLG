% Explicit small positive-control experiment, not a dense-Q benchmark.
cfg=olg_config('compare_DE_vs_full_scan','demo');
cfg.search.gridMode='full_scan'; cfg.search.repetitions=1;
cfg.search.Q=[.49 .51;.99 1.01]; cfg.search.stateGridSize=[3 3];
cfg.search.bRange=[1.53 1.55];
cfg.search.stateChunkSize=2; cfg.search.stateBatchSize=4;
cfg.parallel.workers=2;
cfg.output.directory=fullfile(pwd,'results','small_check');
result=run_olg_experiment(cfg);
