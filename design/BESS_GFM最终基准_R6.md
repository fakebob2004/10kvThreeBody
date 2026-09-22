# BESS-GFM 最终工程基准（R6）

## 1. 最终额定值

项目基准统一为：

`PV 5 MW + Wind 5 MW + BESS 5 MW/10 MWh + Load 5 MW`

| 项目 | 最终值 |
|---|---:|
| BESS AC 额定功率 | 5 MW |
| BESS 标称能量 | 10 MWh（2 h） |
| 电池标称电压 | 1200 V |
| 等效容量 | 8333.3 Ah |
| SOC 范围 / 初值 | 20%-90% / 55% |
| 充电/放电功率上限 | ±5 MW（AC 额定） |
| DC/DC | 双向 buck-boost，1200/1500 V |
| DC-link | 1500 V，0.05 F 聚合电容 |
| PCS | 6.25 MVA，690 V，GFM |
| 变压器 | 6.3 MVA，0.69/10 kV，Δ/Yg |
| PCC | 10 kV，50 Hz |

5 MW 功率容量覆盖两类极端短时平衡：新能源骤降时独立承担约 5 MW 负荷；PV 与风电合计 10 MW、负荷 5 MW 且来不及限发时，吸收约 5 MW 过剩功率。10 MWh 提供 2 h 额定持续时间，适合课程项目的孤岛能源支撑定位，而不是仅作为小型调频支路。

公开工程产品中已有 2.5 MW/5 MWh、1500 V 的两小时标准单元；NREL ATB 也将储能功率与能量分开建模，并覆盖 2、4、6、8、10 h 持续时间。因此两个 2.5 MW/5 MWh 等效单元组成 5 MW/10 MWh，在容量解释上具有工程合理性。

## 2. 最终电气骨架

`1200 V 电池 → 双向 buck-boost DC/DC → 1500 V DC-link → 6.25 MVA GFM VSC → 690 V LCL → 6.3 MVA 0.69/10 kV 变压器 → 10 kV PCC`

该骨架明确包含两种不同性质的“变换”：

1. DC/DC 将随 SOC 变化的电池端电压调节到稳定的 1500 V；
2. 变压器把 PCS 的 690 V AC 升到 10 kV PCC。

这不是重复升压。DC/DC 解决调制裕量、双向电池电流与 DC-link 稳压；交流变压器解决绝缘和电压等级匹配。

## 3. PCS 与控制参数

5 MW 有功输出时，6.25 MVA PCS 的理论无功容量为：

`Qmax = sqrt(6.25^2 - 5^2) = 3.75 Mvar`

当前 R6 参数：

| 参数 | 数值 |
|---|---:|
| P-f 下垂 | 0.1 Hz/MW（5 MW 时 0.5 Hz） |
| Q-V 下垂 | 6.9 V/Mvar（5 Mvar 时 5%） |
| 调制上限 | 0.98 |
| 电池内阻等值 | 0.003 Ω |
| DC/DC 平均效率 | 99% |
| 电池电流额定基值 | 4166.7 A |
| 电池电流验证上限 | 1.10 pu |

GFM 相角由额定角速度加 P-f 下垂积分得到，不依赖 PLL。Q-V 下垂产生 690 V 侧电压指令，三相调制波根据实测 1500 V DC-link 归一化。

## 4. ±5 MW 双向验证

| 工况 | P | Q | S | Vdc | 电池电流 | 电池功率 | f | 调制深度 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 5 MW 负荷/放电 | 5.0476 MW | 1.3414 Mvar | 5.2229 MVA | 1500.00 V | +4384.7 A | +5.2039 MW | 49.49524 Hz | 0.7411 |
| 5 MW 过剩/充电 | -4.9999 MW | -0.1571 Mvar | 5.0024 MVA | 1500.00 V | -4018.0 A | -4.8700 MW | 50.49999 Hz | 0.7524 |

验证结论：

- 两种方向均低于 6.25 MVA PCS 容量；
- 电池电流均低于 1.10 pu；
- 调制深度显著低于 0.98；
- 放电时 SOC 从 55% 下降，吸收功率时 SOC 上升；
- 0.7 s 仿真中 SOC 变化约 0.01%，符合 10 MWh 大容量电池的物理尺度；
- P-f 与 Q-V 下垂方程通过自动断言。

放电工况电池侧功率大于 5 MW，是因为 5 MW AC 负荷还需要覆盖 DC/DC、VSC、滤波器和变压器损耗。这里“5 MW BESS”按 AC 并网点额定定义；电池簇与 DC 母排应按约 1.1 pu 电流裕量设计。

## 5. 模型边界

R6 的 DC/DC 是平均值行为模型，直接接收 1500 V 电压指令，因此 DC-link 在当前结果中接近理想稳压。它适合验证架构、容量、双向功率和 GFM 外环，但尚不能用于评估 DC/DC 电感纹波或控制带宽。

后续只在 BESS 内部深化时，应依次加入：

1. 有限带宽 DC/DC 电压 PI、电感与电流内环；
2. 1.10 pu DC 电流限制和 1.20 pu AC 电流圆限幅；
3. 虚拟阻抗、抗积分饱和和功率斜率；
4. SOC 触边、限充限放、风光限发请求与负荷卸载逻辑；
5. 负荷阶跃、黑启动、故障穿越和弱网测试。

## 6. 文件

- `build/BESS_GFM_10kV_Final_R6.slx`
- `build/BESS_GFM_10kV_Final_R6.png`
- `build/BESS_GFM_10kV_Final_R6_results.png`
- `scripts/init_bess_gfm_final_r6.m`
- `scripts/build_bess_gfm_final_r6.m`
- `scripts/validate_bess_gfm_final_r6.m`

工程依据：

- Sungrow PowerTitan 2.0：<https://www.sungrowpower.com/en/products/utility-energy-storage-system/powertitan2>
- NREL 2024 ATB Utility-Scale Battery Storage：<https://atb.nrel.gov/electricity/2024/2023/utility-scale_battery_storage>
- DOE Solar-Plus-Storage 101：<https://www.energy.gov/cmei/systems/articles/solar-plus-storage-101>
