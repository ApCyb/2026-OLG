# Changes from the original unified OLG package

- DE now runs the unmodified Markus Buehren implementation from File Exchange 18593, version 1.16.0. Native initialization, clipping, strict selection and reinitialization replace the earlier hand-written search rules. The adapter preserves per-evaluation stopping and budgets.
- Both search methods use Q=[0,1.3] × [0,2.1], with step 0.0001 and inclusive endpoints in both profiles: 273,034,001 initial states. Traversal is complete at each parameter and uses bounded-size blocks. A candidate does not stop this inner traversal.
- `stateStep`, `stateBatchSize`, `retainInitialStatesMax` and `stateProgressSeconds` are configurable. A nonempty `stateGridSize` is an explicit resolution override for verification or other experiments; demo no longer coarsens Q.
- `result.initialStates` is a grid descriptor rather than a Cartesian-product matrix. Dense per-state diagnostics are replaced by aggregates and one witness. Small grids retain individual diagnostics.
- Discovery time is recorded when the first candidate block is returned. Total search time also includes the required remaining Q blocks. Ledger fields identify the completed grid, first candidate index and detection time.
- Configuration schema is version 2. Create a fresh configuration using this package's `olg_config`, rather than loading an older configuration structure.
- The Rosenstein-only Lyapunov estimator and both indicator-timing profiles retain their definitions. New example search outputs use an explicitly coarse Q grid; they are not dense-grid results and do not reuse older DE measurements.
- English and Russian instructions, upstream provenance, source hashes, license notices and regression tests are included. No license has been selected for the OLG-specific code.
