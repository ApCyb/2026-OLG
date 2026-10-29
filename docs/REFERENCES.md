# References and implementation provenance

Differential evolution uses Markus Buehren’s [MATLAB Central File Exchange submission 18593](https://www.mathworks.com/matlabcentral/fileexchange/18593-differential-evolution), version 1.16.0 (13 November 2019). The exact upstream source and license are bundled; see [Third-party notices](../THIRD_PARTY_NOTICES.md).

The chaos indicators use the implementations described below; the original mirwais Rosenstein submission and license are now preserved as reference under `vendor/rosenstein`.

* G. A. Gottwald and I. Melbourne, “On the Implementation of the 0–1 Test for Chaos,” SIAM Journal on Applied Dynamical Systems 8, 129–145 (2009). [Author preprint](https://arxiv.org/abs/0906.1418).
* M. T. Rosenstein, J. J. Collins and C. J. De Luca, “A practical method for calculating largest Lyapunov exponents from small data sets,” Physica D 65, 117–134 (1993). [Publisher](https://doi.org/10.1016/0167-2789%2893%2990009-P), [paper at PhysioNet](https://physionet.org/files/lyapunov/1.0.0/RosensteinM93.pdf).
* C. Skokos and T. Manos, “The Smaller (SALI) and the Generalized (GALI) Alignment Indices: Efficient Methods of Chaos Detection.” [Author preprint](https://arxiv.org/abs/1412.7401).
* A. R. Ismail, S. Jovanovic, S. Petit-Watelot and H. Rabah, “Detection of Chaos Using Reservoir Computing Approach,” IEEE Access 10, 52686–52699 (2022). [Publisher](https://doi.org/10.1109/ACCESS.2022.3174960), [author repository](https://hal.science/hal-03981818v1). The implemented ConDN diagnostic is the explicitly documented trace-difference variant, not a fitted classifier from that paper.

The model and fixed parameter values follow the supplied OLG manuscript. No unpublished manuscript or private PDF is redistributed in this package. The included tests and example outputs identify the exact configuration used for verification.
