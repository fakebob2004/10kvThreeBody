# Physical PV commissioning model (R2024b)

From the repository root run:

```matlab
setup_v2_paths
build_pv_standalone
validate_pv_resource_v2
validate_pv_dynamic_mppt
validate_pv_dynamic_limit
validate_pv_dynamic_operating_modes
validate_pv_dynamic_enable_recovery
export_pv_dynamic_evidence(pv_validation_output)
```

The standalone commissioning grid uses a 100 MVA simplified synchronous
machine with an ideal fixed-speed mechanical governor and specified internal
excitation. The model uses fixed-step `ode14x` at 50 microseconds and
Accelerator mode. The first accelerated simulation includes compilation.

PV owns a parameterized Solar Cell array, input capacitor, sampled P&O MPPT,
dispatch curtailment, averaged Boost, and a physical DC-link capacitor. The
PCS owns a three-phase average-value voltage-source converter with physical
DC and AC terminals, local PCC PLL, DC-voltage PI and dq current PI. A
vector current reference limiter and converter-voltage saturation include
integrator tracking. Physical current sensors allow a DC-capacitor charge
balance check. Control outputs are held for one 50 microsecond sample.

The dynamic implementation is selected only when `V2.PV.dynamic.enabled` is
true. The standalone entry selects it by default. The former implementation
remains accessible using `build_pv_standalone('legacy')` and
`validate_pv_resource_v2('legacy')`; it requires its original external
strong-machine fixture. Shared Wind GFL builders are unchanged.

The nominal startup currently has a transient over- and undershoot before
settling; consult the recorded waveform instead of assuming a bumpless
precharged grid connection. The power and current checks use a strong grid;
island, weak-grid, fault and grid-code studies are not established by these
standalone cases.

R2024b Update 9 was used. Older releases have not been verified. The
repository's existing R2024b Wind export fails on this installation because
its preserved blocks reference unavailable `ee.switches.circuit_breaker.abc`
and `ee.sensors.vi_sensor_3ph` classes; the Wind builder was not modified.
