# 5 MW DFIG wind turbine — average-converter R1

`Wind_DFIG_Average_R1.slx` is a new research branch. It does not overwrite the
accepted direct-drive PMSG/SPWM or direct-drive average models.

## Architecture

```text
wind -> Cp(lambda) -> gearbox + shaft inertia -> wound-rotor DFIG
                                               | stator -> 690 V bus/PCC
                                               | rotor  -> average RSC
                                                          -> 1200 V DC link
                                                          -> average GSC -> PCC
```

The upper stator path and lower slip-power path are shown separately at the
top level. This preserves the left-to-right style of the direct-drive model,
while making the defining DFIG feature—direct stator connection—unambiguous.

## Fidelity boundary

- 5 MW aerodynamic turbine with a smooth explicit `Cp(lambda)` curve;
- geared two-pole-pair wound-rotor induction generator;
- four explicit synchronous-dq flux states `[psi_ds psi_qs psi_dr psi_qr]`;
- stator-flux-oriented rotor-current control;
- circular RSC current limit and bounded average rotor voltage;
- shared DC-link energy state;
- DC-voltage-controlled average GSC with explicit filter-current states;
- strong-grid dq commissioning boundary and internal PCC power calculation;
- no triangular carrier, comparator, binary gates, or MATLAB Function block.

The average bridges are not ideal power commands. The RSC produces bounded
rotor dq voltage, which acts on the DFIG flux differential equations. The GSC
produces bounded converter dq voltage, which acts on the filter-current
differential equations. Rotor slip power and GSC power meet in the DC energy
equation.

## Sign conventions and equations

Machine currents are positive into the wound-rotor machine. Grid-side current
is positive from the GSC to the PCC. Generating electromagnetic torque is
negative, while aerodynamic/gearbox torque is positive:

```text
J*d(omega_m)/dt = Tm + Te - B*omega_m
```

The flux equations are

```text
dpsi_ds/dt = v_ds - Rs*i_ds + omega_s*psi_qs
dpsi_qs/dt = v_qs - Rs*i_qs - omega_s*psi_ds
dpsi_dr/dt = v_dr - Rr*i_dr + omega_sl*psi_qr
dpsi_qr/dt = v_qr - Rr*i_qr - omega_sl*psi_dr
omega_sl    = omega_s - p*omega_m
```

Currents are reconstructed with the explicit inverse inductance matrix. The
electromagnetic torque is

```text
Te = 1.5*p*(psi_ds*i_qs - psi_qs*i_ds)
```

The initial condition is a consistent 9 m/s, 0.96 pu, subsynchronous operating
point. With stator flux on the d axis, `idr` supplies magnetization and `iqr`
sets generating torque. The RSC feedforward terms are

```text
vdr_ff = Rr*idr - omega_sl*psi_qr
vqr_ff = Rr*iqr + omega_sl*psi_dr
```

The DC link uses the signed power balance

```text
Cdc*Vdc*dVdc/dt = -P_rotor - P_GSC - P_loss
```

At subsynchronous speed the rotor absorbs slip power and the GSC draws that
power from the grid. Above synchronous speed both signs reverse naturally.

## Main parameters

| Item | R1 value |
|---|---:|
| Wind turbine / DFIG rating | 5 MW |
| Stator voltage | 690 V line-line |
| Grid frequency | 50 Hz |
| Pole pairs | 2 |
| Initial generator speed | 0.96 pu |
| Rotor converter rating | 35% of machine rating |
| DC link | 1200 V, 0.08 F |
| Initial / stepped wind | 9 / 10 m/s at 0.35 s |
| RSC current-loop bandwidth | 80 Hz |
| GSC current-loop bandwidth | 150 Hz |
| Simulation maximum step | 100 us |

## Automated acceptance

Run:

```matlab
run('scripts/build_wind_dfig_average_r1.m')
run('scripts/validate_wind_dfig_average_r1.m')
```

MATLAB R2026a currently reports:

```text
WIND_DFIG_STRUCTURE_OK=1
WIND_DFIG_AVERAGE_CONVERTERS_OK=1
WIND_DFIG_DYNAMIC_OK=1

P_PRE_MW=3.241189
P_POST_MW=4.098751
Q_POST_MVAR=-0.009732
VDC_POST_V=1197.390
SPEED_PU=0.959584
SLIP_HZ=2.020806
IR_MAX_A=5651.304
IR_TRACK_RMS_A=8.880
```

The validation confirms structure, absence of switching/PWM artifacts, finite
dynamic results, increased grid power after the wind step, DC-voltage control,
low PCC reactive power, subsynchronous operation, generating torque signs,
RSC circular-current limiting, and rotor-current tracking.

## Intended upgrades

R1 is a control/protection research baseline, not yet a complete fault model.
The next useful upgrades are:

1. replace the strong-grid dq boundary with the project's physical
   transformer/PCC/grid wrapper;
2. add stator voltage measurement and a stator-flux/PLL observer;
3. implement crowbar, DC chopper, rotor overcurrent timing, and stator breaker;
4. add LVRT reactive-current priority and post-fault resynchronization;
5. validate both sub- and supersynchronous power reversal;
6. introduce shaft two-mass torsional dynamics where mechanical protection is
   in scope.

The top-level interfaces intentionally keep these upgrade points separate from
the accepted direct-drive course model.
