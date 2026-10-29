# Numerical protocol — 26 October 2026

## Model and domains

`C_next=L^sigma-C`, `L_next=b_L*(beta*L-C^lambda)`, with default `(lambda,sigma,beta)=(3.01,1.03,0.99)`. A negative coordinate ends a trajectory immediately, before a subsequent fractional power. Nonfinite states and a numerical safety limit are recorded as stopping conditions, not proofs of escape to infinity. Q specifies initial states only.

Default Q is `[0,1.3] × [0,2.1]`, inclusive step 0.0001: 13001 × 21001 = 273034001 nodes. The default virtual order is a six-round Feistel permutation with cycle walking into the valid node domain, using fixed six uint32 keys from stateSeed=20261026. Products in the mixing function stay within exact double integer range; the permutation does not use saturating uint multiplication. It is bijective; it neither samples nor repeats nodes within one traversal. The previous affine order and lexicographic order remain selectable. No claim of cryptographic security or uniform choice among all N! permutations is made. Both methods use the same permutation. An explicit `stateGridSize` overrides resolution for verification; demo does not do so automatically.

The b-grid is now inclusive `[1,1.6]`, step 0.0001: 6001 nodes. The ascending scan starts at 1. Analytical convergence boundaries do not exclude evaluations. Known candidate b_L=1.54 is used in timing and positive controls, not supplied to DE initialization.

## Staged candidate test

For paper, integrate 5000 updates, retaining `C_1001,...,C_5000` for the 0–1 correlation test. All 32 fixed c values and 400 lags are used. K>=0.8 triggers continuation of the same orbit to 10000; no first-stage updates are repeated. Rosenstein receives all `C_1,...,C_10000`. A candidate requires valid fit, slope>=0.005 and R²>=0.9.

Demo uses 1000 updates, transient 100 and 2000-update confirmation. Exact initial origins are recognized directly. The optimized search does not use the former approximate periodic-tail rejection. No SALI or ConDN threshold participates in discovery.

A negative parameter evaluation exhausts Q. A positive stops before the next client batch; the current batch of worker chunks is collected completely. Within a worker chunk, all states have already been integrated to the short horizon; subsequent indicator screens stop after a candidate. Deferred screens are counted. Therefore `Trajectories` counts integrated initial states, not only states receiving indicators. `exhaustedPhasePool`/`CompleteStateGrid` report whether all Q was reached. The separate `phaseScan=full` mode exhausts positive evaluations as well and saves all node records. In default `first_hit`, initial client batches start at 1280 and double to 40960 while worker task counts remain approximately constant. There is no Q-point cap on a negative.

SALI and ConDN run only after Rosenstein confirmation. The short orbit is regenerated using the same integrator and first-step lookup tables, and its C series must match exactly. Its additional model steps and diagnostic time are included. Diagnostic failures have a status and do not revoke an already confirmed candidate. Tangent steps and calls are counted separately. Multiple chunks in a launched batch may confirm candidates, so diagnostics can run more than once before collection.

## Optimized numerical kernels

The MATLAB integrator uses fixed history slots, compacts once after 32 steps, and returns histories only for survivors. A separate C++ integrator uses reusable buffers for exiting trajectories. Powers of the initial one-dimensional C and L coordinates are precomputed and reused at the first update only on exact coordinate matches.

The MATLAB 0–1 implementation batches FFTs across c values, caches carriers and lag tables, and pads sufficiently for all requested lags. The native kernel evaluates the same finite-sample statistic. Near the K gate (within 1e-8), native values are rechecked with MATLAB FFT. There is no reduction of samples, c values or lags.

Rosenstein uses standardization, embedding dimension 3, delay 1, Theiler window 32, divergence lags 0:48, fit 5:20 and at least 20 pairs at each fit lag. Zero/near-zero candidate distances (`d²<=eps`) are excluded; equal nearest distances select the smaller index. Brute force and the exact k-d tree implement the same rules. Search uses the full requested length; no hidden cap/decimation is applied. The tree is exact, but its worst-case cost can still be quadratic for degenerate data. The slope is in natural logarithms per map iteration. This is a time-series largest-exponent estimate over finite data.

SALI uses scalar tangent updates and positive normalization every 16 steps and at the endpoint. ConDN uses sampling factors `[1,2,4,8]`, equalized pattern lengths, a fixed 100-neuron reservoir, sparse multiplication and parallel independent driven states. Unused readout/internal-weight training is omitted; `trace(C)` replaces the SVD nuclear norm of the positive-semidefinite conceptor. The diagnostic is the trace-difference variant, not a fitted probability of chaos. The reservoir is cached across identical configurations and its generation preserves the caller RNG.

Native integration and MATLAB integration need not yield identical long chaotic orbits because of floating-point rounding. Both comparison methods must use the same backend. Native kernels require process workers in R2024a; MATLAB-only kernels can use threads. Constant tables are transferred once per parameter through `parallel.pool.Constant`.

## File Exchange DE and objective caching

The native engine is Markus Buehren's unmodified File Exchange 18593, version 1.16.0. The adapter selects strategy 7 (DE/rand/1/bin), NP=20, F=0.8 and CR=1 for the one free coordinate. The native variable is a quantized integer b-grid index. Initialization, donor permutations, mutation/crossover, bound clipping, strict selection and reinitialization remain upstream behavior. These rules differ from the hand-written optimizer in the standalone fast archive; identical discovery sequences are not claimed.

Native history caching, email, slave processes and plots are disabled. The adapter stops at the candidate/budget callback, including within initialization. Other errors propagate. The callback reads native iteration numbering without modifying source. A private working directory isolates upstream temporary files; path, current directory and RNG are restored.

Negative objectives use the highest checked trajectory score. In first_hit, the first candidate in ordered traversal supplies the positive objective/witness; full retains the best-scoring witness while separately retaining the first candidate. Non-candidates use clipped finite K scores; a confirmed candidate scores `1+K*(1-exp(-LLE/0.05))`. All negative Q coverage is required before returning a reusable negative. Completed negatives can be cached within one repetition. Requests, new objective computations and cache hits are reported separately. Cache hits reuse fitness with zero new model/indicator work. There is no cross-repetition cache.

After interruption, the adapter reruns the unchanged native optimizer from the same seed and returns recorded callback scores until the saved proposal sequence is exhausted. b values and generations are checked exactly. Replay does not integrate trajectories; its controller overhead is charged. A pending parameter resumes the next committed Q position. Numerical configuration, resolved backends, grid, optimizer settings, MATLAB version and architecture are fingerprinted. A changed protocol requires a new output directory. Completed runs retain recorded times and counters.

## Measured versus estimated comparison

`full_scan` executes the ascending search and reports paired ratios only when both methods find a candidate. Its first hit is first only for the configured grid, finite horizons and numerical rule.

`estimate` executes DE and grid probes. Prefix-cost extrapolation multiplies measured initial-node mean cost by an assumed stopping index. Regime-cost extrapolation sums regime counts times mean probe cost. The historical default b=1.5069 corresponds to index 5070 on the inclusive grid; it is an assumption, not a newly observed first hit. The flags identify earlier probe candidates and whether the historical target was checked/confirmed. Missing regime probes yield NaN. Deterministic probes do not justify confidence intervals and can miss expensive parameter regions. If DE is censored without a candidate, estimated discovery-cost ratios are NaN.

An early random initialization hit characterizes the full randomized DE procedure, not specifically the benefit of evolutionary updates. Initial-state resolution, backend rounding, horizons and thresholds can alter first hits. Finite survival and candidate flags do not certify invariance, a chaotic attractor or its full basin.

## Timing experiment

Timing uses one common MATLAB orbit at b=1.54 from (0.5,1), generated before measurements. No transient is discarded. All three indicators receive 5000 observations in paper / 1000 in demo. Rosenstein is measured separately at short and long lengths (5000/10000 or 1000/2000). Brute-force neighbors are the default to match the supplied updated timing script. A separately configured native-tree timing audit is available.

One full untimed pass precedes seven fixed-order serial repetitions. The three-indicator total is computed within each repetition. Cached reservoir/carrier setup persists after warmup, as in the optimized source. The two Rosenstein baselines have their own rows and ratios. Jacobian-product FTLE baselines were excluded at user request; the exact Jacobian is used only for SALI.

Search time is accumulated committed parameter-scan time plus controller overhead. Pool creation, downtime and final report/plot generation are outside it. Work lost in an interrupted uncommitted batch is not reconstructed in the timer. Worker-stage seconds sum parallel durations and can exceed elapsed client time. The benchmark of identical 1024-node chunks and the supplied single-orbit timing table are distinct from a full dense-grid search.


## Complete finite-horizon maps

Full mode writes metadata and one compressed record file per committed batch: Cartesian uint32 node IDs, uint8 outcomes, uint32 regular IDs, uint16 periods, uint32 trajectory steps, two double last-state coordinates and four single indicators. This is 47 bytes/node before compression, about 12.83 GB per dense Q/b. Decisions use double; records do not affect the gate. Negative cached evaluations reuse the map path.

Regular matching tests periods 1:32 on at least max(64,8*p) recent observations, with scaled period tolerance 1e-7. Representatives reconstructed in (C,L) are compared up to phase with tolerance 1e-5. These are finite-tail regime labels, not established stable attractors. Chaos status 9 always retains attractor=0; distinct chaotic-attractor identities are unresolved. Confirmation failure status 11 combines exit, nonfinite and safety stops.

Record files are written before their checkpoint commit. A scan UUID and committed start/stop range prevent orphan files from being treated as data. The map reader checks all committed records and plots at most 600×600 actual grid nodes, without label interpolation. A full candidate checkpoint with remaining positions continues scanning. First-hit seconds are retained separately from full-map completion seconds, including across native DE replay.

At first detection, the evaluation checkpoint saves the accumulated search prefix as well as local batch time. The optimizer commits that prefix before entering a pending Q evaluation. Thus replay/controller overhead after a detection does not move the recorded first-hit timestamp.

The standalone Q_MODES code is the source for the shuffle, records and map reader. Its hand-written DE is not imported: this package continues to call unmodified FEX18593. Experiment 2 remains Rosenstein-only, with no changes to its October 24 numerical definitions.
