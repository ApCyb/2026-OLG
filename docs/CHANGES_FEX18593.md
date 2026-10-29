# Changes in the 26 October 2026 release

- Added explicit `first_hit` and `full` Q modes as the third argument to `olg_config`. Two-argument calls default to first_hit. Each mode gets a separate output directory.
- Added seeded six-round Feistel/cycle-walking shuffle as the default, retaining lex and previous affine traversal options. It requires no full randperm array, preserves RNG and visits each node once.
- Added adaptive first-hit batches starting at 1280, doubling to 40960. Negative evaluations still exhaust Q without a point budget.
- Full mode completes every positive Q and writes per-node finite-horizon outcomes, regular-tail IDs, periods, steps, last states and indicator values. Approximate raw storage is 47*N bytes, 12.83 GB per dense Q/b.
- Added `olg_scan_b`, `olg_plot_phase_map`, `olg_phase_legend` and small map examples. The map reader handles committed data only and supports reading the standalone map format.
- Separated first candidate search time from full-map completion time. First-hit witnesses follow traversal order, not worker finish order. Prefix and local first-hit times survive resume.
- Updated the optional C++ integrator to return per-node details; rebuild MEX and restart previous worker pools after updating. The client checks its changed ABI.
- Configuration schema is 4; previous FAST/STAGED/Q_MODES and October 24 checkpoints are not resumable. Read-only old-map access does not imply checkpoint migration.
- Preserved FEX18593 v1.16.0 unmodified, negative parameter caching, complete-grid comparison and explicitly labeled grid-cost estimates. Experiment 2 retains the same Rosenstein-only indicators/baselines.
- Updated RU/EN READMEs, GitHub update instructions, source provenance, tests and small verification artifacts. No dense 273034001-node search was run for this release.

Historical reports: [24 October](VALIDATION_20261024.md), [11 October](VALIDATION_20261011.md). Their costs should not be mixed with the new order, batching or Q modes.
