# Verification of the Q-mode release — 26 October 2026

MATLAB R2024a, macOS Apple Silicon; optional kernels rebuilt with Xcode Clang++. **The dense 273034001-node Q experiment was not run.** Maps and timing below concern explicit small grids, not an extrapolated full experiment.

## Automated checks

All **20 tests** passed with compiled kernels available. A clean source-only copy passed **18 tests**, skipped the two optional native-only tests and reported zero failures.

Inherited checks cover native FEX18593 invocation and byte-for-byte integrity of its 38 source files; initialization/generation budgets; cached versus uncached proposals and fitness; completed and interrupted native DE replay; complete negative scans and censored estimates; FFT/native agreement; ConDN/RNG preservation; SALI normalization; exact tree indices with ties; and Rosenstein-only timing.

New checks cover:

- Complete shuffle coverage for N=1,2,3,4,37,308,1025,10000; first 100000 dense-Q indices without repeats; seed reproducibility/change and preservation of the optimizer RNG.
- Adaptive first batches and the first witness in traversal order, with distinct phase position and Cartesian ID.
- Full records for all 308 coarse nodes, with no duplicates or provisional survivor status; single-precision stored indicators and uint32 step/ID fields.
- Zero deferred screens in full mode; chaos status 9 always with attractor=0; regular labels assigned only to numerically matched tails.
- Read-only maps, ignored orphan files, completed checkpoint reuse and a coherent interrupted full prefix that already contains a candidate but still resumes to all nodes.
- Separate first-hit and total DE times, preserved first-hit time after replay of a committed Q evaluation, and changed-order resume rejection.
- Per-node integration details in MATLAB/native and the updated seven-output MEX ABI. Rebuilding an already loaded client kernel was also checked.

The integration script checked both timing profiles, real and estimated b-grid comparison paths, serial/parallel agreement, Threads and Processes with two workers, and native full maps with the complete paper horizons. Static analysis was applied to the changed numerical routines. Source-only execution requires no compiler or PCT for the serial unit suite.

## Single-b Q-mode checks

Settings: lambda=3.01, sigma=1.03, beta=0.99, b_L=1.54; Q=[0,1.3]×[0,2.1], **explicit 14×22=308 nodes, step 0.1**. Paper horizons: 1000 transient + 4000 retained, 32 c values, 10000-point Rosenstein; diagnostics enabled; native integrator/FFT/tree. Chunk=32, max batch=64; first-hit initial batch=16. These are software checks, not default dense settings.

| Run | Integrated nodes | Confirmed candidates checked | First positive batch, s | Full selected work, s |
| --- | ---: | ---: | ---: | ---: |
| first_hit, serial | 16 | 2 | 0.100930 | 0.106256 |
| full, serial | 308 | 108 | 0.535238 | 3.826356 |
| full, two Processes workers | 308 | 108 | 0.297328 | 2.275777 |

All node status counts matched between the serial and parallel native full scans. First-hit candidate counts include additional already launched chunks, not just the retained first witness. Timing ratios from this coarse grid cannot be transferred to the dense Q.

[First-hit summary](../example_results/release_20261026/q_first_hit/summary.csv) · [Serial full summary](../example_results/release_20261026/q_full_serial/summary.csv) · [Parallel full summary](../example_results/release_20261026/q_full_processes/summary.csv) · [Map](../example_results/release_20261026/q_full_processes/evaluation_basin/phase_map.png).

The small map is bundled with its metadata, batch records and evaluation checkpoint for read-only inspection:

```matlab
preview = olg_plot_phase_map(fullfile(pwd,'example_results','release_20261026', ...
    'q_full_processes','evaluation_basin'), false);
```

The map describes finite-horizon outcomes; no multiple chaotic candidates are merged into a claimed single attractor. The only established exact fixed state singled out analytically is the initial origin.

## DE, grid comparisons and timing

Real comparison checks used demo horizons, Q=[0.49,0.51]×[0.99,1.01] with 3×3 nodes, b_L in [1.53,1.55], two repetitions and two workers. DE found a candidate in 1 and 2 initialization requests; the actual ascending scan used 67 requests in each repetition. These deliberately narrowed positive controls validate execution and reporting, not a general DE or evolutionary-update advantage.

[Measured comparison](../example_results/release_20261026/measured_threads/summary.csv) · [Native DE / grid estimate](../example_results/release_20261026/estimated_processes/estimated_grid_cost.csv).

Both indicator timing profiles completed with the unchanged six-row Rosenstein-only protocol. Paper values still match the supplied optimized table: K=0.99770858049343, ConDN delta=6.62848182382396, Rosenstein short=0.11030543193461, long=0.110704397046645. Times are retained as new measurements, separately from the supplied October 24 table.

[Current paper timing](../example_results/release_20261026/timing_paper/summary.csv) · [Supplied timing](../example_results/optimized_timing_supplied_20261024/timing_summary.csv) · [Historical October 24 report](VALIDATION_20261024.md).

## Reproduction and provenance

```matlab
build_olg_fast
results = run_tests;
addpath(fullfile(pwd,'tests'));
verify_release;          % Explicit small grids, including paper-horizon maps.
export_example_results; % Saved results only, no new trajectories.
```

The Q-mode source instructions, verification and cost analysis are preserved as [source README](SOURCE_20261026_README_Q_MODES.txt), [source verification](SOURCE_20261026_VERIFICATION_Q_MODES.txt) and [source analysis](SOURCE_20261026_ANALYSIS_Q_MODES.txt). Their hand-written DE is not imported; this package retains FEX18593. Input hashes are in [UPGRADE_SOURCE_HASHES_20261026.json](UPGRADE_SOURCE_HASHES_20261026.json). Previous supplied kernel/timing measurements remain historical inputs and do not establish full dense-search speedups.
