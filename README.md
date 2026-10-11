# OLG experiments with File Exchange Differential Evolution

[English](README.md) | [Русский](README_RU.md)

This MATLAB package compares differential evolution (DE) with an ascending scan of the OLG parameter `b_L`, stopping each method at its first numerically detected chaos candidate. A second experiment measures the runtime of chaos indicators on one fixed OLG trajectory. Both experiments use the same indicator implementations.

The largest Lyapunov exponent is estimated **only by the Rosenstein time series method**. The configuration key `horizon.ftle` denotes its input series length. Output tables call the estimate `RosensteinLLE` or `rosenstein_lle`; no product of Jacobians is used for this estimate. Exact Jacobians are used only by the optional SALI indicator.

[Changes in this version](docs/CHANGES_FEX18593.md) · [Numerical methods](docs/METHODS.md) · [Verified example results](docs/VALIDATION.md) · [References](docs/REFERENCES.md)

DE uses **Markus Buehren’s Differential Evolution, File Exchange 18593, version 1.16.0**, with all upstream source files unchanged. [Source and license notices](THIRD_PARTY_NOTICES.md) · [SHA-256 manifest](vendor/fex18593_manifest.json). A license for the OLG-specific code has intentionally not been selected; add it before publication. The bundled third-party code retains its own license.

## Requirements and setup

MATLAB R2024a was used for verification. Parallel Computing Toolbox is needed for parallel search; serial search and indicator timing use base MATLAB. The DE source and its license are already bundled; no additional download, Statistics Toolbox, or Deep Learning Toolbox is required.

Extract the package and open `olg_experiments_fex18593` as the MATLAB current folder. If you downloaded a repository containing these files directly at its root, open that root folder instead. It must contain `olg_config.m`, `run_olg_experiment.m`, and the `+olg` folder.

Add only the package root to the path, not its `+olg` subfolder. If an older OLG package is on the path, check which public functions MATLAB resolves:

```matlab
addpath(pwd, '-begin');
which olg_config -all
which run_olg_experiment -all
```

## Compare DE with the full scan

```matlab
cfg = olg_config('compare_DE_vs_full_scan', 'paper');
result = run_olg_experiment(cfg);
```

For a shorter trajectory horizon, use `'demo'`. **Both profiles retain the full 6000-node parameter grid and the 273,034,001-point initial-state grid.** Demo does not coarsen either grid. Full dense searches are very large computations; use the explicit coarse verification example below to check installation first.

The OLG map is

```text
C_(t+1) = L_t^sigma - C_t
L_(t+1) = b_L * (beta * L_t - C_t^lambda)
```

The fixed model parameters are `lambda=3.01`, `sigma=1.03`, `beta=0.99`. The default parameter interval is `(1,1.6]`, with step `0.0001`: the ascending scan begins at **1.0001**. The grid contains 6000 points: 101 satisfy `b_L <= 1/0.99`, and 5899 lie above that boundary. This analytical boundary is not used to exclude points or guide DE.

DE proposes values on the same grid through the upstream integer-index quantization. It uses native random initialization with a population of 20, strategy 7 (`DE/rand/1/bin`), F=0.8 and CR=1. All initialization and duplicate evaluations count toward discovery cost. Both methods have a maximum of 6000 parameter evaluations and stop after completing the first parameter evaluation containing a candidate.

Every parameter evaluation processes **all 13001 × 21001 = 273,034,001 initial states** in `Q=[0,1.3] x [0,2.1]`, with inclusive endpoints and step `10^-4` in each coordinate. The grid is traversed in blocks of 1024; it is never allocated as a full matrix. **Finding a candidate does not interrupt the Q traversal.** Q specifies initial states: leaving Q does not end a trajectory as long as it remains in the nonnegative quadrant and below the numerical state limit. Parallelism is over these initial states, not over competing parameter values, so both methods have the same resource allocation and stopping rule.

```matlab
cfg.search.bRange = [1 1.6];
cfg.search.bStep = 0.0001;             % Interval length must be a multiple.
cfg.search.includeLowerEndpoint = false;
cfg.search.Q = [0 1.3; 0 2.1];         % Rows: C bounds, L bounds.
cfg.search.stateStep = [1e-4 1e-4];    % Both endpoints included.
cfg.search.stateGridSize = [];        % Empty: use stateStep (default).
cfg.search.stateBatchSize = 1024;      % Changes memory use, not grid resolution.
cfg.search.population = 20;
cfg.search.mutation = 0.8;
cfg.search.strategy = 7;              % Native DE/rand/1/bin.
cfg.search.crossover = 1;
cfg.search.repetitions = 30;          % Default: one pair of runs.
cfg.search.maxEvaluations = Inf;      % Capped at the number of grid nodes.
cfg.search.seed = 20261011;
```

For a small installation check, explicitly override the Q grid and parameter budget:

```matlab
cfg = olg_config('compare_DE_vs_full_scan', 'demo');
cfg.search.stateGridSize = [14 22];   % Explicit override: 308 states, step 0.1.
cfg.search.maxEvaluations = 50;
result = run_olg_experiment(cfg);
```

This is a coarse check, not the requested dense-grid experiment. To restore the dense grid, set `cfg.search.stateGridSize=[]`. Limiting parameter evaluations alone does not reduce the 273 million states per evaluation. If a method exhausts its budget without a candidate, the result is censored, not evidence of absence of chaos.

### Preliminary indicators

The default gate is the correlation 0–1 test. Additional gates are evaluated in the listed order; **all enabled gates must pass** before extending the trajectory and running Rosenstein.

```matlab
cfg.filters = {'zero_one'};                 % Default.
cfg.filters = {'zero_one','sali','condn'};    % Optional combination.
```

There is also a common numerical screen for approximately constant or periodic tails. The exact origin is excluded as a chaos witness. A trajectory stops immediately if it leaves the nonnegative quadrant. Reaching a numerical state limit is reported separately; it is not interpreted as proof of escape to infinity.

Default thresholds are `K >= 0.8`, `SALI <= 1e-8`, ConDN trace difference `> 0`, and Rosenstein slope `>= 0.005` with fit `R² >= 0.9`. SALI and ConDN thresholds are optional screening choices, not sufficient chaos criteria for this dissipative model. Their limitations and the precise candidate rule are described in [Numerical methods](docs/METHODS.md).

### Horizons

| Profile | Cheap trajectory end | Search transient | Retained search samples | Rosenstein series length | Initial states |
| --- | ---: | ---: | ---: | ---: | ---: |
| demo | 1000 | 100 | 900 | 2000 | 13001 × 21001 |
| paper | 5000 | 1000 | 4000 | 10000 | 13001 × 21001 |

The cheap path is `x_0,...,x_N`. Search signal samples are `C_(T+1),...,C_N`; SALI uses tangent steps from `x_T` to `x_N`. Rosenstein uses the full series `C_1,...,C_H` over the requested longer horizon, without additional transient removal. The first `N` orbit steps are reused. Settings are in `cfg.horizon`.

### Workers

```matlab
cfg.parallel.enabled = true;
cfg.parallel.workers = 'auto';  % Physical cores where detectable, capped by states per block.
cfg.parallel.resizePool = true;
% cfg.parallel.workers = 8;     % Optional override.
% cfg.parallel.enabled = false; % Run without Parallel Computing Toolbox.
```

The search uses a thread pool. Automatic selection uses the physical core count on macOS and the computational thread count as a portable fallback. It resizes an idle existing pool and refuses to replace a busy pool. More workers need not give a proportional speedup; the actual worker count is saved. Pool startup is outside each search timer.

## Compare indicator runtimes

```matlab
cfg = olg_config('compare_chaos_indicators', 'paper');
result = run_olg_experiment(cfg);
```

This mode has no parameter search. It generates one trajectory at `lambda=3.01`, `sigma=1.03`, `beta=0.99`, `b_L=1.54`, starting from `(0.5,1.0)`. It measures the 0–1 test, SALI, ConDN, and Rosenstein sequentially. The cheap indicators use 1000 iterations in demo and 5000 in paper; Rosenstein uses 2000 and 10000, respectively. **No transient is discarded in this timing mode by default.**

The common orbit is generated once before measurement. Its generation time is reported separately. Every method receives a full untimed warmup; seven timed repetitions follow, with rotating serial order. The report includes individual times and the sum of the three cheap indicator times. A ratio `RosensteinOverIndicatorTime > 1` means the indicator was faster on this run. The experiment measures the outcome rather than assuming that every preliminary indicator is faster.

```matlab
cfg.timing.repetitions = 7;
cfg.timing.warmupPasses = 1;
cfg.timing.indicators = {'zero_one','sali','condn'};
cfg.timing.b = 1.54;
cfg.timing.x0 = [0.5 1.0];
```

## Results and checkpoints

Each invocation creates a fresh subfolder under `results/<mode>/<profile>/`. It contains `result.mat`, `summary.csv`, `comparison.csv`, and PNG/FIG plots. Search additionally writes evaluation ledgers and a completed MAT file for each method and repetition. Checkpoints are saved every `cfg.search.progressEvery` evaluations and at discovery or budget exhaustion. During a long parameter evaluation, progress is printed and aggregate partial results are written to `current_parameter.mat` approximately every `cfg.search.stateProgressSeconds` seconds, at block boundaries. This is a progress snapshot, not a resumable checkpoint. An interruption can lose work after the latest snapshot; automatic resumption is not implemented.

The principal discovery fields are `FirstCandidateEvaluation`, `FirstCandidateSeconds`, `CandidateB`, and `FoundDuringInitialization`. The first three are `NaN` when the budget is exhausted without finding a candidate. `FirstCandidateSeconds` measures client-side detection at the end of the first block containing a candidate, including DE setup and previous work. `ElapsedSeconds` includes all remaining Q blocks, final checkpointing and DE cleanup. Parallel-block completion is the timing resolution; it is not a timestamp from the first worker to finish. `EvaluationSeconds` measures model and indicator evaluation only. Ledger fields count orbit steps and calls to each indicator. SALI tangent steps are counted separately. Parameter evaluations, runtime, and orbit steps can favor different methods. `Trajectories` counts every evaluated initial state, including the rest of Q after detection. `CompleteStateGrid` in a completed ledger is true for every parameter evaluation.

The dense-grid result stores the two axes and counts in `result.initialStates`, aggregate diagnostics, and one witness orbit. It does not accumulate 273 million per-state structures or a complete basin map. Individual diagnostics are retained only for grids of at most `cfg.search.retainInitialStatesMax=10000` points. Reconstruct an index range with `olg.state_block(result.initialStates, first, last)`. Each DE run also stores the exact backend version and options in `result.runs(k).backend`.

`comparison.csv` gives the full-scan/DE ratios for evaluation count, time to detection, and total search time. Ratios are `NaN` unless both runs found a candidate. Repeated DE runs use different recorded seeds. The deterministic ascending scan is repeated for paired timing measurements; execution order alternates across repetitions. No bootstrap interval is inferred from a single pair.

Reload a completed experiment without computing new trajectories:

```matlab
result = olg_show_results('path/to/saved/run');
```

Inspect an individual completed method after interrupting the other method:

```matlab
data = load('path/to/saved/run/de_rep001_completed.mat');
disp(data.out.summary);
```

The first candidate encountered by DE need not have the smallest `b_L`. The ascending scan finds the first candidate on its grid under this detector and initial-state grid. Neither observation proves the first onset of chaos, an invariant attractor, or its complete basin. The reference value `b_L=1.54` is used only in the separate timing experiment, never injected into the search.

## Tests

```matlab
results = run_tests;
```

Tests cover dense-grid dimensions and block indexing, full traversal after a candidate, direct invocation of the native DE, exact budgets within generations and initialization, reproducibility, error propagation, environment restoration, horizons, transient indexing, and shared indicator kernels. Integration results use an explicitly coarser Q grid; the full dense search has not been run for this release. The package is independent of older OLG scripts and does not load their cached results. Earlier runtimes should not be compared directly because the horizons and Lyapunov calculation have changed.

## Repository contents

| Path | Purpose |
| --- | --- |
| `olg_config.m` | Configuration for both experiment modes and profiles |
| `run_olg_experiment.m` | Common entry point |
| `olg_show_results.m` | Load and display a completed experiment |
| `+olg/` | Shared model, indicators, search, and reporting functions |
| `vendor/fex18593/` | Unmodified upstream DE source and license |
| `+olg/fex_de.m` | Adapter to the native DE implementation |
| `THIRD_PARTY_NOTICES.md` | Source, version, license and provenance |
| `examples/` | Launch scripts and an explicit coarse search check |
| `example_results/` | Verified example outputs, configurations, and timing measurements |
| `tests/` and `run_tests.m` | Automated tests and integration verification |
| `docs/` | Numerical methods, validation report, and references |
| `README_RU.md` | Russian instructions |

For GitHub publication, place the contents of `olg_experiments_fex18593` at the repository root, preserving the `+olg` directory name. Keep this English `README.md` at the root alongside `README_RU.md` so that their relative links work. Include `.gitignore`: it excludes newly generated `results/` while retaining the bundled `example_results/`. Preserve `vendor/` and `THIRD_PARTY_NOTICES.md`. Select a license for the OLG-specific work before publication.
