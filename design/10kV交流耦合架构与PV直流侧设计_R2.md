# 10 kV 交流耦合架构与 PV 直流侧设计（R2）

## 1. 定版结论

R2 采用三条独立电源支路在 10 kV 交流母线汇集，不再让 PV 与 BESS 共用直流母线：

```text
PV array -- PV DC link -- PV GFL inverter -- LCL -- T1 0.69/10 kV --+
                                                                        |
BESS 1200 V -- bidirectional DC/DC -- BESS DC link -- GFM PCS -- LCL -- T2 0.69/10 kV --+-- 10 kV PCC
                                                                                         |
PMSG -- machine-side converter/DC link -- wind GFL converter -- LCL -- T3 0.69/10 kV ----+
                                                                                         |
                                                                  T4 10/0.4 kV -- 400 V load
```

这同时满足三个依据：

1. 课程要求允许交流端或直流端协同，但题图注明直流端协同起评分较低，因此选择交流端协同。
2. MathWorks `Renewable-Energy-Integration-Simscape` 的 `BatteryStoragePVPlantGFM.slx` 中，PV 和 BESS 是各自带变流器的独立系统，在交流集电母线耦合；PV 为 GFL，BESS 为 GFM/VSM。
3. 四篇文献共同支持由 BESS-GFM 建立孤岛电压/频率、PV 和风机 GFL 跟随送功率，并把快速电气控制与慢速能量管理分层。

这里的“两次变压”应理解为不同位置的升降压：每个 690 V 电源支路先经 `0.69/10 kV` 单元升压变，400 V 负荷再经 `10/0.4 kV` 配电变。不要在同一风机支路串接 `690/380 V` 后再升到 10 kV。

## 2. PV 电压是否“不能变”

准确说法是：PV 端电压会随辐照度、温度和控制工作点变化，但不能像理想电压源一样任意指定。

MathWorks 参数脚本采用：

```matlab
PVInverter.Vdc = PVTransformer.lv*sqrt(2)*2/sqrt(3)*1.15;
% Solar Panel with Vmpp ~ Vdc
```

其 4.16 kV 交流侧对应约 7.812 kV 直流侧。PV 模型没有前级 Boost，而是通过组件串联数把阵列最大功率点电压设计到逆变器所需直流电压附近；增量电导 MPPT 输出 `Vmpp`，直流电压环让实际工作点跟踪它。

把同一设计原则缩放到本项目 690 V 交流侧：

```text
Vdc,ref = 690*sqrt(2)*2/sqrt(3)*1.15 = 1295.8 V
```

因此 `1500 V` 是器件/阵列低温开路电压上限，不应再作为被硬控的日常工作参考。阵列设计必须同时满足：

```text
Ns * Vmpp,module(Tdesign) ~= 1295.8 V
Ns * Voc,module(Tmin) < 1500 V
Np = 5 MW / (Ns * Pmodule)
```

没有组件铭牌的 `Vmpp/Voc`、温度系数和最低环境温度之前，不能负责任地给出最终串并联数。

原模型 `Vm=300 V, Voc=375 V` 是小功率等值被直接放大电流后的遗留参数，不能只把数值改成 1295.8 V。实施时二选一：

- 推荐：按真实组件重新设计串并联，使 `Vmpp` 落在约 1.296 kV，PV 直接接自己的 DC link，保持与 MathWorks 示例一致。
- 兼容旧 PV 等值：保留约 300 V PV 模型，并增加 Boost 升压到约 1.296 kV；但 5 MW 必须拆成多路模块，不能用一只器件承受 16.7 kA。

## 3. 统一基值与额定电流

系统公共基值：`Sbase=10 MVA`、`Vbase=10 kV`、`fbase=50 Hz`。变流器设备设计基值：`6.3 MVA/690 V`。DC 基值按支路定义：PV 逆变器 DC link 初值为 `1295.8 V`；BESS 电池端为 `1200 V`，经双向 DC/DC 接入 `1500 V` DC link。不同 DC 电压层不能混用同一电流基值。

| 位置 | 基值/额定值 | 电流 |
|---|---:|---:|
| 10 kV 系统基值 | 10 MVA | 577.35 A |
| 690 V 系统基值 | 10 MVA | 8367.35 A |
| 690 V 设备基值 | 6.3 MVA | 5271.20 A |
| PV 交流侧 | 5 MW、pf=0.9、690 V | 4648.6 A |
| PV 10 kV 侧 | 5 MW、pf=0.9 | 320.8 A |
| 风机交流侧 | 5 MW、pf=1、690 V | 4183.7 A |
| 风机 10 kV 侧 | 5 MW、pf=1 | 288.7 A |
| BESS 交流侧额定 | 5 MW、690 V | 4183.7 A |
| PV DC 工作点 | 5 MW、1295.8 V | 3858.7 A |
| 电池额定放电 | 5 MW、1200 V | 4166.7 A |
| BESS DC-link 额定 | 5 MW、1500 V | 3333.3 A |
| 400 V、5 MW 负荷 | pf=1 | 7216.9 A |

5 MW 的 690 V 或 1.3 kV 电流仍很大，物理产品应由多个 250-500 kW 功率模块并联构成；模型可先用聚合平均值表示，但限流、损耗和滤波器应按模块/机柜组织。

## 4. 变压器与线路

PV、BESS、风机各自使用一台 `6.3 MVA, 0.69/10 kV` 单元变压器，初值取总电阻 `0.01 pu`、总漏抗 `0.06 pu`，两侧各分一半。当前 Simscape 架构模型采用低压侧 Delta 1、高压侧 Yg；三支路组别必须一致，受控源相角补偿均为 `+30 deg`。

400 V 负荷通过独立 `6.3 MVA, 10/0.4 kV` 变压器接入。如果 5 MW 主负荷能采用中压设备，应直接接 10 kV，仅给小型辅助负载保留 10/0.4 kV 变压器。

10 kV 电缆初值为每相 `R=0.125 ohm/km, L=0.30 mH/km`：PV/风机暂取 1 km，BESS 在同一站内暂取 0.2 km，电网联络线暂取 2 km。实际电缆型号、长度和敷设方式到位后必须替换。

## 5. LCL、直流电容与控制器起点

每条 6.3 MVA/690 V 支路当前统一采用：

| 参数 | 数值 |
|---|---:|
| L1 | 19.244 uH/相（0.08 pu） |
| L2 | 7.217 uH/相（0.03 pu） |
| R1、R2 | 各 0.378 mOhm/相（0.005 pu） |
| C | 2.106 mF/相（0.05 pu 无功） |
| Rd | 0.0166 ohm |
| 谐振频率 | 1513.8 Hz |

PV DC link 暂采用 `3.090 mF` 作为平均值模型初值。最终 BESS-GFM R6 在 1500 V 母线上采用 `0.05 F` 聚合 DC-link 电容，储能约 56.25 kJ（约等于 5 MW 下 11.25 ms）。该值用于平均值系统级模型，不代表单个硬件电容；详细开关模型仍应根据允许纹波、PWM 频率、模块数量和故障穿越时间重新设计。

BESS 最终工程基准改为 `5 MW / 10 MWh`、`1200 V / 8333 Ah`，SOC 范围 20%-90%、初值 55%。电池经双向 buck-boost DC/DC 接入独立 `1500 V` DC link，名义升压比为 `1.25`；PCS 为 `6.25 MVA`，配套 `6.3 MVA, 0.69/10 kV` 变压器。5 MW 时理论无功裕量为 3.75 Mvar，电池电流保护初值取额定的 1.10 倍。

连续域初始控制参数：

| 环路 | 初值 |
|---|---:|
| 电流环带宽 | 500 Hz |
| 电流 PI | Kp=0.128471，Ki=4.74829 |
| DC 电压外环带宽 | 20 Hz |
| DC 电压 PI（pu） | Kp=0.146315，Ki=13.0032 |
| PLL 带宽 | 20 Hz |
| PLL PI（归一化） | Kp=177.69，Ki=15791.4 |
| GFM P-f 下垂 | 0.01 pu f / pu P |
| GFM Q-V 下垂 | 0.10 pu V / pu Q |
| 虚拟阻抗 | R=0.02 pu，X=0.10 pu |
| 交流电流限值 | 1.20 pu |

这些只是平均值模型的首轮整定点。控制器还必须加入 dq 电流圆限幅、优先级分配、抗积分饱和、功率斜率限制、SOC 上下限和模式切换无扰动逻辑。

## 6. 四篇文献如何落实到 R2

### 6.1 弱网 PV-WT-BESS 动态分析

- 其公共 DC 架构不是本项目最终拓扑，但对震荡机理极有价值：PV 工作区、DC 电压状态与网络阻抗相互作用可主导低频不稳定，不能只调 PLL。
- 在 R2 中要分别记录 PV DC link 与 BESS DC link，扫描 PV 最大功率区、限压区、限流区以及不同短路比。
- 主动阻尼应放在基础环路稳定之后，且不能掩盖饱和与初始化错误。

### 6.2 微网 GFM/GFL 控制

- PV/风机采用 GFL：MPPT/PQ 外环、PLL、dq 电流内环。
- BESS 采用 GFM：电压源、P-f/Q-V 下垂或 VSM、虚拟阻抗和限流，负责孤岛建压与频率基准。
- 并网转孤岛必须有状态机，不能让全部变流器继续依赖 PLL。

### 6.3 严重度感知 GFM/GFL 协同

- 基础版本先实现确定性的 GFL/GFM 模式和稳定切换。
- 提升版本再用频差、RoCoF、电压偏差形成严重度指标，连续调整 GFM 支撑权重。
- 验证指标至少包括频率最低点、RoCoF、电压最低值/超调、整定时间、IAE/ITAE。

### 6.4 双层多时间尺度调度

- 毫秒至秒级由电流环、DC 电压环和 GFM V/f 环处理；秒至分钟级 EMS 只生成带斜率限制的功率参考。
- SOC 正常窗口建议 20%-90%，初始值 50%-60%，给充放电都留裕度。
- 必须验证双低出力、双高且满充、负荷阶跃、SOC 触边和储能降额，不只跑额定稳态。

## 7. 当前模型边界与下一步

`build/PV_Wind_BESS_10kV_ACCoupled_R2026a.slx` 已实现三支路交流耦合的原生 R2026a Simscape 网络，且通过模型更新和 10 ms 短时仿真。当前三台 PCS 仍是三相源等值，作用是验证电压骨架、变比、相移、线路、LCL 和网络初始化；它还不是最终控制器/PWM 模型。

后续建议按以下顺序深化：

1. 用真实组件数据确定 PV 串并联数和温度电压范围。
2. 将 PV 支路替换为 PV array + 独立 DC capacitor + 平均值 VSC + MPPT/Vdc/GFL 控制。
3. 将 BESS 支路替换为 battery + 双向 DC/DC + 独立 DC capacitor + 平均值 VSC + GFM 控制。
4. 将风机支路替换为 PMSG + 机侧控制器 + DC link + 网侧 GFL VSC。
5. 逐支路闭环：先电流环，再 DC/V-f 外环，再功率与 SOC 管理；最后并联。
6. 加入预充、软启动、限流和抗饱和后，再做并离网、故障和弱网扫描。
7. 系统级稳定后才切换详细 PWM/IGBT，检查 THD 与离散步长。

## 8. 本地参考位置

- MathWorks 参数：`references/Renewable-Energy-Integration-Simscape-master/ScriptsData/PVPlant/BatteryStoragePVPlantGFMParameters.m`
- MathWorks 顶层模型：`references/Renewable-Energy-Integration-Simscape-master/Models/PVPlant/BatteryStoragePVPlantGFM.slx`
- PV 逆变器：`references/Renewable-Energy-Integration-Simscape-master/Models/PVPlant/PVInverterGFL.slx`
- PV 控制器：`references/Renewable-Energy-Integration-Simscape-master/Models/PVPlant/PVcontroller.slx`
- R2 参数脚本：`scripts/init_10kv_architecture.m`
- R2 构建脚本：`scripts/build_10kv_native_model.m`
- R2 回归脚本：`scripts/validate_10kv_native_model.m`
