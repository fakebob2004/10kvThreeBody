# Stage 2 R2：三源交流系统、Resource API 与可读模型

## 已冻结模型

- `build/BESS_PV_WIND_STAGE2_R1.slx`：三源自然交流耦合基线。
- `build/BESS_PV_WIND_STAGE2_R2_API.slx`：加入 5 ms Resource API 的功能基线；协调器默认关闭。
- `build/BESS_PV_WIND_STAGE2_R2_1_READABLE.slx`：R2 的可读性派生，控制参数、方程、工况和求解器不变。

哈希记录在 `FROZEN_BASELINES.sha256`。构建脚本会先核对上游模型哈希，禁止无意覆盖冻结基座。

## 物理架构

三个资源只通过公共 10 kV AC 网络耦合：

- BESS-GFM：5 MW / 10 MWh，6.25 MVA PCS，0.69/10 kV；负责形成电压和频率。
- PV-GFL：5 MW / 6.25 MVA，独立 DC link、本地 PLL、本地 PQ/电流控制。
- Wind-GFL：5 MW / 6.25 MVA，system-level average PCS、本地 PLL、可用功率与调度限制。
- 负荷基准：5 MW + 1.5 Mvar。

不存在跨资源 theta/omega、共享 PLL、共享 DC-link 或跨资源隐藏 Goto/From 控制路径。

## Resource API

统一命令字段：

1. `P_ref_W`
2. `Q_ref_var`
3. `enable`
4. `mode`

统一状态字段：

1. `P_W`
2. `Q_var`
3. `Vpcc_V`
4. `frequency_Hz`
5. `available_power_W`
6. `power_headroom_W`
7. `current_limit_factor`
8. `health`
9. `energy_state_pu`
10. `Vdc_V`
11. `mppt_capture_pu`
12. `dispatch_limit_W`

`scripts/define_stage2_resource_api.m` 定义人类可读元数据，并生成 11 元纯数值实时配置向量。`scripts/stage2_coordinator_algorithm.m` 不依赖 Simulink 内部块路径，可迁移到 MATLAB Function、S-function、Python 或 C++。

状态在协调器入口使用一拍 5 ms 快照，从而形成可实现的“状态采样 → 算法 → 命令”时序，并避免瞬时状态反馈造成代数环。资源状态同时直通遥测，不因协调采样而延迟显示。

当前协调器默认 `AUTONOMOUS`，用于证明增加 API 不改变三源自然耦合基线。PV/Wind 命令已可经统一 API 执行。BESS 命令在算法输出和 48 通道 API 日志中保留，但尚未施加到冻结 GFM；下一阶段必须新增独立的 GFM 二次功率偏置接口，禁止协调器直接操作 `Id*`、`Iq*`、PWM、PLL 或电流环。

## 验收结果

执行：

```matlab
run('scripts/validate_bess_pv_wind_stage2_r2_api.m')
run('scripts/validate_bess_pv_wind_stage2_r2_1_readable.m')
```

通过标志：

```text
STAGE2_RESOURCE_API_UNIT_PASS=1
BESS_PV_WIND_STAGE2_R1_THREE_SOURCE_BASELINE_PASS=1
BESS_PV_WIND_STAGE2_R2_API_BASELINE_PASS=1
BESS_PV_WIND_STAGE2_R2_1_READABLE_PASS=1
```

四个动态工况：

| 工况 | 事件 | 事件后 BESS / PV / Wind |
|---|---|---|
| A | PV 2→3 MW | 0.050 / 2.967 / 1.983 MW |
| B | Wind 2→3 MW | 0.050 / 1.983 / 2.967 MW |
| C | PV 与 Wind 同时 2→3 MW | -0.943 / 2.967 / 2.967 MW |
| D | Load 5→6 MW | 2.057 / 1.983 / 1.983 MW |

所有工况均满足 PCC 电压、频率、RoCoF、本地 PLL、电流限幅、BESS DC-link 与功率平衡断言。Case C 中 BESS 进入约 0.943 MW 充电，验证了 GFM 可双向吸收过剩新能源功率。

## 人工阅读入口

- `build/STAGE2_R2_1_01_Top.png`：三源、10 kV PCC、负荷和协调层。
- `build/STAGE2_R2_1_02_Coordination.png`：Scenario/Telemetry 与 Resource API 的职责边界。
- `build/STAGE2_R2_1_03_Resource_API.png`：5 ms 状态快照、协调函数与命令输出。
- `build/STAGE2_R2_1_04_BESS_DC.png` 至 `07_Wind_GFL.png`：资源内部层级。

相关脚本：

- `scripts/build_bess_pv_wind_stage2_r2_api.m`
- `scripts/build_bess_pv_wind_stage2_r2_1_readable.m`
- `scripts/validate_stage2_resource_api.m`
- `scripts/validate_bess_pv_wind_stage2_r2_api.m`
- `scripts/validate_bess_pv_wind_stage2_r2_1_readable.m`

PV-GFL 本地控制的方程、限流顺序、enable 语义及高精度升级边界见
`README_PV_GFL_CONTROL_STRATEGY.md`；可用
`scripts/audit_pv_gfl_control_strategy.m` 对冻结 R2.1 实现进行只读核对。
