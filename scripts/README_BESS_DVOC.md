# BESS dVOC commissioning branch

Build from the repository root:

```matlab
setup_v2_paths
test_dvoc_controller_parity
build_bess_standalone('dvoc')
run_bess_dvoc_commissioning
```

The new model is `models/resources/bess_resource_dvoc.slx`. The default
`build_bess_standalone()` still selects droop. Existing SLX models are not
used as editable templates and are not overwritten by the dVOC build.

## Replacement boundary

The public resource Command/Status buses and 10 kV physical connection remain
unchanged. Internally dVOC requires a local measurement vector containing
filter-node line-line voltages and current flowing from that node into L2.
Bridge current comes from the existing converter sensor. No BESS/PV/Wind
shared PLL, oscillator angle or DC link is introduced.

The abc adapter uses a nominal rotating frame, phase-peak voltage/current
bases and the resource 6.25 MVA base. The same controller equations are used
as in the frozen research, but the current-loop R/X match the actual BESS
inverter-side filter. The frozen N2 network and BESS network are different.

The initial adapter supports nominal 690 V / 50 Hz commands and mode 1;
unsupported reference values fail explicitly rather than being silently
ignored. P/Q references remain resource-level inputs. Enable disables the
voltage command and freezes the oscillator dq state; it is not an AC breaker.
Enable/re-enable dynamics have not yet been certified.

## Protection and fidelity boundaries

- Native dVOC: 3 pu current-reference circle, 1.4 pu voltage-vector limit,
  virtual admittance 0.2 pu, 500 Hz current tracking, eta=3 and alpha=1.
- Existing BESS common protection remains downstream: 1.2 pu current
  foldback, battery current/SOC interlocks and 1.1 pu phase-voltage bounds.
  These protections can change the waveform compared with native N2.
- The optional external virtual-impedance interface remains available but
  is disabled by default here, to avoid doubling the native virtual
  admittance action.
- The BESS DC source remains an energy/SOC equivalent with fixed 1500 V,
  not a switching bridge or physical DC-link transient model.
- The existing transformer excludes leakage reactance in its block
  configuration. This migration does not change that plant assumption.
- Frequency telemetry is the local oscillator frequency; health is the
  existing status placeholder, not a newly validated fault detector.

`run_bess_dvoc_commissioning` saves data and plots before checking initial
power/voltage/frequency gates. A failed gate is a diagnostic outcome, not
permission to widen tolerances. Passing the 4→5 MW test is not full
fault, SOC-boundary, overload or three-resource certification.
