# Wind PMSG Transient R3

## Purpose

`Wind_PMSG_Transient_R3.slx` is a derived transient-study model. It leaves the
accepted R2 grid-side plant unchanged and increases machine-side fidelity
without adding the computational cost of a second switching converter.

The organization follows the functional separation used by the local
MathWorks `Renewable Energy Integration with Simscape` reference project:
resource and drive train, generator and machine-side control, DC energy
interface, grid-side control/converter, and grid network are separate model
boundaries. No reference model was copied or overwritten.

## Added dynamics

- Cp(lambda) aerodynamic power with a configurable wind-speed step.
- Two-mass direct-drive shaft with turbine inertia, generator inertia, shaft
  stiffness, shaft damping and twist state.
- Continuous PMSG d/q stator-current states including resistance, inductance,
  electrical speed coupling and permanent-magnet back EMF.
- MPPT torque reference, `id*=0`, generating `iq*<0`, PI current control,
  cross-coupling compensation, back-EMF feedforward and circular voltage limit.
- Averaged MSC electrical power conversion into the existing physical DC link.
- Named logs for shaft speeds/torque, PMSG currents/references, MSC voltage,
  electromagnetic torque, DC power, Vdc and the existing GSC/PCC signals.

## Preserved R2 plant

- Physical 1500 V DC capacitor, precharge and brake path.
- 6.25 MVA two-level GSC with explicit 5 kHz SPWM gate comparison.
- AC filter, 0.69/10 kV transformer, PCC sensing and grid equivalent.
- Existing GFL DC-voltage and dq-current control.

## Acceptance results

The generated model compiled in MATLAB R2026a and passed:

- 20 ms switching operating point: `Vdc=1501.57 V`, `Pmsc=2.7750 MW`,
  q-axis mean current error `0.000605 A`, maximum shaft speed split
  `8.18e-5 rad/s`, binary complementary GSC gates.
- 9.0 to 10.5 m/s wind step at 0.12 s: aerodynamic power increased from
  `3.2993 MW` to `4.5286 MW`; post-step Vdc stayed within
  `1484.42–1500.18 V`; maximum shaft speed split was `0.00216 rad/s`; MSC
  q-axis mean current error was `0.0165 A`.

The short post-step window does not show the full MPPT power rise because the
5 MW rotor inertia intentionally stores the aerodynamic-power mismatch first.
That behavior is the expected purpose of the new two-mass transient model.

## Known boundary

The MSC is an averaged voltage-source converter. The model is suitable for
shaft, electromagnetic, current-loop, DC-link and grid-side EMT studies, but it
does not claim machine-side semiconductor ripple, common-mode voltage, bearing
current or detailed magnetic saturation. The inherited physical grid chain
also issues an initial-condition relaxation warning for its DC capacitor and
filter currents; both acceptance simulations complete and remain bounded.

## Reproduction

Run, with Simulink cache/code-generation folders pointed outside the project:

```matlab
run('scripts/build_wind_pmsg_transient_r3.m')
run('scripts/validate_wind_pmsg_transient_r3.m')
run('scripts/validate_wind_pmsg_transient_r3_step.m')
```

