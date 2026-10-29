% Very large dense-Q run: an actual ascending scan, not a cost estimate.
cfg=olg_config('compare_DE_vs_full_scan','paper');
cfg.search.gridMode='full_scan';
cfg.output.directory=fullfile(pwd,'results','paper_actual_full_scan');
result=run_olg_experiment(cfg);
