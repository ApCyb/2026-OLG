# Numerical methods and comparison protocol

## OLG model

The map is `C_(t+1)=L_t^sigma-C_t`, `L_(t+1)=b_L*(beta*L_t-C_t^lambda)`. The default fixed parameters are `lambda=3.01`, `sigma=1.03`, and `beta=0.99`. Initial states are nonnegative. A negative component ends a trajectory before any subsequent fractional power is evaluated. No projection, clipping, or reinjection is performed.

An exact initial origin is recorded separately and cannot be a chaos witness. Numerical overflow and `cfg.detector.maxState` stops are distinct from leaving the quadrant. The rectangle Q specifies initial states only. Finite survival in the quadrant is not an invariance proof.

## Candidate detection

For each initial state, the detector performs these steps:

1. Generate the orbit to the cheap horizon N, stopping immediately on a domain or numerical failure.
2. Retain states from the transient T onward. Screen the tail for an approximate period from 1 to `maxPeriod=32`, using up to 128 comparisons by default, at tolerance `1e-7*max(1,tail amplitude)`.
3. Evaluate the selected cheap indicators in order. Stop at the first failed gate. Scalar methods receive `C_(T+1),...,C_N`; SALI receives `x_T,...,x_N`.
4. Extend a passing orbit to H without repeating its first N steps. Repeat the regular-tail screen.
5. Estimate the largest exponent by Rosenstein on `C_1,...,C_H`. Accept a candidate only when the slope is at least 0.005 and the fit R² is at least 0.9.

A parameter is a candidate when at least one grid initial state passes this complete rule. Every initial state is still evaluated for that parameter, so scheduling and worker count cannot alter the parameter-level stopping rule. One witness orbit and aggregate counts are saved at discovery. Per-state diagnostics are retained only when the grid size does not exceed `cfg.search.retainInitialStatesMax` (10000 by default); the dense grid is processed without accumulating per-state objects. A candidate's Rosenstein regression curve and pair counts are available in `discovery.witness.rosensteinDetails`.

The periodicity screen is a finite-tolerance numerical test. Optional gates can reject true chaotic trajectories as well as spurious candidates. Sensitivity to initial-state resolution, horizon, tolerance, and fit interval should be studied before interpreting a candidate as an attractor.

## Indicator definitions

The [0–1 correlation test](https://arxiv.org/abs/0906.1418) uses the centered, standardized C series, 32 fixed values of c in `(pi/5,4*pi/5)`, maximum lag `floor(N/10)`, and the median of the displacement correlations. The deterministic c values remove objective noise from DE. A constant series returns zero.

[SALI](https://arxiv.org/abs/1412.7401) starts with two orthogonal unit deviations, propagates them through the exact OLG tangent map, and normalizes them independently at each step. It returns `min(norm(v1+v2),norm(v1-v2))`. There is no Gram–Schmidt step. In a dissipative system, alignment can also occur on regular attractors. A small SALI is therefore only an optional gate here.

The ConDN implementation is a multirate trace-difference variant based on [Ismail et al.](https://doi.org/10.1109/ACCESS.2022.3174960). It uses sampling factors `[1,2,4,8]`, equal-length normalized samples, a fixed 100-neuron reservoir with spectral radius 0.9, and aperture 10. It computes conceptors `C=R/(R+alpha^(-2)*I)` and returns `sum(svd(C_8))-sum(svd(C_1))`. It does **not** fit the multi-rate saturation coefficient from equation (20) of that paper. The configurable positive-difference gate is a heuristic requiring calibration for OLG. White-noise installation, readout and internal-weight training, conceptor construction, and trace calculation are all included in its measured runtime. Private random streams preserve DE's random sequence.

The [Rosenstein estimate](https://doi.org/10.1016/0167-2789%2893%2990009-P) uses the entire supplied scalar series, standardized before delay reconstruction. Defaults: embedding dimension 3, delay 1, Theiler window 32, divergence lags 0 through 48, linear fit at lags 5 through 20, and at least 20 usable neighbor pairs at each fit lag. The slope of mean log neighbor separation is reported in natural logarithms per map iteration. The estimate is undefined for a constant series or insufficient pairs. Fit R² is retained separately. Series length H is distinct from the short divergence-lag interval used in the regression. Changing these fit settings can change both the numerical value and candidate detection.

The Rosenstein implementation uses direct nearest-neighbor search with O(M²) time and O(Mm) memory. It uses no hidden point cap, decimation, Jacobian product, or external nearest-neighbor toolbox. The term FTLE in configuration denotes the requested finite-data largest-exponent diagnostic; it is not the maximum-singular-value definition of a tangent-product FTLE.

## Differential evolution objective

DE maximizes the highest trajectory score over the fixed initial-state grid. An exited trajectory has a negative score, increasing with survival duration. A detected regular tail scores zero. Nonregular short survivors score between 1 and 2 according to preliminary indicator progress. Trajectories that reach Rosenstein but fail confirmation receive a score below 2.5. Candidates score above 3. Nonfinite indicator values fail their gates. The full scoring rule is in `+olg/trajectory.m`.

The optimizer is the unmodified [Markus Buehren Differential Evolution submission 18593](https://www.mathworks.com/matlabcentral/fileexchange/18593-differential-evolution), version 1.16.0 (2019-11-13), bundled under `vendor/fex18593`. The adapter uses native strategy 7 (`DE/rand/1/bin`), population 20, mutation factor F=0.8, and CR=1. There is one free coordinate. CR=1 makes this coordinate undergo native binomial crossover on every trial. These are experiment settings; the upstream defaults are not identical.

With `snapToGrid=true`, the native variable is an integer index in `[1,numel(bValues)]` with quantization 1; the callback maps it to `bValues(index)`. Native initialization, donor permutations, mutation, crossover, clipping at parameter bounds, strict-improvement selection, and reinitialization are preserved. Initialization uses the upstream random initialization and quantization rules, not the previous package's discrete sampling scheme. Native `nochangeiter=10` and `nofevaliter=10` are retained. Initialization is random with no supplied preferred parameter (`useInitParams=0`). With `snapToGrid=false`, DE instead proposes values over `[bValues(1),bValues(end)]` with native nominal quantization 0; this optional setting changes the search domain and should be reported explicitly.

The upstream history cache is disabled (`saveHistory=0`): duplicate objective calls are reevaluated and charged. Slave processes, upstream plotting and email are disabled. MATLAB threads parallelize only the OLG initial states. The experiment ledger replaces the upstream history. The callback logs the native `iterationNr` through read-only access to its calling evaluation function; the source version is pinned for this reason.

After the callback has completed all Q states and recorded its results, the adapter raises and handles a dedicated stop exception on a candidate or budget exhaustion. Native generation-level stopping would otherwise evaluate additional population members. Other exceptions propagate. This also enforces budgets smaller than the initial population. The adapter runs the unchanged upstream program in a private temporary directory and restores the caller's directory, path and random state on success or failure. Temporary timing/semaphore files are removed. Backend settings and provenance are stored in each DE run's `backend` field.

No analytic exclusion at `b_L=1/beta`, no known chaotic point, and no previous experiment result enter the objective or initialization.

## Dense initial-state grid

Both search methods use `Q=[0,1.3] x [0,2.1]` with inclusive endpoints and step `10^-4` in each coordinate: **13001 x 21001 = 273034001** states per parameter evaluation, in both demo and paper profiles. The two axes are stored separately. Blocks of at most 1024 states are constructed on demand, in the same order as MATLAB `ndgrid` flattened columnwise: C varies fastest. No point is sampled out or skipped, and finding a candidate does not end the Q traversal.

Workers evaluate each block with `parfor`. Counters include every state and every orbit/indicator operation in all blocks. Candidate counts and survivor counts are aggregates over the complete Q grid. The default storage includes one witness rather than a dense basin map. `result.initialStates` is the grid descriptor (`C`, `L`, `shape`, `count`, `step`, `order`), not a 273-million-row matrix. `olg.state_block` reconstructs any contiguous range of indices. A nonempty `stateGridSize` explicitly overrides `stateStep` for small verification runs; it is never enabled silently by demo.

The ascending scan has no random initialization and starts at the first admissible grid point. DE initialization is fully charged. A candidate found during DE initialization supports a claim about the complete randomized search procedure; it does not establish that evolutionary updates caused the advantage. For that narrower claim, inspect generations and compare a separately specified random-search baseline.

## Runtime interpretation

Search timers include the full trajectory and gate computations, DE setup and decisions, and periodic checkpoint overhead. Worker-pool startup and final plotting are outside the timers. The first run may also contain MATLAB compilation overhead. Execution order alternates across repeated pairs. All initial states of a parameter are processed before checking the search stop condition. `FirstCandidateSeconds` records when the client receives the first block containing a candidate, measured from the start of that method. This includes completion of the whole parallel block, rather than a worker-specific finish timestamp. `ElapsedSeconds` also includes all later blocks required to finish Q, final parameter-level checkpointing and DE cleanup. `FirstCandidateStateIndex` is the first candidate in deterministic grid order, not necessarily the worker that finished first. The same batching policy applies to both methods.

Indicator timing excludes common orbit generation, applies one full warmup per method, rotates the serial measurement order, and reports all seven measurements plus medians. Reservoir preparation is included in ConDN; embedding and neighbor search are included in Rosenstein. The cheap-total row is a sum within each repetition, not an additional independent call. Parallel workers are not used in this mode.

The search comparison reports actual discovery cost or censoring at a common budget. The timing comparison reports actual speed ratios. Neither report presupposes that DE or a given indicator must win. Results from the legacy package have different horizons and detector semantics and are not imported.
