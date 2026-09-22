# BESS-GFM 模型层级与阅读指南（R8）

## 交付模型

- 模型：`build/BESS_GFM_10kV_Readable_R8.slx`
- 顶层预览：`build/BESS_GFM_10kV_Readable_R8.png`
- 回归脚本：`scripts/validate_bess_gfm_readable_r8.m`
- 参数初始化：`scripts/init_bess_gfm_dynamic_r7.m`

R8 只重构 BESS-GFM 部分的层级、接口和布线，不加入或修改 PV、风电控制。

## 顶层边界

顶层只保留四个模块：

1. `01 BESS DC Source`
   - 电池：5 MW / 10 MWh，1200 V，8333.3 Ah。
   - 双向 DC/DC、输入电感、1500 V 直流母线和级联电压/电流 PI。
   - 两级 PI 均使用回算式抗积分饱和。
   - SOC 到 20% 时禁止继续放电，到 90% 时禁止继续充电；反向恢复功率仍允许。
   - 将电池对象和直接控制它的 DC/DC 控制器放在同一上层边界内。

2. `02 GFM PCS and Step-up`
   - P-f、Q-V、虚拟阻抗、交流限流、调制与平均值 VSC。
   - LCL 滤波器、0.69/10 kV 变压器和 PCC P/Q 测量。
   - 将 GFM 控制与被控 PCS/LCL/变压器放在同一上层边界内。

3. `03 Island Load Scenario`
   - 4 MW + j1.2 Mvar 基础负荷。
   - 0.30 s 投入 1 MW + j0.3 Mvar 阶跃负荷。

4. `04 Supervision and Results`
   - 只读监测和 `gfm_r7_result` 15 通道记录。
   - 不参与闭环控制，不形成对功能模块的反向依赖。

## 最小交互原则

顶层显式功率接口只有三张物理网络：

- 1500 Vdc 正极；
- 1500 Vdc 负极；
- 10 kV 三相母线，基础负荷和阶跃负荷在同一母线上并联。

控制量和遥测量通过有名称的 Goto/From 路由传递。这样不会用长线跨过多个模块，但每个信号仍可按标签搜索和追踪。关键标签对应的物理量包括：

- `Vdc_V`、`Ibat_A`；
- `P_ac_W`、`Q_ac_var`；
- `duty_pu`、`modulation_pu`；
- `Iac_est_A`、`ac_limit_factor`。

SOC 保护和 PI 抗饱和都封装在 `01 BESS DC Source/02 Bidirectional DC-DC Control`
内，不向顶层增加交互端口。SOC 逻辑限制的是电池电流参考方向，
而不是仅将 SOC 显示值夹在 20%--90% 之间。

本设计没有为了“线少”而把所有对象塞进一个大子系统：高频闭环放在本地边界内，功率域边界仍清楚可见，监测则与功能控制解耦。

## 推荐阅读顺序

1. 顶层确认功率流：`BESS DC Source -> GFM PCS and Step-up -> Island Load`。
2. 打开 `01 BESS DC Source`：先看电池/DC 链，再看双闭环 DC/DC 控制。
3. 打开 `02 GFM PCS and Step-up`：先看 GFM 控制，再看 PCS/LCL/变压器。
4. 打开负荷场景，确认 0.30 s 阶跃。
5. 最后打开监测模块核对 15 通道记录，不要把监测线误读成控制反馈。

## 已验证工况

MATLAB R2026a 动态回归通过：

- 阶跃前：P = 3.9984 MW，f = 49.60016 Hz；
- 阶跃后：P = 5.0476 MW，f = 49.49524 Hz；
- 事件后 Vdc 范围：1434.36–1502.54 V，仍在 ±5% 验收带内；
- 电池电流峰值：4451.1 A，未超过 4500 A 控制限值；
- AC 限流因子遥测：阶跃前 1.0000；
- 稳态 P/f 与 R7 一致；严格 4500 A 参考限流与抗饱和使暂态电流峰值降低，Vdc 瞬态跌落相应加深，但仍满足 ±5% 验收带。

运行验证：

```matlab
run('scripts/validate_bess_gfm_readable_r8.m')
run('scripts/validate_bess_gfm_r8_soc_limits.m')
```
