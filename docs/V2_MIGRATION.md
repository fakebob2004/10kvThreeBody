# v2 architecture migration

## Baseline checkpoint

- Initial project Git commit: `3fec353`
- Tags: `stage1-pv-bess-validated`, `wind-gfl-standalone-validated`
- The five canonical migration-oracle models are tracked explicitly despite the general `build/` ignore rule.
- External reference projects remain local and are not vendored.

## Migration phases

1. Common builder functions, typed buses and parameter schema.
2. PV Resource generated from an empty model and checked against PV standalone acceptance.
3. Wind Resource generated with the same GFL builders and its own source/DC builder.
4. BESS Resource generated in the same three-module form while preserving R8 mathematics.
5. Three-resource island assembly and four natural-coordination cases.

## Compatibility policy

Legacy vector logs remain available only in regression adapters. New model-to-model interfaces are typed buses. No v2 resource reads a legacy block path outside its own boundary.

## Shared and independent items

Shared code: bus definitions, parameter schema, GFL/GFM component builders, AC-interface builder, PCC-measurement builder, layout and test utilities.

Independent physical instances: every PV/Wind/BESS converter plant, filter, transformer, feeder, sensor and PCC port. This remains true when all three configurations contain identical numbers.

