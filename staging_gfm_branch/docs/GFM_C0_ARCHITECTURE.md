# GFM C0 control branch

The GFM branch is independent of the original GFL B0/B1 generated assets:

```text
build_gfm_plant_c0_model.m -> GFM_BESS_Plant_C0.slx
                                      |
                                      `-> build_gfm_c0_model.m
                                               |
                                               `-> GFM_Inverter_C0.slx
```

`build_gfm_plant_c0_model.m` began as a copy of the readable B0 builder, then
diverged only where the BESS-GFM power stage requires different ratings,
measurements, and switching-device settings.  Neither GFM build script loads,
modifies, or regenerates `GFL_Inverter_B0.slx` or `GFL_Inverter_B1.slx`.

## Engineering base

- BESS active power: 5 MW
- BESS energy: 10 MWh
- PCS: 6.25 MVA
- DC link: 1500 V
- nominal battery metadata: 1200 V, 8333.3 Ah, SOC initial 55%
- converter AC: 690 V line-line
- transformer: 6.3 MVA, 0.69/10 kV
- converter current limit: 1.20 pu
- switching frequency: 5 kHz

The C0 plant still uses an ideal DC voltage source. The 10 MWh battery
and bidirectional DC/DC are ratings and controller-design metadata in C0, not yet
a physical battery plant.

## Branch-local switching interface

- six Simulink-PS gate converters use unit `V`;
- PWM high level is 1 V;
- ideal-switch threshold is `Converter.GateThreshold_V = 0.5 V`;
- the detailed bridge uses a no-dynamics antiparallel protection diode;
- converter-terminal `Vabc_inv`, `Vll_inv`, and `Iabc_sw` are measured before
  the RL filter.

These settings live only in the GFM branch. The original GFL B0/B1 switch
definition remains outside the dependency chain.

## Readable controller hierarchy

```text
GFM Controller
|-- 01 Measurements and Power
|   |-- abc -> alpha-beta
|   |-- instantaneous P/Q
|   `-- 20 Hz power filters and PCC peak current
|-- 02 P-f Droop and Angle
|   |-- P reference - measured P
|   |-- 0.5 Hz / 5 MW droop
|   `-- limited omega -> internal angle (no PLL)
|-- 03 Q-V Droop and Magnitude
|   |-- Q reference - measured Q
|   `-- voltage magnitude command with 0.90-1.10 pu limits
|-- 04 Voltage Reference and Limits
|   |-- internal angle -> three-phase unit vectors
|   |-- Vll/Vdc normalization
|   |-- one-control-period measurement delay
|   `-- current foldback and +/-0.95 modulation limit
`-- 05 Carrier PWM
    `-- explicit complementary [GaH GaL GbH GbL GcH GcL]
```

There are no MATLAB Function blocks and no PLL. The two one-period delays are
intentional digital-control boundaries that remove the switching algebraic loop.

## Validation status

Passed:

- diagram update;
- required control hierarchy;
- no MATLAB Function blocks;
- 5 ms detailed-switching simulation;
- binary and complementary six-gate outputs;
- 1 V isolated-grid source test produces a 1500 V converter line-voltage PWM
  level and 14.06 A peak switching current;
- converter fundamental line voltage is 688.7 V RMS;
- PCC fundamental phase voltage is 5.743 kV RMS, consistent with a 10 kV bus;
- 40 ms numerical execution;
- frequency, DC-link, and modulation limits.

Open control-commissioning issue:

- the gate-threshold root cause is closed and is no longer inherited from B1;
- the 40 ms stiff-grid operating test currently gives 0.082 MW and
  -0.0124 Mvar, with 10.31 A peak PCC current;
- `run_gfm_c0_operating_point` reports `PowerTransferValidated = false`.

Do not claim 5 MW closed-loop power operation yet. The next task is limited to
GFM control commissioning: verify P/Q sign conventions and the internal-angle
to physical-voltage phase mapping, then add controlled synchronization/startup.

## Commands

```matlab
run(fullfile('Scripts','build_gfm_plant_c0_model.m'))
run(fullfile('Scripts','build_gfm_c0_model.m'))
run_gfm_c0_checks
run_gfm_c0_active_switch_test
run_gfm_c0_operating_point
```
