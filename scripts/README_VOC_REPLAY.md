# Frozen N2 dVOC replay — scope and reproduction

This is an independent MATLAB transcription of the **limited dVOC** variant
used by `Pf/research/RLsearch/python/rl/gfm_network_overvoltage_attribution_01`.
It is not yet the BESS Simscape controller replacement.

## Reproduce

1. Run `export_voc_attribution_inputs.py` with the Pf research Python environment.
   It reads the frozen source cases and their native 6.25 us reference traces;
   it does not modify the research results.
2. In MATLAB, add `scripts` to the path and run
   `run_voc_attribution_replay`.
3. Results are under `artifacts/voc_attribution`.

The standalone SLX uses a MATLAB Function simulation adapter and requires
`voc_n2_rhs.m`, `voc_n2_simulink_rhs.m`, and the case MAT files on the path.
The adapter uses extrinsic MATLAB execution; it is not a code-generation or
real-time implementation. The continuous Simulink harness is smoke-tested
over the first 2 ms only. Full event waveforms come from the explicit MATLAB
RK4 replay, not from that short Simulink smoke test. In the RK4 replay event
topology is held throughout each interval, matching the Python reference.

## Outputs

- `*_fullrate.mat`: `fullData`, column `names`, and `dt`; every 6.25 us sample.
- `*_waveforms.csv`: 0.1 ms samples plus full-rate samples within 5 ms of
  clearing and the exact highest-voltage sample.
- `*_waveforms.png`: node voltages, current, oscillator/bridge magnitudes,
  limit factors, terminal P/Q, and oscillator/synchronous-machine frequency.
- `matlab_parity_summary.csv`: RHS, clearing-state, shared-waveform and peak
  comparison results. Success requires all three cases to pass and the
  Simulink smoke test to pass.
- `inputs_manifest.json`: source trace paths and SHA-256 hashes.

## Semantics that must not be confused

- Voltage is instantaneous dq-vector magnitude in pu, **not moving RMS**.
- The native current reference circle is 3 pu. This does not guarantee that
  physical bridge current stays below 3 pu during transients.
- The 1.4 pu bridge voltage limit is the research modulation proxy, not a
  limit derived from the BESS DC bus.
- `mu_filter` is a controller state. The exported `current_ref_factor` is
  the instantaneous limiter factor. The limited variant does not feed the
  filtered state back into the oscillator gain.
- Terminal current excludes filter capacitor current. It must not be
  replaced with bridge current during BESS integration.
- N2 has different filter/network parameters from the project's BESS.
  Reproducing N2 peaks does not validate BESS stability or its protections.

## Next integration gate

Keep the existing droop model unchanged. Add a selectable dVOC strategy with
local filter voltage, bridge current and external terminal current. Preserve
the public ResourceCommand/ResourceStatus interface and separate the dVOC
virtual admittance from the optional external virtual-impedance policy.
Document engineering-base conversion and the additional BESS protection
limits explicitly; then validate the independent BESS model before any
three-resource integration. Do not describe the N2 ODE model as that BESS
physical-model validation.
