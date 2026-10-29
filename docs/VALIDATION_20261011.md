# Verification of the File Exchange DE variant

Verified on 11 October 2026 with MATLAB R2024a (`24.1.0.2537033`, MACA64). The comparison below used 10 thread workers (10 physical cores, including 8 performance cores). The DE backend is Markus Buehren's File Exchange 18593, version 1.16.0. No results from the earlier hand-written DE are reused.

**The default Q grid has 273,034,001 states per parameter. Its full search was not run.** The verification search explicitly overrides Q resolution to 14 × 22 = 308 states. It retains the requested Q rectangle, the full 6000-node b_L grid, and the complete traversal of Q at every visited parameter. The reported speed ratios apply only to this coarse verification case.

## Completed checks

Fourteen automated tests cover:

- Requested profiles, parameter-grid endpoints and the dense grid's exact shape, endpoints and index transitions.
- Bounded-memory block reconstruction and complete traversal after a candidate, including the final partial block; aggregate counts are independent of block size.
- Actual invocation of the bundled `differentialevolution` engine, initialization and generation numbering, and exact budgets, including a budget of one and a stop partway through a generation.
- Reproducible DE traces with the same seed; restoration of MATLAB path, current directory and global RNG; propagation of evaluator errors.
- Byte-for-byte SHA-256 integrity of all 38 upstream files.
- Orbit extension, exits, transient indexing, gates, regular controls, the known OLG candidate, and shared timing/search indicator kernels.

Serial and thread-pool evaluations agreed numerically for both the default gate and the optional combination of 0–1, SALI and ConDN. Both indicator timing profiles completed. The known state `(C_0,L_0)=(0.5,1)` at `b_L=1.54` passed the paper detector with short-series K = 0.997332551, Rosenstein estimate = 0.110704397 per iteration and fit R² = 0.998423030, using the full 10000-step horizon.

## Coarse search verification

Configuration: Q = [0,1.3] × [0,2.1], explicit `stateGridSize=[14 22]` (step 0.1); b_L in (1,1.6] with step 0.0001; cheap horizon 1000, transient 100, Rosenstein horizon 2000; only the 0–1 gate; population 20, native strategy 7, F=0.8, CR=1, seed 20261011. All 308 states were evaluated for every visited b_L. Timing and parallel checks ran before this search in the same MATLAB process.

| Method | Evaluations to candidate | Candidate b_L | Seconds to detection | Total search seconds | Model steps | Rosenstein calls |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| File Exchange DE | 35 | 1.5130 | 3.1559 | 3.2887 | 3,226,905 | 107 |
| Ascending grid | 5072 | 1.5072 | 187.0826 | 187.1522 | 522,384,731 | 1 |

In this pair, the grid/DE ratios were **144.91** for parameter evaluations, **59.28** for detection time and **56.91** for total search time. DE's candidate occurred in its first evolutionary generation after the 20 initialization evaluations. All Q blocks were completed before stopping the parameter search. With 308 states and batch size 1024, the verification case uses one block per parameter; the multi-block stopping/counting behavior is checked separately by automated tests.

This is one paired run, not a confidence interval or proof of a general DE advantage. The grid's candidate is first only relative to this finite grid and detector. The dense initial-state grid can change both detected candidate parameters and runtimes. No quantitative speed claim for the dense grid is inferred from these measurements.

[Summary](../example_results/demo_search/summary.csv) · [DE ledger](../example_results/demo_search/de_rep001.csv) · [DE backend settings](../example_results/demo_search/de_rep001_backend.json) · [Grid ledger](../example_results/demo_search/full_scan_rep001.csv) · [Configuration](../example_results/demo_search/configuration.json) · [Figure](../example_results/demo_search/comparison.png)

## Indicator timing

Fixed b_L=1.54, initial state (0.5,1); no discarded transient. The table reports medians of seven serial repetitions after one warmup. Common orbit generation is excluded. The total is the median of within-repetition sums.

| Indicator | Demo seconds | Paper seconds |
| --- | ---: | ---: |
| 0–1 test | 0.007395 | 0.286225 |
| SALI | 0.000847 | 0.003794 |
| ConDN | 0.013215 | 0.038399 |
| Rosenstein LLE | 0.014950 | 0.314279 |
| Three preliminary indicators total | 0.021365 | 0.328331 |

The combined preliminary-indicator time exceeded Rosenstein time in both profiles. Each individual indicator was faster than Rosenstein in these median measurements. Search defaults to only the 0–1 gate. The timing results depend on implementation, machine and MATLAB state.

[Demo summary](../example_results/demo_indicators/summary.csv) · [Paper summary](../example_results/paper_indicators/summary.csv) · [Paper timing repetitions](../example_results/paper_indicators/timing_repetitions.csv) · [Paper figure](../example_results/paper_indicators/comparison.png)

## Reproduction

From the package root:

```matlab
results = run_tests;
addpath(fullfile(pwd,'tests'));
verify_release;          % Both timing profiles and explicitly coarse Q search.
export_example_results; % Reads completed runs; no new model evaluations.
```

The ordinary test suite does not scan the complete b_L grid. `verify_release` explicitly uses the coarse grid described above. The main configuration retains the requested dense Q grid in both profiles. Exported CSV files, configurations, backend metadata, witness paths, Rosenstein fits and figures are bundled under `example_results/`.
