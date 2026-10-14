# Builder layout

```text
builders/
  components/   reusable control and physical-component construction code
  interfaces/   typed bus definitions and interface helpers
  resource_builders/  PV, Wind and BESS resource builders
  assemblies/   system-level builders
  utilities/    deterministic layout, connection and rendering helpers
```

Run `setup_v2_paths` from the project root before invoking a builder. Builders generate models without copying a legacy `.slx` file.

The BESS-GFM builder uses an explicit replacement chain:

```text
strategy -> virtual-impedance policy/interface -> common protection -> average converter
```

Strategy and virtual-impedance policies communicate through typed buses, so
their implementations can be replaced without changing the BESS resource,
AC interface or coordinator contract.

MATLAB reserves directories named `resources` and refuses to add them to the
path, so the executable directory is named `resource_builders` rather than the
conceptual `resources` shown in the architecture sketch.
