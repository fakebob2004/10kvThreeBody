# Simulink R2024b-targeted exports

The accepted PV-GFL and Wind-GFL v2 standalone resources are exported to
`models/r2024b/` using Simulink's `ExportToVersion` mechanism. The models in
`models/resources/` remain the authoritative R2026a development artifacts.

Simscape Electrical reports that backward export is only partially supported.
Both exported models have therefore been reopened, updated/compiled, and
smoke-tested in the installed R2026a environment. The host does not contain
R2024b, so a final open-and-run check in native MATLAB R2024b remains required.

Export from the project root:

```matlab
setup_v2_paths;
export_validated_resources_r2024b;
```

Compile and run the basic 2 MW, unity-power-factor smoke tests:

```matlab
setup_v2_paths;
validate_r2024b_resource_exports;
```

The smoke test checks model update/compilation, finite simulation output,
active/reactive power, PCC voltage, and frequency. It does not replace either
the full acceptance suites for the authoritative source models or the final
native-R2024b check.

## Recorded export check

Generated with MATLAB R2026a and targeted at R2024b:

| Model | 2 MW smoke-test P | Q | PCC voltage | Frequency | SHA-256 |
|---|---:|---:|---:|---:|---|
| PV-GFL | 1.9336 MW | 0.0474 Mvar | 9.810 kV | 50.141 Hz | `30d1023a261206fed44aff03bf7f9891ee4b165568cf43b229ecd58d6c7659fa` |
| Wind-GFL | 1.9329 MW | 0.0474 Mvar | 9.829 kV | 50.152 Hz | `edf91bb2c5c125543814f5f0b11fd74e9b025d0d11e8844df09fe07d8932434f` |

Both SLX archives passed ZIP integrity checks. Simulink model update and the
dynamic smoke tests passed with `R2024B_RESOURCE_SMOKE_PASS=1`.
