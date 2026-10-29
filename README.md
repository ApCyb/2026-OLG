# OLG chaos experiments — optimized release, 26 October 2026

[English](README.md) | [Русский](README_RU.md)

Two MATLAB experiments share optimized numerical kernels:

1. DE search over the OLG parameter `b_L`, with either **estimated ascending-grid cost** or an **actual ascending scan**.
2. Sequential timing of the 0–1 test, SALI, ConDN and the **Rosenstein time-series exponent at two horizons**.

DE calls Markus Buehren's [File Exchange 18593](https://www.mathworks.com/matlabcentral/fileexchange/18593-differential-evolution), version 1.16.0. All 38 upstream files remain unmodified. [Third-party notices](THIRD_PARTY_NOTICES.md) · [Methods](docs/METHODS.md) · [Validation](docs/VALIDATION.md) · [Changes](docs/CHANGES_FEX18593.md) · [Updating GitHub](docs/UPDATE_GITHUB_EN.md).

## Setup

Open `olg_experiments_fex18593` as the MATLAB current folder and add **only its root**, without `genpath`:

```matlab
addpath(pwd, '-begin');
which olg_config -all
which run_olg_experiment -all
```

Verified with MATLAB R2024a on macOS Apple Silicon. Parallel search requires Parallel Computing Toolbox. Serial execution and indicator timing use base MATLAB. Optional C++ MEX kernels require a supported compiler. The GitHub package distributes their **source**, not platform-specific binaries.

For MATLAB-only execution, no build is needed. To enable the native kernels:

```matlab
build_olg_fast
```

**Rebuild after updating from October 24: the integrator ABI now provides per-node outcomes.** Close the previous idle pool before rebuilding so its workers reload the new binary. This builds the integrator, 0–1 FFT kernel and exact nearest-neighbor tree for the current platform. Build time and pool startup are outside search timers.

## Experiment 1: DE and ascending-grid cost

```matlab
cfg = olg_config('compare_DE_vs_full_scan', 'paper');
result = run_olg_experiment(cfg);
```

**The default `cfg.search.gridMode='estimate'` follows the recent fast experiment:** five actual DE runs, followed by measured grid probes and two cost extrapolations. An extrapolation is never recorded as a completed ascending scan. For an actual comparison of both search methods, explicitly select:

```matlab
cfg.search.gridMode = 'full_scan';
cfg.output.directory = fullfile(pwd,'results','paper_actual_full_scan');
result = run_olg_experiment(cfg);
```

The fixed model is

```text
C_(t+1) = L_t^sigma - C_t
L_(t+1) = b_L * (beta*L_t - C_t^lambda)
lambda = 3.01, sigma = 1.03, beta = 0.99
```

Defaults now include **b_L=1**: `[1,1.6]` with step 0.0001, **6001 nodes**. The ascending scan begins at 1. There are 102 nodes at or below `1/0.99` and 5899 above it. This analytical boundary does not prune the search or guide DE.

`Q=[0,1.3] × [0,2.1]`, with inclusive endpoints and step 0.0001 in each coordinate, has **273,034,001 initial states**. Both methods use the same seeded six-round Feistel/cycle-walking shuffle of this entire grid. The order is reproducible and contains every node once; it is not claimed to be uniform over all N! permutations. Only the axes, coordinate-power tables and current chunks are stored. Neither `demo` nor `paper` silently coarsens Q.

### Two independent choices: Q processing and b-grid comparison

```matlab
cfg = olg_config('compare_DE_vs_full_scan','paper','first_hit'); % Default Q mode.
cfg = olg_config('compare_DE_vs_full_scan','paper','full');      % Save every Q outcome.
```

The third argument sets `cfg.search.phaseScan` and gives each mode its own default output directory. It is independent of `cfg.search.gridMode`: `estimate` means measured DE plus estimated b-grid cost; `full_scan` means an actual ascending b search. Selecting Q mode `full` does not itself request an ascending b search.

`first_hit` starts with 1280 nodes, doubles batch size through 2560, 5120, 10240, 20480 and 40960, then continues at 40960. Worker chunks grow while retaining roughly the same task count. This first batch size is **not** a Q budget: a negative still exhausts all 273034001 nodes. After a hit, the launched batch completes; the retained witness is the first positive node in traversal order, independent of worker completion speed. No per-node map is written.

`full` starts with the configured large batches and processes **every** Q node, even after a candidate. It writes each node's outcome in committed batch files. DE then stops after finishing the first positive parameter evaluation. `ScreeningDeferred` is zero in this mode. Diagnostics can be disabled explicitly in a new output directory; this does not change the 0–1/Rosenstein detection rule.

```matlab
cfg.search.stateOrder = 'shuffle'; % Seeded Feistel + cycle walking; new default.
cfg.search.stateSeed = 20261026;
cfg.search.firstHitBatchSize = 1280;
% cfg.search.stateOrder = 'lex';      % C varies fastest.
% cfg.search.stateOrder = 'permuted'; % Previous affine permutation.
```

Shuffle uses O(batch) index storage, preserves the optimizer RNG and is shared across all b values and DE repetitions. It is a pseudorandom traversal, not a cryptographic primitive or a uniform choice from all N! permutations. It can improve a particular positive search, but does not make a negative full-Q evaluation cheaper by skipping states.

The standalone Q_MODES names map to this package as follows: `phaseScan` → `search.phaseScan`, `phaseOrder/phaseSeed` → `search.stateOrder/stateSeed`, `firstHitBatchSize` → `search.firstHitBatchSize`, `integrator/zeroOneBackend` → `runtime.*`, and `outputDir` → `output.directory`. Start with this package's constructor; copying the standalone configuration structure is unsupported.

### Detection and stopping

- Integrate each state to the cheap horizon, stopping immediately on a negative/nonfinite coordinate or numerical safety limit.
- Apply the 0–1 correlation test with all **32** fixed c values. Paper retains `C_1001,...,C_5000`: **4000 samples and 400 lags**.
- Only if `K>=0.8`, extend the existing orbit to 10000 and apply Rosenstein to **all `C_1,...,C_10000`**, accepting slope `>=0.005` and fit `R²>=0.9`.
- SALI and ConDN are **post-confirmation diagnostics**. Their values do not change fitness or the detection decision. ConDN retains 100 neurons and sampling factors `[1 2 4 8]`.

A **negative** parameter evaluation exhausts Q. After a **positive** evaluation, the already launched batch completes and the next batch is not launched; each worker chunk stops new indicator calls after its first candidate. Counts include all integration already performed, deferred indicator screens, confirmation and diagnostic orbit replay. This is the October 24 fast protocol. Select the separate `full` mode below to finish and save every node, including after a positive result.

| Profile | Cheap horizon | Search transient | Retained search samples | Rosenstein confirmation |
| --- | ---: | ---: | ---: | ---: |
| demo | 1000 | 100 | 900 | 2000 |
| paper | 5000 | 1000 | 4000 | 10000 |

The cheap path is reused when extending to confirmation. No transient is removed from the full Rosenstein series. The old approximate periodic-tail screen is not used by the optimized search.

### Configuration

```matlab
cfg.search.bRange = [1 1.6];
cfg.search.bStep = 1e-4;
cfg.search.includeLowerEndpoint = true;
cfg.search.Q = [0 1.3; 0 2.1];
cfg.search.stateStep = [1e-4 1e-4];
cfg.search.stateGridSize = [];        % Empty: use stateStep.
cfg.search.stateChunkSize = 4096;
cfg.search.stateBatchSize = 40960;    % Multiple of stateChunkSize.
cfg.search.repetitions = 5;
cfg.search.population = 20;
cfg.search.strategy = 7;             % Native FEX DE/rand/1/bin.
cfg.search.mutation = 0.8;
cfg.search.crossover = 1;             % One free coordinate.
cfg.search.cacheParameters = true;
cfg.search.diagnostics = true;
cfg.parallel.workers = 'auto';
```

DE optimizes the integer index of a b-grid node. Native FEX initialization, mutation, crossover, clipping, strict-improvement selection and reinitialization are preserved. Initialization is charged. Candidate discovery during initialization is flagged and does not establish that evolutionary updates caused an advantage.

Completed negative evaluations can be reused **within one DE repetition**. `Evaluations` counts all requests, including cache hits; `UniqueEvaluations` counts actual new objective computations. Cache hits add zero new model steps, trajectories and indicator calls. The cache is not shared between repetitions. `cfg.search.cacheParameters=false` disables it.

### Native backends and workers

Defaults preserve MATLAB orbit arithmetic and use cached MATLAB FFT. Search neighbor lookup is automatic: exact native tree if built, otherwise brute force.

```matlab
cfg.runtime.integrator = 'native';
cfg.runtime.zeroOneBackend = 'native';
cfg.rosenstein.neighborMethod = 'native';
cfg.parallel.poolType = 'auto';
```

For a fully MATLAB search, set integrator/0–1 to `'matlab'` and neighbor method to `'brute'`. Any selected MEX kernel requires **Processes** in R2024a; MATLAB-only execution uses **Threads**. Automatic worker count uses physical cores, capped by chunks per batch. Data are transferred once per parameter using `parallel.pool.Constant`.

MATLAB and C++ can round arithmetic differently; long chaotic trajectories, K/LLE and first candidate parameters can therefore differ. Compare both search methods with the **same backend and chunk/batch configuration**. Use a new output directory after changing numerical settings or backends.

### What the grid estimates mean

`estimate` mode measures a short ascending prefix and deterministic probes in parameter regimes, then extrapolates cost. The default historical target is **b_L=1.5069**, index **5070** on the inclusive b-grid. It is a hypothesis inherited from an earlier protocol, not an established first hit of the new detector. Probe flags report whether it was checked, confirmed, or contradicted by an earlier candidate. Probes are never injected into DE.

`estimated_grid_cost.csv` contains prefix and regime extrapolations. A regime without a measurement yields `NaN`. Deterministic probes do not provide statistical confidence intervals and can miss expensive regimes. Use `full_scan` when a measured first candidate on the ascending grid is required.

## Experiment 2: optimized indicator timing

```matlab
cfg = olg_config('compare_chaos_indicators', 'paper');
result = run_olg_experiment(cfg);
```

Fixed `(lambda,sigma,beta,b_L)=(3.01,1.03,0.99,1.54)` and initial state `(0.5,1)`. One common MATLAB orbit is generated before timing. No transient is removed. The three indicators use 5000 observations in paper / 1000 in demo. **Rosenstein is timed at both 5000 and 10000 in paper, or 1000 and 2000 in demo.** No Jacobian-product FTLE baseline is included.

The report has six rows: 0–1, SALI, ConDN, their within-repetition total, short Rosenstein, long Rosenstein. A complete warmup is followed by seven fixed-order sequential repetitions, matching the supplied optimized script. Pool workers are not used.

0–1 uses batched cached FFT; SALI normalizes every 16 steps and at the endpoint; ConDN batches four driven signals, uses a sparse reservoir, omits unused training and computes `trace(C)` instead of SVD. Reservoir generation is cached at fixed settings, including across warmup and timed calls. These changes preserve the specified diagnostics; they do not reduce c values, lags, observations or reservoir size.

```matlab
cfg.timing.implementation = 'optimized'; % Or 'reference'.
cfg.timing.neighborMethod = 'brute';    % Default: match the supplied baseline.
% cfg.timing.neighborMethod = 'native'; % Separate exact-tree timing audit.
cfg.timing.zeroOneBackend = 'matlab';
```

The search's automatic tree does not silently change the timing baseline. To reproduce the matched kernel benchmark after building, run `benchmark_olg_fast` (default: 1024 common Q nodes, three repetitions). It benchmarks kernels, not a full DE/grid experiment.

The [supplied October 24 table](example_results/optimized_timing_supplied_20261024/timing_summary.csv) is retained with only the Rosenstein baselines, per the requested scope. Its measured values are not relabeled as a fresh run of this unified package.

## Scan one b value and view a full outcome map

```matlab
cfg = olg_config('compare_DE_vs_full_scan','paper','full');
% Explicit coarse check; remove this override only for a dense-grid run.
cfg.search.stateGridSize = [14 22];
cfg.search.stateChunkSize = 32;
cfg.search.stateBatchSize = 64;
cfg.output.directory = fullfile(pwd,'results','map_check');
r = olg_scan_b(1.54,cfg);       % No DE and no b-grid cost probes.
preview = olg_plot_phase_map(r.basinFolder);
```

For the dense default grid, use `stateGridSize=[]` in a fresh directory. **Full records require approximately 47*N bytes before MAT compression: 12.83 GB (11.95 GiB) per b value** on the dense grid, plus metadata. Multiple parameter evaluations require correspondingly more disk space. Full trajectories for all states are not stored. A repeated negative parameter within one DE run reuses its completed evaluation/map.

Each `*_basin` directory contains metadata and `batch_*.mat` files beside the evaluation checkpoint. Batch files have traversal `start/stop`, a `scanId` and these record columns:

| Column | Storage | Meaning |
| --- | --- | --- |
| `id` | uint32 | Original Cartesian node index, independent of shuffle order |
| `status` | uint8 | Finite-horizon outcome; see `olg_phase_legend` |
| `attractor`, `period` | uint32, uint16 | Numerical regular-regime ID and detected period |
| `steps` | uint32 | Trajectory updates, excluding diagnostic replay |
| `last` | two doubles | Last valid or first inadmissible state |
| `K`, `LLE`, `SALI`, `ConDN` | single | Stored indicators; candidate decisions use double beforehand |

Only regular tails receive regime IDs, matched in (C,L) up to phase and configured tolerances. Defaults are max period 32, at least max(64,8*p) tail observations, period tolerance 1e-7 and cluster tolerance 1e-5. Slow transients or nearby regimes can be misclassified/merged; these labels do not establish stability. **Chaos candidates have status=9 and attractor=0**; separate chaotic-attractor identities remain unresolved. Code 11 groups exits/nonfinite/safety failures during confirmation. Exact initial origins have status=1 and steps=0.

`olg_plot_phase_map` reads committed records only, including during an unfinished full scan. Orphan or uncommitted files are ignored. Its preview uses at most 600×600 actual Cartesian nodes, leaves unvisited points blank and does not interpolate outcome labels. All processed dense records remain on disk. The reader also accepts the standalone Q_MODES map format; this is read-only compatibility, not checkpoint migration.

For each parameter, `firstCandidate.seconds` is the client time when the first positive batch has returned, not a worker-side timestamp. `firstCandidate.phasePosition` is its ordered position; `phaseIndex` is its original Cartesian ID. Search ledgers/summaries expose `FirstCandidateSearchSeconds` (also `FirstCandidateSeconds`) separately from `ElapsedSeconds`, which includes finishing the positive full map. The first-hit time is preserved across resume. Estimates of grid cost use the same selected Q mode and remain total-mode cost estimates.

## Results, interruption and resume

Each configuration writes to `cfg.output.directory`. **Repeating the same call resumes that directory**; use another directory for a new independent experiment. Configuration schema 4 and numerical protocol fingerprints reject incompatible checkpoints. Older checkpoints cannot be resumed.

Parameter checkpoints save the next committed Q position about every 30 seconds. Optimizer checkpoints save each returned objective value. After interruption, DE reconstructs its native state by deterministic replay of recorded callback values; replay performs **no trajectory evaluations**. A pending parameter resumes its Q checkpoint, including a full scan whose candidate was already found. In `full`, every record batch is written before committing its checkpoint, and mode/order/seed/batch changes reject resume. Uncommitted batches are recomputed. Completed runs reload without changing their recorded counters/times.

`FirstCandidateSeconds`/`FirstCandidateSearchSeconds` stop at the first returned positive batch. In `full`, the objective can finish much later; use `ElapsedSeconds` for that complete cost. The batch boundary includes post-confirmation diagnostics and parallel work already launched.

`ElapsedSeconds` is accumulated committed scan time plus optimizer/controller overhead; it excludes pool startup and downtime. Work in an interrupted, uncommitted batch is not recovered by the timer. Worker-stage seconds are sums across parallel calls and may exceed elapsed time. `OrbitSteps` includes diagnostic orbit replay; SALI tangent work is counted separately.

```matlab
result = olg_show_results(cfg.output.directory); % Completed results only, no simulations.
```

Measured comparisons save summaries, request ledgers, MAT checkpoints and PNG/FIG plots. Estimate mode additionally saves `actual_de_runs.csv`, `de_summary.csv`, `grid_probes.csv`, `estimated_grid_cost.csv` and `grid_cost_strata.csv`. One witness C series, diagnostics and Rosenstein fit are retained; full mode additionally saves all per-node records. Finite numerical candidates do not prove an invariant chaotic attractor or its complete basin.

## Small verification run

```matlab
cfg = olg_config('compare_DE_vs_full_scan','demo');
cfg.search.gridMode = 'full_scan';
cfg.search.Q = [0.49 0.51; 0.99 1.01];
cfg.search.stateGridSize = [3 3];
cfg.search.bRange = [1.53 1.55];
cfg.search.repetitions = 1;
cfg.search.stateChunkSize = 2;
cfg.search.stateBatchSize = 4;
cfg.parallel.workers = 2;
cfg.output.directory = fullfile(pwd,'results','small_check');
result = run_olg_experiment(cfg);
```

This intentionally narrowed positive-control case checks installation; it is not evidence of a general DE speed advantage. Full dense-Q parameter searches were not run for this release.

```matlab
results = run_tests;
addpath(fullfile(pwd,'tests'));
verify_release; % Requires built kernels; explicit small grids and two workers.
```

For publication, copy the contents of this folder to the existing repository code root. Preserve third-party licenses. The OLG-specific distribution license remains unselected; retain any license already chosen in your repository. Detailed [GitHub update instructions](docs/UPDATE_GITHUB_EN.md) cover a branch, validation, review and push.
