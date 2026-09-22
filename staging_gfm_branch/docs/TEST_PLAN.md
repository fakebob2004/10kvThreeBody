# Baseline test plan

Every control test records three distinct layers: raw controller request,
limited feasible reference, and physical response.

| ID | Stage | Stimulus | Required observations | Pass criterion |
|---|---|---|---|---|
| T1 | B0/B1 | nominal DC and grid, open-loop PWM | `Vdc`, gate pulses, converter voltage, `Vabc_PCC`, `Iabc_PCC` | topology compiles; voltages are finite; phase sequence is correct |
| T2 | B2 | nominal balanced grid | `Vq_PCC`, `theta_PLL`, `omega_PLL` | `Vq -> 0`; frequency -> 50 Hz |
| T3 | B3 | `Id*: 0.2 -> 0.5 pu` | request, feasible `Id`, physical `Id` | stable tracking with documented rise time/overshoot |
| T4 | B3 | `Iq*: 0 -> 0.3 pu` | request, feasible `Iq`, physical `Iq` | stable tracking and correct Q sign |
| T5 | B4 | step DC-side power | `Vdc`, `Id_cmd_raw`, `Id_ref_lim`, `Id` | `Vdc -> Vdc*` without current violation |
| T6 | B4 | nominal P/Q command | `P_PCC`, `Q_PCC`, dq signals | steady-state P/Q error within declared tolerance |
| T7 | B5 | command magnitude above `Imax` | raw/limited dq, active flag, utilization | `hypot(Id_ref_lim,Iq_ref_lim) <= Imax` |
| T8 | B6 | grid voltage `1.0 -> 0.8 pu` | all three signal layers plus `Vdc`, PCC voltage | numerically stable; no advanced LVRT claim |
| G1 | GFM C0 | normal grid, 5 ms | hierarchy, device masks, gates, `Vll_inv` | 1 V gate unit; 0.5 V threshold; diodes enabled; complementary gates; DC-link-scale PWM |
| G2 | GFM C0 | 1 V source behind 10 kOhm isolation | `GatePulses`, `Vll_inv`, `Iabc_sw` | VSC line-voltage peak > 0.5 Vdc; finite current; proves voltage is not grid backfeed |
| G3 | GFM C0 | rated stiff grid, 40 ms | P/Q, frequency, Vdc, modulation, current | numerical and limit checks pass; 5 MW power transfer is a separate required criterion |

## B0 automated checks

`run_b0_checks` verifies the four functional top-level blocks, flat directly
readable grid-interface/grid internals, absence of DC busbars and top-level diagnostic Terminators,
parameterized masks, absence of MATLAB Function blocks, and successful diagram update.
`run_b0_smoke_test` then runs a 0.1 ms initialization/simulation check. Neither
test claims B1 switching validation because B0 deliberately holds all gates off.

## B1 automated checks

`run_b1_checks` verifies the readable modulation/PWM hierarchy, converter-side
measurement hierarchy, parameter references, gate ordering, and diagram update.
`run_b1_smoke_test` runs 2 ms of detailed switching and verifies binary gates,
exact upper/lower complementarity, carrier range, modulation range, finite
physical signals, line-voltage calculation, and DC-link voltage.
`run_b1_operating_point_test` runs two 50 Hz cycles and projects the second-cycle
raw PWM line voltage onto the fundamental; its RMS value must be within 2% of
the 400 V converter-side rating.

## GFM C0 automated checks

`run_gfm_c0_checks` verifies the readable graphical hierarchy, absence of
MATLAB Function blocks, branch-local gate units, switch threshold, protection
diodes, complementary PWM, and DC-link-scale switching voltage.

`run_gfm_c0_active_switch_test` depresses the external source to 1 V and puts
10 kOhm in the test-only grid path. A 1500 V converter line-voltage peak then
demonstrates active VSC switching without converting the test into a fault.

`run_gfm_c0_operating_point` is intentionally stricter: its result includes
`PowerTransferValidated`. The present 40 ms value is false (0.082 MW versus the
5 MW reference), so rated-power control must not be claimed from G1/G2 alone.
