# GFM C0 control branch

`GFM_Inverter_C0.slx` is derived from the frozen `GFL_Inverter_B1.slx` plant.
It does not recreate the VSC, transformer, grid interface, or PCC measurement.
Only the controller and its deliberate measurement interface are added.

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

The inherited B1 plant still uses an ideal DC voltage source. The 10 MWh battery
and bidirectional DC/DC are ratings and controller-design metadata in C0, not yet
a physical battery plant.

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
- 40 ms numerical execution;
- frequency, DC-link, and modulation limits.

Open issue inherited from B1:

- B1 produces only approximately 0.65 mA even when the grid-source phase is
  forced 10 degrees away from the inverter;
- C0 therefore also produces negligible PCC power although its internal angle,
  690 V voltage command, and PWM are active;
- `run_gfm_c0_operating_point` reports `PowerTransferValidated = false`.

Do not claim 5 MW closed-loop power operation until the inherited AC physical
chain is corrected and the phase-step test produces the expected current.

## Commands

```matlab
run(fullfile('Scripts','build_gfm_c0_model.m'))
run_gfm_c0_checks
run_gfm_c0_operating_point
```
