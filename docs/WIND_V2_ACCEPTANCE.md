# Wind-GFL v2 acceptance

`models/resources/wind_resource_standalone.slx` is generated from an empty
model by `builders/assemblies/build_wind_standalone.m`.  It instantiates the
same reviewed GFL PCS and AC-interface builders used by PV, while retaining
an independent wind source, PCS, filter, transformer, PLL and DC-energy
state.

Run:

```matlab
setup_v2_paths
build_wind_standalone
validate_wind_resource_v2
```

MATLAB R2026a result:

```text
WIND_RESOURCE_V2_ACCEPTANCE_PASS=1
```

| Case | P (MW) | Q (Mvar) | Available / dispatch (MW) | Vdc (V) | limit |
|---|---:|---:|---:|---:|---:|
| zero dispatch | -0.039 | 0.006 | 5 / 0 | 1500 | 1.000 |
| 0 -> 2 MW | 1.939 | -0.003 | 5 / 2 | 1513 | 1.000 |
| wind 2 -> 3 MW | 2.921 | -0.027 | 3 / 5 | 1520 | 1.000 |
| dispatch 2 -> 3 MW | 2.921 | -0.026 | 5 / 3 | 1520 | 1.000 |
| Q -> 1 Mvar | 1.947 | 0.989 | 5 / 2 | 1513 | 1.000 |
| rated 5 MW | 4.867 | -0.016 | 5 / 5 | 1533 | 1.000 |
| available cap | 1.942 | -0.001 | 2 / 4 | 1513 | 1.000 |
| circle limit | 4.564 | 5.600 | 5 / 5 | 1533 | 0.941 |

The DC capacitor integrates `P_MSC - P_PCS`; an availability or dispatch
request is not treated as physical DC power before the MSC ramp.  The source
boundary can later be replaced with turbine, PMSG and machine-side converter
models without changing `ResourceCommandBus`, `ResourceStatusBus`, or the
10 kV PCC port.

All five generated images were reviewed.  The resource and AC-interface
levels are readable.  Source/DC and shared PCS internal routing is dense and
is explicitly deferred for a later line-layout-only refactor.
