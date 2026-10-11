# Third-party software

## Differential Evolution — Markus Buehren

The directory [`vendor/fex18593/`](vendor/fex18593/) contains all 38 files from Markus Buehren's **Differential Evolution**, MATLAB Central File Exchange submission **18593**, **version 1.16.0**, released **13 November 2019**.

- [Submission page](https://www.mathworks.com/matlabcentral/fileexchange/18593-differential-evolution)
- [Official versioned archive](https://addons.mathworks.com/downloads/e5/e5572284-4a80-11e4-9553-005056977bd0/1.16.0/differential_evolution-1.16.0.zip)
- [Upstream license](vendor/fex18593/license.txt), copyright (c) 2019, Markus Buehren, All rights reserved.
- [Provenance and individual SHA-256 hashes](vendor/fex18593_manifest.json)

The upstream source files and license are included **without modifications**. The OLG adapter is [`+olg/fex_de.m`](+olg/fex_de.m); it calls `differentialevolution`, which calls the bundled `computenewpopulation`. The adapter controls objective evaluation, the evaluation budget, stopping, and isolation of temporary files and random state. It does not implement mutation, recombination, population initialization, or selection.

Archive SHA-256:

```text
f7db38622a50982724f20d0af35ad63ad9d740da302561e401c3691859614f80
```

Retain the upstream copyright notice, license conditions, and disclaimer when redistributing this package. No affiliation with or endorsement by the upstream author is implied.

## OLG package license status

No distribution license has yet been selected for the OLG-specific code and documentation. The third-party license above applies to its upstream files; it does not license the rest of this package. Select a license for the OLG-specific work before public release.

The indicator implementations remain the local implementations described in [References](docs/REFERENCES.md). This change replaces the DE implementation only.
