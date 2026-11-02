# Physical PV + transient Wind: grid-supported integration

## Current Wind R4 frequency-step regression

The current builder imports Wind R4 with its native PCC PLL driving both
grid-side dq transforms. At 0.7 s the imposed grid frequency changes from
50 to 50.2 Hz. Over 1.15–1.25 s the independent bus-voltage measurement
gave 50.1999994 Hz, the Wind PLL gave 50.1999971 Hz and the slope of the
actual control angle gave 50.1999994 Hz. In the current controller frame,
the PCC voltage angle averaged 0.0471 degrees. Wind DC voltage averaged
1500.71 V. Run `validate_grid_supported_postsettling_dynamics({'frequency_step'})`
to reproduce this strong-grid case. Joint cold-start acceptance remains open.
R4 uses an assumed 2% rated copper loss. Available power estimates MSC output
at the current shaft speed, before grid-side losses.

## Current Wind dispatch and standby

Run `validate_wind_dispatch_cycle('GRID_SUPPORTED_PV_WIND_R1')` on the
generated joint plant. The voltage-aligned q-current request passes through
the same circular current limiter as the active request. A 20 ms filter
smooths reactive dispatch. Enable controls generation and reactive dispatch
while the grid-side converter maintains the DC link and synchronization.

| Joint test window | PCC P (MW) | PCC Q (Mvar) |
|---|---:|---:|
| +1 Mvar | 3.102 | +0.9996 |
| -1 Mvar | 3.099 | -0.9989 |
| Generation disabled | -0.0066 | -0.0007 |
| Generation resumed | 2.973 | -0.9995 |

From 0.25 through 1.50 s the Wind DC link spanned 1477.0–1524.7 V and
its PLL spanned 49.921–50.091 Hz. Available power and incremental headroom
use the MSC DC boundary. Standby reports zero dispatchable headroom.
PCC reserve under simultaneous converter current limitation needs separate
qualification before enabling a capability coordinator.

On the switching model, `validate_wind_step_energy` gave a 0.00123%
integrated energy residual from wind input to MSC over 0.11–0.22 s.
After accounting for DC capacitor energy, the DC-to-PCC gap was 2.20%.

Run `diagnose_wind_start_targets` to compare the first 3 ms of the joint
model. The baseline starts Wind/PV near 903/750 V. Targeting Wind's
internal capacitor state yields 1503/1500 V but the bus peak reaches
787 kV. Including the specified transformer leakage in that case raises
the peak to 1.64 MV. Releasing the Wind filter-current target gives the
same peaks. These variants are diagnostic only. Cold-start acceptance
requires the raw AC peak and both initial DC voltages to pass together.

## Historical R3 commissioning record

This work is on `integration/grid-supported-pv-wind`. It merges PV commit
`ca7a100` from `origin/feat/pv-physical-dc-r2024b` and consumes the locally
supplied Wind R3 functional modules. The original R3 source files and model
are not edited. Existing islanded baselines are not regenerated or overwritten.

## Explicit scope

- A 100 MVA simplified synchronous machine stays physically connected to
  the common 10 kV network throughout commissioning.
- Its mechanical speed is imposed by an ideal governor. It balances power,
  but this harness is **not** a validation of finite-inertia governor/AVR
  dynamics or autonomous frequency response.
- PV retains the new physical array/Boost/DC capacitor/average VSC and local
  DC-voltage/current controllers supplied by the PV branch.
- Wind retains R3's two-mass shaft, continuous dq PMSG, MSC current control,
  physical DC capacitor, precharge, brake and grid-side current controller.
  The GSC uses the already available average-duty interface rather than SPWM.
- The supplied R3 control angle came from `Nominal Grid Angle`. Its PLL was
  diagnostic. The integration adapter explicitly selects the **local PCC PLL**
  with the alignment already used in the accepted average Wind R2 path.
- Wind's inherited global Goto/From tags are namespaced and scoped inside
  the Wind resource. No PV/Wind shared angle, PLL or DC link is introduced.
- A resource-level P command caps the MPPT torque request. Aerodynamic and
  rotor energy dynamics remain active; a P command is not instantaneous power.
- Wind Q is explicitly restricted to zero in this first adapter and rejected
  by an assertion otherwise. It must not be presented as a fully commissioned
  general-purpose Wind P/Q API. Wind disable/re-enable is not certified.
- The coordinator remains off. A replacement BESS has not been supplied;
  the existing GFM is not paralleled without synchronization commissioning.
- There is no grid-disconnection event or islanding test.

## Relative entry points

```matlab
setup_v2_paths
run_grid_supported_component_checks

build_grid_supported_integration({'Wind'})
build_grid_supported_integration({'PV','Wind'})
validate_grid_supported_integration
audit_grid_supported_integration
```

`validate_grid_supported_integration` is the **cold-start-inclusive** gate.
The joint cold-start gate currently fails and must not be advertised as passed.
To test control interactions after initial transients while retaining the
complete startup trace, run the separately labelled conditional suite:

```matlab
validate_grid_supported_postsettling_dynamics
collect_grid_supported_evidence
```

Each conditional case runs from 0 to 1.25 s, checks the pre-event DC/bus
operating point, applies its disturbance at 0.7 s, and evaluates dynamics from
0.5 s. Full raw traces, including startup, are saved. Its JSON explicitly has
`cold_start_accepted=false` and `islanding_tested=false`. It is not a workaround
that makes the cold-start gate green. Complete-operating-point restoration was
also checked; a checksum mismatch was rejected rather than disabling validation.

The component runner preserves each stage's pass/error/metrics and can resume:

```matlab
run_grid_supported_component_checks({'wind_operating_point','wind_step'})
validate_grid_supported_integration({'pv_dispatch'})
```

New source files:

```text
parameters/init_grid_supported_integration.m
builders/resource_builders/build_wind_r3_grid_adapter.m
builders/assemblies/build_grid_supported_integration.m
scripts/run_grid_supported_component_checks.m
tests/validate_grid_supported_integration.m
```

Generated models are under `models/integration/`. Detailed logs, JSON, MAT
waveforms and figures are under `artifacts/grid_supported_integration/`.
Generated evidence is kept out of ordinary source commits.

## Verification sequence

1. Supplied PV: physical dispatch and DC charge balance, MPPT, current limit.
2. Supplied Wind R3: switching operating point and wind-speed step.
3. Adapted Wind + synchronous machine: startup and local-PLL operation.
4. Physical PV + adapted Wind + synchronous machine: startup.
5. PV dispatch step: synchronous-machine power compensates PV increase,
   while Wind remains close to its own operating point.
6. Wind-speed step: aerodynamic input changes; rotor/shaft dynamics are retained.
7. PV Q step: reactive transfer and common-bus voltage remain bounded.
8. Synchronous-machine frequency step: independently measured bus frequency
   and both local PLLs follow, demonstrating no fixed nominal-angle shortcut.

The integration runner stops at the first failed stage and saves the failure.
Passing standalone tests does not mark subsequent integration stages passed.
Existing tolerances in teammate standalone tests are not widened.

The first common-grid build exposed a nonphysical raw startup voltage of
`5.220153e8 V` at t=0, despite normal tail values. A 3 ms controlled comparison
showed that initializing the synchronous machine at the connected load
(`Pt0=5 MW`, `Qt0=1.5 Mvar`) reduced the raw maximum to `10.1083 kV`.
Changing only to a variable-step solver did not remove the spike. This is an
initial-operating-point correction, not a controller-gain change. The current
integration tests include a raw-voltage-maximum gate; they do not average away
that initial sample. Source capacitor/current initial-condition relaxation
is still explicitly recorded and is not certified as a bumpless cold start.

In the joint direct-connected model the raw first-sample maximum is still
`25.7962 kV`, with initial PV/Wind DC voltages approximately `750/902 V`
instead of their requested 1500 V. A 3 ms resource-isolation comparison found
that the supplied native PV harness starts at 1500 V DC (PCC peak 11.9745 kV),
whereas PV with the common 5 MW/1.5 Mvar load alone retains 1500 V DC but has
a first-solve PCC spike. This separates source commissioning from whole-network
initialization: it does not establish that either resource controller is
unstable. An attempted delayed-breaker startup failed its dynamic constraints
and was not retained in the generator. Both resources are directly connected
in the current conditional dynamic harness; the synchronous machine never opens.

The generated models are intentionally not committed as accepted replacements.
The small, scoped numerical evidence is in `docs/evidence/grid_supported/results.json`;
large full traces and cache files remain under ignored artifacts/temp folders.

## Verified result summary

Runtime: MATLAB R2026a Update 4. The supplied PV dispatch/MPPT/current-limit
checks and the supplied Wind R3 operating-point/wind-step checks passed.
The namespaced adapter source/interface audit also passed; the original Wind
R3 SLX, initializer and generator retain their original SHA-256 values.

The following results apply **only to the explicitly labelled post-settling
grid-supported tests**, with the machine continuously connected:

| Case | Result |
|---|---|
| Joint steady state | PV 2.0216 MW, Wind 2.7098 MW, machine 0.2690 MW; bus 9.9524 kV |
| PV dispatch 2 to 3 MW | PV 2.9921 MW; machine power decreases by 0.9571 MW; Wind remains about 2.71 MW |
| Wind 9 to 10.5 m/s | Aerodynamic power 3.2992 to 4.6274 MW; electrical output 2.8612 MW at the tail, with inertia retaining part of the mismatch |
| PV Q 0 to 1 Mvar | PV Q 1.0018 Mvar; machine Q about 0.4980 Mvar; bus 9.9841 kV |
| Grid frequency 50 to 50.2 Hz | Measured bus 50.199998 Hz; PV PLL 50.196247 Hz; Wind PLL 50.199996 Hz |

PV DC capacitor charge residuals over the dynamic window range from 0.1377
to 0.3932 C, rechecked using the actual Boost-output and VSC DC-current sensors.
The nominal-load active-power residual is approximately 0.30 kW in the steady
and PV-dispatch cases and about -18.54 kW in the frequency event. The latter is
reported as a **nominal-load/measurement residual**, not as negative physical
loss or a measurement of all storage-energy derivatives.

The fixed-speed machine absorbs power when renewable generation exceeds the
5 MW load (about -0.702 MW after the PV increase). This is intentional strong-grid
balancing; it is not proof that a real prime mover can absorb arbitrary power,
nor that the future islanded system can operate without BESS charge headroom.

The unfiltered 0-to-1 Mvar PV Q command also causes a brief PV PLL frequency
estimate excursion of 49.0129--50.2579 Hz (Wind estimator 49.9026--50.0020 Hz)
before relocking. This is explicitly retained in the numerical evidence, not
averaged out. It is not a claim that the imposed machine shaft speed falls to
49 Hz. Command slew limiting and local synchronization sensitivity need review
before weak-grid/island commissioning. Passing the present final-tracking gates
does not certify an optimized transient PLL response.

### Not accepted

Joint cold start is **not accepted**: the full traces retain the 25.7962 kV
first-sample bus excursion and relaxed DC initial values. The delayed-breaker
alternative also failed and was removed. BESS, coordination algorithms,
islanding, weak-grid and fault acceptance are not part of this result.

## Remaining engineering work

Wind's available-power status currently reports captured aerodynamic power,
not a fully calibrated deliverable electrical reserve; do not enable a
capability coordinator on it without accounting for conversion and rotor energy.
The supplied Wind transformer excludes leakage reactance, and the PV branch
inherits its own filter/transformer assumptions. These are recorded plant
boundaries, not hidden retuning in this integration.

Next steps after grid-supported commissioning are Wind API completion and
the upgraded BESS's own grid-parallel synchronization/current-control tests.
Only after those should the three-resource system be considered for islanding.
