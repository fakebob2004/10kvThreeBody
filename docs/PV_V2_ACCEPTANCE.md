# PV-GFL v2 acceptance

`models/resources/pv_resource_standalone.slx` is generated from an empty
model by `builders/assemblies/build_pv_standalone.m`.  The renewable resource
has exactly one typed command input, one typed status output, and one 10 kV
physical PCC port.  The standalone grid is a strong synchronous-machine test
fixture derived from the Renewable Energy Integration with Simscape example;
it is not part of the renewable resource or the later islanded assembly.

The acceptance entry point is:

```matlab
setup_v2_paths
build_pv_standalone
validate_pv_resource_v2
```

The validated result on MATLAB R2026a is:

```text
PV_RESOURCE_V2_ACCEPTANCE_PASS=1
```

Key steady-state results:

| Case | P (MW) | Q (Mvar) | PCC (kV) | f (Hz) | limit factor |
|---|---:|---:|---:|---:|---:|
| zero | -0.039 | 0.007 | 9.616 | 49.718 | 1.000 |
| 0 -> 2 MW | 1.953 | -0.004 | 9.497 | 49.576 | 1.000 |
| 2 -> 3 MW | 2.931 | -0.016 | 9.440 | 49.529 | 1.000 |
| Q -> 1 Mvar | 1.947 | 0.987 | 9.690 | 49.580 | 1.000 |
| 5 MW | 4.870 | -0.012 | 9.455 | 49.702 | 1.000 |
| PF 0.9 | 4.885 | 2.369 | 9.960 | 49.703 | 1.000 |
| circle limit | 4.554 | 5.595 | 10.591 | 49.752 | 0.940 |

At the circle-limit point, the dq reference and measured converter-side peak
currents were 8135.4 A and 8140.0 A.  The current measurement is owned by the
PCS; PCC voltage remains the PLL input, while converter-terminal voltage is
used for P/Q-to-dq feed-forward.

Visual review covered all four generated PNGs.  The resource and AC-interface
levels are readable.  PCS internal routing is functionally correct but remains
visually dense; its line-layout refactor is deliberately deferred and must not
change equations, parameters, or acceptance cases.
