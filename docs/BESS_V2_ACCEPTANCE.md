# BESS-GFM v2 acceptance

The maintainable BESS resource is generated from source by
`build_bess_standalone`. It does not copy or patch the frozen R8 model.

## Ratings and physical boundary

- BESS: 5 MW / 10 MWh, initial SOC 0.55, permitted SOC 0.20–0.90.
- Battery-equivalent nominal voltage: 1200 V; DC boundary: 1500 V.
- PCS: 6.25 MVA, 690 V, with a 4500 A battery-current boundary.
- Independent LCL filter and 6.3 MVA 0.69/10 kV transformer.
- One physical `PCC_10kV` port; no shared DC link, angle, PLL or transformer.

## Replaceable GFM contract

The PCS processing order is fixed:

```text
GFM Strategy Slot
  -> Virtual Impedance Policy
  -> Virtual Impedance Interface
  -> Common Protection and Limiter
  -> Average Voltage Converter
```

The current strategy is P-f/Q-V droop. A future VSM or dVOC strategy replaces
only `01 GFM Strategy` and must emit `GFMVoltageCommandBus`:

```text
vabc_V, theta_rad, omega_rad_s, Vll_ref_V, enabled
```

The virtual-impedance policy is independently replaceable. Its stable output
is `VirtualImpedanceCommandBus`:

```text
enable, R_ohm, X_ohm
```

The present static policy reserves local PCC and converter-current inputs so a
dynamic/fault-dependent policy can be substituted without modifying the
strategy, protection or converter. The coordinator cannot command virtual
impedance, Id/Iq, PWM, gate signals or angle; it sees only ResourceCommandBus
and ResourceStatusBus.

## Local protection ownership

SOC direction interlock, AC-current backup foldback and battery-current
foldback stay inside the BESS resource. `battery_current_limit_factor` is an
internal BESS-to-PCS status field, not a coordinator command. The system-level
DC source uses a short power-measurement buffer to represent DC-link energy
decoupling and to avoid interpreting the constant-power-load initialization
impulse as battery current.

## Acceptance command and result

```matlab
setup_v2_paths
build_bess_standalone
validate_bess_resource_v2
```

Accepted island test:

| Window | P | Q | PCC voltage | frequency |
|---|---:|---:|---:|---:|
| Before 0.30 s step | 4.0002 MW | 1.2000 Mvar | 9.238 kV | 50.0000 Hz |
| After +1 MW/+0.3 Mvar | 5.0194 MW | 1.4359 Mvar | 8.927 kV | 49.7961 Hz |

The post-event virtual-impedance voltage drop is 37.451 V and final SOC is
0.549895. The validation additionally checks the typed interfaces, strict
left-to-right processing order, absence of PLL/PWM/Id/Iq paths, LCL ownership,
finite status values, current limits, SOC bounds, bidirectional headroom and
1500 V DC boundary.

`BESS_RESOURCE_V2_ACCEPTANCE_PASS=1` is required before this resource is used
by a multi-resource assembly.
