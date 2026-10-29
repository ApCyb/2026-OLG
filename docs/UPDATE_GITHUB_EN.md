# Update the existing GitHub repository

Target: https://github.com/ApCyb/olg-chaos-experiments. Release date: 26 October 2026.

The GitHub connection returned 404 during preparation, so the current remote branch and file layout could not be verified. These steps use `origin/HEAD` and require your own access to the repository. [GitHub's clone/fetch documentation](https://docs.github.com/en/get-started/using-git/getting-changes-from-a-remote-repository) explains remote access.

1. Extract `OLG_EXPERIMENTS_FEX18593_GITHUB_2026-10-26.zip`. Clone the repository if necessary, or enter its existing local clone. Use a clean working tree; commit your existing work before switching branches.

```bash
git clone https://github.com/ApCyb/olg-chaos-experiments.git
cd olg-chaos-experiments
git status --short
git fetch origin
git remote set-head origin --auto
git switch --create update-q-modes-2026-10-26 origin/HEAD
```

2. Inspect `git ls-tree --name-only HEAD`. If the code is at repository root, copy the **contents** of the extracted folder there. If code currently resides in a subfolder, use that location instead. Adjust the source path below:

```bash
rsync -av \
  --exclude='results/' \
  --exclude='.git/' \
  --exclude='*.mex*' \
  --exclude='.gitignore' \
  "../olg_experiments_fex18593/" ./
```

Do not add an extra wrapper folder around existing code. This command does not delete extra repository files. Preserve `.github`, existing project licenses and citation metadata. Merge the package's ignore patterns into the existing `.gitignore`, particularly `results/`, `*.mex*`, `*.asv`, `*.m~` and `.DS_Store`. Keep `example_results/` and both third-party license directories.

3. Finish existing calculations first. Close the old pool and rebuild the changed integrator ABI. From the updated code root in MATLAB (the license guard also supports installations without Parallel Computing Toolbox):

```matlab
if license('test','Distrib_Computing_Toolbox')
    p = gcp('nocreate'); if ~isempty(p), delete(p); end
end
clear functions
clear mex
addpath(pwd, '-begin');
which olg_config -all
build_olg_fast
results = run_tests;
addpath(fullfile(pwd,'tests'));
verify_release;
```

Native checks require a compiler; without built kernels, native unit tests are skipped and `verify_release` is unavailable. The integration script uses explicit small grids, not the dense default Q. Create fresh schema-4 configurations and output directories; old checkpoints are incompatible. Select the Q mode with `olg_config(...,'first_hit'/'full')`; separately check `cfg.search.gridMode`: the default is an estimate, while `'full_scan'` performs the actual ascending search. Full mode writes about 12.83 GB of raw records per dense Q/b value. Keep runtime batch maps and checkpoints out of Git; small `example_results/release_20261026` fixtures are intentional. Read-only access to standalone Q_MODES maps is supported; resuming old checkpoints is not.

4. Review and commit:

```bash
git status --short
git diff --stat
git diff --check
git add -A
git diff --cached --stat
git diff --cached --check
git diff --cached --name-only
git commit -m "Add Q scan modes, shuffle traversal and saved outcome maps"
git push -u origin update-q-modes-2026-10-26
```

Before committing, verify that generated `results/`, native binaries and private files are not staged. Ignore patterns do not remove files that were already tracked. Keep the supplied benchmark tables separate from fresh unified-package verification results.

5. Create a Pull Request from this branch to the repository's actual default branch. Describe explicit Q modes, shuffle traversal, adaptive initial batches, per-node records/maps, separate first-candidate timing, resumable FEX DE, request/cache-miss counts, estimated versus measured grid comparisons, Rosenstein-only timing baselines, documentation and small-grid validation. Review and merge normally. Optionally create a `v2026.10.26` release and attach the ZIP and SHA-256; a release asset is preferable to committing the ZIP into the source tree.

[GitHub: adding files and pushing changes](https://docs.github.com/en/repositories/working-with-files/managing-files/adding-a-file-to-a-repository).
