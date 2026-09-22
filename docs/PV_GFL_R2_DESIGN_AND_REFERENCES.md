# PV-GFL R2 system-level commissioning base

## Accepted artifact

- Model: `build/PV_GFL_864_SystemLevel_SM_R2.slx`
- Builder: `scripts/build_pv_gfl_system_level_sm.m`
- Parameters: `scripts/init_pv_gfl_864_average_sm.m`
- Regression: `scripts/validate_pv_gfl_system_level_sm.m`
- MATLAB target: R2026a
- Commissioning grid: 25 MVA synchronous machine with governor and AVR
- Electrical boundary: 5 MW PV, 6.25 MVA converter, 690 V converter side,
  6.3 MVA 0.69/10 kV transformer, 10 kV PCC

The model is independent of R8/BESS and contains no gate-level PWM.  It is a
system-level GFL base intended to pass strong-grid commissioning before being
connected to the islanded BESS-GFM model.

## Minimal interaction boundary

The PV branch exposes only three logical boundaries:

1. `CommandBus = [P_cmd_W, Q_cmd_var, enable]`;
2. one physical three-phase `PCC_10kV` port;
3. `StatusBus = [t, P, Q, P_cmd, Q_cmd, theta, f, Id_ref, Iq_ref,
   I_limit, phase_error]`.

The standalone commissioning scenario is outside the PV branch in
`02 Commissioning Command Profile`.  It can later be replaced by the AC-side
coordinator without editing the converter plant or PLL.

## Controller/reference mapping

### Teammate `Wind_PV_SOC_DCAC_864.slx`

Retained concepts:

- local voltage synchronization;
- abc/dq-oriented current command;
- independent P and Q commands;
- current-limited GFL behavior;
- converter-local measurements rather than importing the GFM angle.

Not copied numerically:

- the 50/60 kW filter and PI gains;
- the old Specialized Power Systems switching bridge;
- SVPWM and gate pulses;
- mutable base-workspace wiring between unrelated sources.

### VSC_Lib

Used as a controller-structure and interface reference, not a runtime
dependency.  The locally available VSC_Lib audits support the following
choices:

- project-owned command/status ports rather than hidden library constants;
- explicit current-reference limiting before the inner tracking dynamics;
- explicit limiter status for later supervisory coordination;
- controller and physical plant separated at a small, documented boundary;
- no hidden `Control_Lib`/`Source_Lib` dependency in the delivered model.

The currently available local audit is mainly for VSC_Lib GFM current-control
variants.  Its exact GFM outer-loop equations are therefore **not** claimed as
the source of this GFL P/Q law.

### Renewable Energy Integration Design with Simscape

Directly used or checked:

- synchronous-machine, governor and AVR subsystem from
  `BatteryStoragePVPlantGFM.slx`;
- local PLL/controller hierarchy against `PVcontroller.slx`;
- GFL plant/controller separation against `PVInverterGFL.slx`;
- Simscape three-phase sensors, transformer and physical-network solver;
- staged strong-grid commissioning and repeatable regression philosophy.

The copied synchronous-machine subsystem is embedded in the generated model;
the delivered SLX does not use the reference project as a model reference.

## System-level reductions

The converter is a controlled three-phase current injection with a 150 Hz
first-order inner tracking dynamic.  The following EMT details are omitted on
purpose:

- semiconductor switching and PWM carrier;
- gate dead time and switching harmonics;
- explicit voltage-source current-PI modulation saturation;
- transformer leakage inductance in series with an ideal controlled current
  source (this combination creates an invalid current-source/inductor cutset).

The transformer ratio, copper loss, rating, shunt filter dynamics, current
limit, P/Q behavior and local PLL remain explicit.  A later EMT branch may
restore leakage and PWM after the system-level AC collaboration is stable.

## Accepted regression results

| Case | Measured P | Measured Q | Mean frequency | Peak dq current reference |
|---|---:|---:|---:|---:|
| Zero command | -0.0489 MW | 0.0073 Mvar | 49.5867 Hz | 408.8 A |
| 0 to 2 MW | 1.9333 MW | -0.0018 Mvar | 49.5907 Hz | 3108.6 A |
| 2 to 3 MW | 2.9176 MW | -0.0168 Mvar | 49.5348 Hz | 4757.4 A |
| 0 to 1 Mvar at 2 MW | 1.9414 MW | 0.9948 Mvar | 49.5966 Hz | 3300.7 A |

All cases remain below the 1.10 pu current-reference limit.  The active-power
acceptance tolerance is 8%; reactive-power errors are checked independently.

## Next integration rule

Do not connect this branch directly to R8 yet.  The next step is a separate
derived two-source model in which:

- the external coordinator replaces `02 Commissioning Command Profile`;
- the PV branch keeps its local PLL and receives only `CommandBus`;
- R8 remains frozen and is copied into the derived integration artifact;
- the same StatusBus is used for no-coordinator/coordinator comparison.
