# BESS-GFM 动态控制与负荷阶跃验证（R7）

## 1. 本阶段完成内容

R7 只深化 BESS-GFM，没有修改 PV、风电或联合系统。相对 R6 增加：

- 1200/1500 V 双向 DC/DC 占空比控制；
- 0.4 mH 显式输入电感与 0.05 F DC-link 电容状态；
- 1500 V 外环 PI 和电池电流内环 PI；
- AC 有功到电池电流的 2 ms 快速前馈；
- 1.08 pu 电流参考限幅，为 1.10 pu 物理电流上限预留动态裕量；
- PCS 1.20 pu AC 电流估算与调制限幅；
- 0.02 pu 电阻、0.10 pu 电抗的平衡正序虚拟阻抗近似；
- 10 kV 物理断路器及 1 MW + j0.3 Mvar 负荷阶跃。

官方 Average-Value DC-DC Converter 支持占空比、参考电流和参考电压三种控制形式。R7 采用 buck-boost 占空比关系：

`V2 = D/(1-D)*V1`

1200/1500 V 的稳态前馈占空比为：

`Dff = 1500/(1200+1500) = 0.5556`

## 2. 动态参数

| 参数 | 数值 |
|---|---:|
| DC/DC 输入电感 | 0.4 mH |
| DC-link 电容 | 0.05 F |
| 电压外环带宽 | 10 Hz |
| 电流内环带宽 | 300 Hz |
| 电流传感器时间常数 | 100 us |
| 功率前馈滤波 | 2 ms |
| 电流参考限幅 | 1.08 pu = 4500 A |
| 物理电流上限 | 1.10 pu = 4583.3 A |
| AC 电流限制 | 1.20 pu = 6275 A |
| 虚拟阻抗 | 0.02 + j0.10 pu |
| 负荷阶跃 | 4 MW+j1.2 Mvar → 5 MW+j1.5 Mvar |
| 阶跃时刻 | 0.30 s |

R7 使用行为平均 buck-boost 方程，并把电感、电容显式放在变换器外部。曾尝试 R2026a 的内置 `Average value` LC 模式，但其内部输出电容与原 DC-link 状态在大功率网络初始化时产生奇异矩阵；显式 L/C 形式避免了重复状态，也保留了所需的动态物理过程。

## 3. 控制结构

DC/DC 控制为：

`P_ac 前馈 + Vdc PI → Ibat_ref 限幅 → 电流 PI + Dff → duty 限幅 → buck-boost`

外环只修正 DC-link 偏差，主要功率变化由 2 ms 有功前馈快速转换为电池电流参考。这样在 1 MW 阶跃时不会等待 DC-link 明显下降后才增加电池电流。

虚拟阻抗在平衡正序近似下对线电压指令增加：

`DeltaV = (-Rvirt*P + Xvirt*Q)/Vll`

这不是完整的逐相瞬时 dq 限流器，但已将功率方向和 R/X 特性写入 GFM 电压指令。进入故障穿越阶段时仍需升级为 dq 电流矢量限幅。

## 4. 自动验证结果

| 指标 | 阶跃前 | 阶跃后 |
|---|---:|---:|
| 有功 | 3.9984 MW | 5.0476 MW |
| 无功 | 1.1022 Mvar | 1.3414 Mvar |
| 频率 | 49.60016 Hz | 49.49524 Hz |
| DC-link 稳态 | 1500.05 V | 1500.02 V |
| 电池电流稳态 | 3477.1 A | 4383.7 A |

阶跃暂态：

- DC-link：1464.57–1520.94 V，即 −2.36% / +1.40%；
- DC-link 重新进入 ±1% 的时间：82.5 ms；
- 电池电流峰值：4515.0 A，小于 4583.3 A；
- AC 电流峰值：4405.9 A，小于 6275 A；
- 占空比：0.5525–0.5617，未触及 0.05/0.95 限幅；
- AC 限流因子保持 1，额定工况没有误限流；
- P-f 下垂与虚拟阻抗电压方程通过自动断言。

## 5. 当前边界

R7 已适合正常运行范围内的负荷阶跃和系统协同研究，但不能替代故障电流研究。下一阶段接入联合系统前，应增加：

1. dq 电流内环和电流圆限幅；
2. 电压跌落时的虚拟阻抗/限流模式切换；
3. PI 抗积分饱和与 SOC 触边状态机；
4. 黑启动预充和接触器时序；
5. 过载、三相短路和不平衡故障验证。

## 6. 文件

- `build/BESS_GFM_10kV_Dynamic_R7.slx`
- `build/BESS_GFM_10kV_Dynamic_R7.png`
- `build/BESS_GFM_10kV_Dynamic_R7_results.png`
- `scripts/init_bess_gfm_dynamic_r7.m`
- `scripts/build_bess_gfm_dynamic_r7.m`
- `scripts/validate_bess_gfm_dynamic_r7.m`

参考：

- <https://www.mathworks.com/help/sps/ref/averagevaluedcdcconverter.html>
- <https://www.mathworks.com/help/sps/ug/average-value-dc-dc-converter-control.html>
- <https://www.mathworks.com/help/sps/ug/design-analyze-gridforming-converter.html>
