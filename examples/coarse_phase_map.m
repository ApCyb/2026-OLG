% Full records for 308 coarse Q nodes; paper horizons, not a dense-Q run.
cfg=olg_config('compare_DE_vs_full_scan','paper','full');
cfg.search.stateGridSize=[14 22]; cfg.search.stateChunkSize=32; cfg.search.stateBatchSize=64;
cfg.parallel.workers=2;
cfg.output.directory=fullfile(pwd,'results','map_check');
r=olg_scan_b(1.54,cfg);
preview=olg_plot_phase_map(r.basinFolder);
