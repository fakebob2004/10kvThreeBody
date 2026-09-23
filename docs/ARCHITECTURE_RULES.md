# Architecture rules for the maintainable three-resource model

This document is normative for the v2 builders. The v2 source of truth is MATLAB builder code and parameter data; an `.slx` file under `models/` is a generated canonical artifact, not a template to be copied and patched.

## 1. Evidence from the validated baselines

The migration preserves the behavior already demonstrated by these immutable baselines:

| Baseline | Preserved behavior |
|---|---|
| BESS-GFM R8 | 5 MW / 10 MWh battery, 1500 V DC link, GFM P-f and Q-V behavior, bidirectional power, DC/AC current limits, SOC direction interlock |
| PV-GFL R2.1 | local PCC PLL, P/Q-to-dq reference, converter-enable semantics, circular current limit, 5 MW / 6.25 MVA at 690 V / 10 kV |
| Wind-GFL R1 | PV-compatible GFL grid-side behavior plus independent available-power, dispatch, mechanical-response and DC-energy states |
| Stage 1 | BESS-GFM and PV-GFL exchange power only through the common 10 kV network |
| Stage 2 R1 | PV and Wind steps are naturally balanced by the bidirectional BESS; no shared PLL, angle or DC link |

The frozen artifacts and hashes remain migration oracles. They are never inputs to a v2 builder.

## 2. Lessons retained from the reference projects

### Renewable Energy Integration with Simscape

- A resource owns its source, converter and local controller; plant-level models connect resources by physical networks.
- PV, wind and storage expose replaceable source-side variants without moving grid-side ownership.
- Controller and plant parameters are initialized centrally and expressed with named structures.
- GFL and GFM are converter-control choices, not reasons to merge transformers or source models.
- Grid-code tests and operating scenarios are harnesses around the resource, not hidden inside it.

### VSC_Lib / MYVSC

- The top diagram is a single-line power diagram; diagnostics remain inside the owning boundary.
- Standard Simscape blocks own electrical physics; readable elementary Simulink blocks own control mathematics.
- Controller, converter, filter/transformer/PCC and grid equivalents have explicit ownership boundaries.
- Parameter scripts are the only numerical source of truth.
- Staged tests prove conduction, synchronization and power transfer separately.

The v2 project borrows these organizational principles only. It does not copy reference blocks or create runtime links to either project.

## 3. Software reuse versus physical instances

`SHARED CODE / TEMPLATE` means MATLAB functions, parameter schemas, typed bus schemas and layout helpers. Examples are `add_gfl_control`, `add_gfm_control`, `add_ac_interface` and `add_pcc_measurement`.

`INDEPENDENT PHYSICAL INSTANCE` means a block created by a resource builder. PV, Wind and BESS each receive their own filter, transformer, feeder, PCC sensor and PCC port. Equal numerical parameters do not make those devices shared.

The following is forbidden:

- copying an accepted `.slx`, deleting blocks and renaming the result;
- copying a PV PCS block into Wind and renaming tags;
- one transformer/filter instance serving multiple resources;
- cross-resource Goto/From tags, shared PLLs, shared angles or shared DC links.

## 4. Required hierarchy and ownership

Every resource has exactly three first-level physical modules plus Command/Status ports:

```text
01 Source and DC Side -> 02 PCS -> 03 AC Interface -> PCC_10kV
```

- `01 Source and DC Side` owns resource availability, DC energy and source protection.
- `02 PCS` is the only owner of GFL/GFM mode, fast control, limiting and the average converter.
- `03 AC Interface` owns the resource's filter, 690 V bus, transformer, feeder option and PCC measurement.

The resource top level must show the physical chain left-to-right. Command and status signals enter/leave from the side and may not cross the physical chain.

## 5. Control hierarchy depth

The intended maximum reading depth is:

```text
Assembly -> Resource -> PCS -> control function
```

GFL PCS first level shows `Local PLL`, `P/Q to dq Reference`, `Current Limiter`, `Current Controller`, and `Average Converter`. GFM PCS first level shows `P-f / Q-V or VSM`, `Voltage and Angle Reference`, `Virtual Impedance`, `Current/Voltage Limiter`, and `Average Converter`.

Elementary gains, integrators, functions and saturations are visible only inside the control function that owns them. Wrapper names such as `Secondary Control`, `Primary Power Stage` and `Grid Interface Layer` are prohibited when they add no engineering meaning.

## 6. Stable external contracts

All resources use typed `ResourceCommandBus` and `ResourceStatusBus`. AC-interface measurements use typed `PCCMeasurementBus`.

The coordinator may command only slower resource quantities: `P_ref`, `Q_ref`, `V_ref`, `f_ref`, `enable`, and `mode`. It must never command `Id`, `Iq`, PLL angle, PWM or gates.

Source/DC fidelity may be upgraded without changing PCS or AC-interface ports. GFL may be replaced by GFM without changing Source/DC or AC-interface ownership.

`enable=0` means converter injection disabled. It does not imply an open PCC breaker; passive filter reactive power remains physically valid unless a separate branch-disconnect command and breaker are explicitly modeled.

## 7. Parameters and units

- All block expressions reference a resource configuration structure.
- SI units are encoded in field names (`_W`, `_var`, `_V`, `_A`, `_Hz`, `_s`, `_ohm`, `_H`, `_F`, `_pu`).
- Power rating, energy rating and current limits are distinct fields.
- Each resource owns `cfg.filter`, `cfg.transformer`, `cfg.feeder`, `cfg.rating`, `cfg.source`, and `cfg.control` even when values initially match.
- Project-wide base values are explicit; local device values are not inferred by multiplying an old low-power model.

## 8. Builder rules

- Builders start with `new_system`; a frozen `.slx` may be inspected or tested but never copied as a construction step.
- Component builders add blocks and connections to a supplied parent and configuration prefix.
- Resource builders call component builders and create independent physical blocks.
- Assembly builders call resource builders and connect only physical PCC ports plus typed Command/Status buses.
- Layout is deterministic and belongs to the builder.
- Subsystem previews are disabled.
- Generated files go to `models/` or `artifacts/` and can be rebuilt from a clean MATLAB session.

## 9. Visual rules

- Main power flow is left-to-right at every resource level.
- Measurement is below or beside its owning physical equipment.
- Telemetry does not cross a control chain or power chain.
- A first-level diagram never mixes physical equipment with PI/Gain/Fcn details.
- The assembly resembles a 10 kV single-line diagram; Coordination/Supervision stays peripheral.
- Every required PNG is opened and visually inspected, not merely checked for existence.

## 10. Verification rules

- Migration does not relax existing numerical tolerances.
- Standalone PV, Wind and BESS regressions run before assembly tests.
- Dynamic acceptance uses one-cycle averaging plus multi-cycle dwell where appropriate; isolated solver samples do not define settling.
- Three-source tests cover PV step, Wind step, simultaneous renewable step and load step.
- Tests monitor active/reactive powers, voltage, frequency, RoCoF, local PLLs, all current limits, BESS SOC/Vdc, Wind energy state and power-balance residual.

## 11. Version policy

Git records history. Names such as `R1_4`, `FINAL2` and `READABLE` are not version control. Migration SHA checks remain only as guards around validated legacy oracles. Generated PNGs, caches, logs and routine build products are ignored.

