# 10 kV three-resource AC system

## 分支与发布约定

禁止在本仓库新建远端分支。发布已验证的成果时，须将 `main` 和所有现有远端分支一起快进到同一提交，并核对远端提交号；只更新集成分支不算发布完成。若历史已分叉，停止发布并与维护者确认，不得强推或覆盖队友提交。

最新三源模型的 R2023b 成品在 [models/r2023b](models/r2023b/)，运行方法见[压力测试交接说明](docs/P3_STRESS_HANDOFF.md)。`build/r2023b/` 是旧 Stage 2，不是这次适配的入口。

This repository contains the validated baselines and the maintainable v2
generation path for a 10 kV islanded system with BESS-GFM, PV-GFL and
Wind-GFL resources.

Current v2 status:

- PV-GFL: generated from source and accepted (`PV_RESOURCE_V2_ACCEPTANCE_PASS=1`).
- Wind-GFL: generated from source and accepted (`WIND_RESOURCE_V2_ACCEPTANCE_PASS=1`).
- BESS-GFM: generated from source and accepted (`BESS_RESOURCE_V2_ACCEPTANCE_PASS=1`).
- The three-resource assembly remains the subsequent phase.

The `integration/grid-supported-pv-wind` work adds the physical PV branch
and transient PMSG Wind R3 to a common 10 kV network with a permanently
connected synchronous machine. This is a **grid-supported commissioning**
harness, not an accepted islanded replacement. Cold-start and post-settling
dynamic results are deliberately separate. See
[integration scope and reproduction](docs/GRID_SUPPORTED_INTEGRATION.md).

An additional 5 MW direct-drive Wind-GFL course model is maintained at
`models/resources/Wind_DirectDrive_Average.slx`. It preserves the physical
1500 V DC link and 0.69/10 kV grid interface while using an averaged-switch
GSC for system-level coordination studies. See
[`design/WIND_COURSE_AVERAGE.md`](design/WIND_COURSE_AVERAGE.md).

Each renewable resource owns an independent source/DC side, PCS, filter,
0.69/10 kV transformer, local PLL and PCC measurement.  Reuse is implemented
through MATLAB builders and parameter schemas, not by sharing physical block
instances or control states.

MATLAB R2026a entry points:

```matlab
setup_v2_paths

build_pv_standalone
validate_pv_resource_v2

build_wind_standalone
validate_wind_resource_v2

build_bess_standalone
validate_bess_resource_v2
```

R2024b-targeted exports of both accepted resources are maintained under
`models/r2024b/`. See [R2024b compatibility](docs/R2024B_COMPATIBILITY.md)
for regeneration and smoke-test commands.

See [architecture rules](docs/ARCHITECTURE_RULES.md),
[PV acceptance](docs/PV_V2_ACCEPTANCE.md), and
[Wind acceptance](docs/WIND_V2_ACCEPTANCE.md), and
[BESS acceptance](docs/BESS_V2_ACCEPTANCE.md).

Frozen predecessor models and their hashes are recorded in
`FROZEN_BASELINES.sha256`.  Generated build caches, review PNGs and external
reference repositories are intentionally excluded from version control.
