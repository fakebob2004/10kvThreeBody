# Direct-drive wind course model — SPWM R2

This branch is a course-oriented derivative of the accepted Wind-GFL R1
baseline. It does not overwrite frozen Stage-2 or Wind R1 assets.

Planned energy path:

```text
wind speed -> aerodynamic Cp(lambda,beta) -> rotor inertia and MPPT torque
           -> average PMSG/MSC power and loss limits
           -> sampled Pmsc/Vdc average MSC current interface
           -> physical DC-link capacitor + staged DC support contactor
           -> detailed two-level three-phase bridge with explicit SPWM
           -> AC filter -> 0.69/10 kV transformer -> PCC -> strong grid
```

The turbine, PMSG torque actuator, and machine-side converter are averaged
energy models. The DC capacitor and grid-side VSC are physical. The grid-side
bridge uses six explicit complementary 5 kHz SPWM gates. A DC-overvoltage relay
exposes the brake threshold and estimated braking current for later protection
extensions.

The six switching commands are generated and combined entirely inside the GFL
controller. The converter vector is explicitly labeled
`[AH AL BH BL CH CL]`; complementary pairs are `(1,2)`, `(3,4)`, and `(5,6)`.
The filter, 0.69/10 kV Y-Y transformer, and PCC measurements are packaged as
one readable power-path subsystem, and measurement signals are logged without
being exposed at the model top level.

Top-level packaged ports are aligned with the adjacent subsystem. The GFL
controller gate output and VSC gate input now share one horizontal line, and
the VSC AC terminal, filter/PCC, and grid ports form a nearly straight power
path. This removes the inherited long automatic detour without changing the
electrical topology.

## Diagram-layout principles

The model is generated entirely by code, so readability rules belong in the
builder and are checked after regeneration rather than being one-off manual
edits.

- Arrange blocks by signal meaning and reading direction, not merely by block
  number. Use separate visual bands for the main energy/control path,
  feedback, and diagnostics.
- Put each boundary port or local tag beside its first consumer (or final
  producer). Align the port with the receiving pin whenever possible; this
  minimizes lead length and avoids unnecessary elbows.
- Keep the primary chain left-to-right. For DC circuits, use one horizontal
  rail per polarity and connect capacitors, sensors, solver references, and
  grounding branches vertically.
- Rotate physical/signal conversion blocks to match the direction of the
  signal they serve. A horizontal measurement input should remain horizontal;
  a current command entering a physical element vertically should use a
  vertical converter.
- Hide transport-only tags inside the subsystem that owns the signal. Expose
  only interfaces that explain the subsystem contract; do not lift internal
  measurement plumbing to the model top level.
- Keep coursework logic visible: package coherent functions, but do not use a
  bus or opaque function block merely to hide untidy wiring. Remove unused
  sources instead of leaving plausible-looking but disconnected blocks.
- Reposition only where the visual gain is clear. Preserve a stable layout,
  and add geometry/connection assertions for short paths that must not regress.

Inside `04 GFL Control and SPWM`, synchronization and dq measurement occupy
the upper band with their diagnostics immediately adjacent. The lower band is
the uninterrupted control chain `03 -> 04 -> 05 -> 06`; the nominal-angle
baseline is kept separately below it. The inherited top-level lines are
discarded and rebuilt explicitly so old autorouting waypoints cannot survive a
fresh generation.

Subsystem `05 Filter Transformer and PCC` remains packaged because its filter,
step-up transformer, PCC sensor, and internal measurement export together form
one clear grid-interface contract. Internally, the three-phase power path is a
single horizontal chain. The voltage and current physical outputs are each
aligned directly with their PS-to-Simulink conversion and local tag, while the
grid terminal is aligned with the sensor's electrical output; no measurement
plumbing is exposed at the model top level.

Subsystem `06 Grid Equivalent and Source` is retained as the external-grid
boundary. Its main path is a straight `PCC -> explicit Rg+Lg -> ideal source`
chain. The ideal source faces left so its AC terminal meets the impedance, its
neutral terminal remains on the right, and the grounded-wye connection drops
vertically to the ground block. The source's own impedance stays disabled so
the SCR-derived Thevenin impedance is represented exactly once.

The six internal layers of `04 GFL Control and SPWM` are intentionally kept:
measurement/PQ estimation, PLL synchronization, outer DC/reference generation,
circular current limiting, dq current regulation, and PWM/physical gate
conversion each represent a distinct algorithm or interface boundary. The
review therefore removes wiring artifacts rather than flattening these layers.
Raw d/q commands are distributed locally inside the limiter, the current
controller uses local angle distribution and keeps Id/Iq monitor outputs beside
their demultiplexer, and PWM monitor sinks remain beside their signal sources.

The turbine rotor-speed output is the middle port of subsystem 01 so it aligns
directly with the subsystem 02 speed input. Because a standard directed
Simulink Inport cannot share the right edge with the controller physical output,
`Pmsc` is distributed to subsystem 04 through the labeled global tag
`PMSC_TO_GFL`. The controller therefore exposes only its right-side Gate Drive
port at the top level, removing the long return wire while keeping the signal
route explicit.

The grid source internal impedance is disabled. Grid strength is represented
once, explicitly, by the upstream SCR-based `Rg + Lg` branch. This is important:
the inherited seed had both the explicit branch and a hidden 1 MVA source
impedance, which made the nominal grid unrealistically weak and prevented a
stable power-transfer operating point.

## Current validation boundary

- The model rebuilds and compiles in MATLAB R2026a.
- The 8 ms switching smoke test passes: gates are binary, all three bridge legs
  are complementary, and the DC support stage remains within 1400--1600 V.
- The 100 ms DC support contactor intentionally remains closed while the grid
  synchronization/control baseline is established.
- The SRF-PLL is retained for inspection but does not yet drive the current
  controller. The known 50 Hz source angle (`theta0=-90 deg`) is used for the
  present baseline.
- The converter current sensor is oriented converter-to-grid. The implemented
  equations therefore use `Id*=Pmsc/Vd+PI(Vdc-Vdc*)`,
  `Vd*=Vgd+PI_d-omega*L*Iq`, and `Vq*=Vgq+PI_q+omega*L*Id`.
- The 80 ms operating-point audit now reports `PowerTransferValidated=true`:
  `Pmsc=3.196 MW`, `P_PCC=2.961 MW`, `Q_PCC=0.419 Mvar`, and
  `Vdc=1500.18 V`. Current negative/positive sequence ratio is about 0.57%.
- Simscape still reports relaxed initial-condition targets for the DC capacitor
  and filter currents at startup. The solver recovers and both automated tests
  complete; this warning should be stated rather than hidden in the report.
