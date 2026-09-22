# PV-GFL 控制策略整理（R2.1 / Stage 2）

## 可读结构模型

PV 控制结构整理版为：

`build/BESS_GFM_PV_GFL_Stage1_R1_2_PV_CONTROL_READABLE.slx`

它从冻结 Stage 1 R1 复制派生，不修改原始 R2.1、Stage 1 R1 或 Stage 2 模型。模型 SHA-256：

```text
ac7686338e3c897bd3736a5127cca4a85706cb5d0c41af7022abc3e82e806ae1
```

构建与回归：

```matlab
run('scripts/build_pv_gfl_r2_2_control_readable.m')
run('scripts/validate_pv_gfl_r2_2_control_readable.m')
```

验收标志：

```text
BESS_PV_STAGE1_NATURAL_AC_COORDINATION_PASS=1
PV_GFL_R2_2_CONTROL_READABLE_ACCEPTANCE_PASS=1
```

导出的九张阅读图均经过人工查看：

1. `PV_R2_2_01_Top.png`：Stage 1 物理拓扑与监督接口。
2. `PV_R2_2_02_Branch.png`：PV 支路外部三接口。
3. `PV_R2_2_03_PCS.png`：Secondary Control 与 Primary Converter/Filter。
4. `PV_R2_2_04_Secondary_Control.png`：PLL、Current Command、Status Assembly。
5. `PV_R2_2_05_Local_PLL.png`：本地 PCC PLL。
6. `PV_R2_2_06_Current_Command.png`：参考生成、enable/圆限幅、150 Hz 执行及独立遥测区。
7. `PV_R2_2_07_Status_Assembly.png`：16 字段状态汇聚。
8. `PV_R2_2_08_Primary_Power.png`：average PCS、RL、并联电容与测量。
9. `PV_R2_2_09_Stepup_PCC.png`：0.69/10 kV 变压器与 PCC 测量。

R2.2 只改变层级显示、块位置、线路路由、注释及内容预览状态；控制方程、参数、信号含义、工况、求解器和日志均不变。

## 1. 控制边界

PV-GFL 的外部接口保持为：

```text
ResourceCommand {P_ref, Q_ref, enable, mode}
                   |
                   v
          PV local control owner
                   |
          10 kV physical PCC port
                   |
ResourceStatus {P, Q, Vpcc, f, P_available, headroom,
                current_limit_factor, health, ...}
```

职责划分：

- 上层协调器可以修改 `P_ref`、`Q_ref`、`enable` 和资源模式。
- `mode` 在 Resource API 层解释；PV 支路实际接收 `[P_ref,Q_ref,enable]`。
- PV 本地控制器独占 PLL、dq 电流参考生成、圆形限流、相位补偿和 abc 电流执行。
- 协调器禁止直接写入 `Id*`、`Iq*`、PLL 状态、PWM 或快速电流控制状态。
- PV 不读取 BESS 的 `theta`、`omega` 或内部测量；同步信息只来自 PV 自己的 10 kV PCC 电压。

## 2. 当前实现层级

```text
PV-GFL Branch
├── Command Interface
│   └── [P_ref, Q_ref, enable]
├── 01 GFL PCS
│   ├── 01 Secondary Control
│   │   ├── Local SRF-PLL
│   │   ├── P/Q -> raw dq current reference
│   │   ├── converter enable gate
│   │   ├── circular dq current limit
│   │   ├── 150 Hz first-order current tracking
│   │   ├── dq -> abc current synthesis
│   │   └── Status Assembly
│   └── 02 Primary Converter and Filter
│       ├── controlled-current average PCS
│       ├── interface RL
│       └── damped shunt capacitor
└── 02 Step-up and PCC
    ├── 0.69/10 kV transformer
    ├── PCC voltage/current measurement
    └── PCC P/Q measurement
```

当前模型的研究对象是系统级 AC 动态，不是开关谐波。实际执行元件是受控电流注入源；没有 PWM、门极、开关器件或显式 PV array/boost/DC-link 能量闭环。

## 3. 本地同步策略

PLL 输入是 PV 支路自己的 10 kV PCC 三相电压：

$$
\theta_m=\operatorname{atan2}\!\left[
\frac{2}{3}\left(v_a-\frac{v_b}{2}-\frac{v_c}{2}\right),
\frac{\sqrt3}{3}(v_c-v_b)
\right]
$$

相位误差使用环形误差，避免 $\pm\pi$ 跳变：

$$
e_\theta=\operatorname{atan2}
\left(\sin(\theta_m-\hat\theta),\cos(\theta_m-\hat\theta)\right)
$$

$$
\hat\omega=\operatorname{sat}_{[2\pi45,\,2\pi55]}
\left(\omega_0+K_p e_\theta+K_i\int e_\theta dt\right)
$$

$$
\hat\theta=\int\hat\omega dt
$$

当前主要参数：

| 参数 | 数值 |
|---|---:|
| 额定频率 | 50 Hz |
| PLL `Kp` | 200 |
| PLL `Ki` | 5000 |
| PLL 频率限制 | 45–55 Hz |
| dq/abc 相角补偿 | $\theta_{abc}=\hat\theta-\pi/6$ |

该 PLL 是本地同步环，不是三资源共享角度源。

## 4. P/Q 到 dq 电流参考

控制器使用 690 V 侧测得的线电压峰值：

$$
V_{LL,pk}=\sqrt{\frac{2}{3}(v_a^2+v_b^2+v_c^2)}
$$

有功电流参考：

$$
I_d^*=\frac{2P^*}{\sqrt3\sqrt{V_{LL,pk}^2+1}}
$$

无功电流参考包含并联滤波电容补偿：

$$
I_q^*=-\frac{2\left[Q^*-\frac{\omega_0 C_f}{2}V_{LL,pk}^2\right]}
{\sqrt3\sqrt{V_{LL,pk}^2+1}}
$$

其中 `+1` 是零电压数值保护，不是物理电压偏置。额定电压下：

$$
Q_C=\omega_0 C_f V_{LL,rms}^2\approx0.3125\ \text{Mvar}
$$

因此 `Q_ref=0` 的含义是 PCC 净无功接近零，而不是换流器自身 $I_q=0$。

## 5. enable 与电流限幅

`enable` 首先限制到 `[0,1]`，再同时作用于 dq 两轴：

$$
\begin{bmatrix}I_{d,g}^*\\I_{q,g}^*\end{bmatrix}
=\operatorname{sat}_{[0,1]}(enable)
\begin{bmatrix}I_d^*\\I_q^*\end{bmatrix}
$$

圆形电流限幅保持 P/Q 电流方向，不做两个轴的独立裁剪：

$$
k_I=\min\left(1,
\frac{I_{max}}{\sqrt{(I_{d,g}^*)^2+(I_{q,g}^*)^2+\epsilon}}
\right)
$$

$$
I_{d,lim}^*=k_I I_{d,g}^*,\qquad
I_{q,lim}^*=k_I I_{q,g}^*
$$

当前额定值：

| 参数 | 数值 |
|---|---:|
| PCS | 5 MW / 6.25 MVA |
| 690 V 侧额定 RMS 电流 | 5229.62 A |
| 电流上限 | 8135.38 A peak |
| 上限系数 | 1.10 pu |

`enable=0` 仅表示 converter current command 归零，不表示打开 PCC 断路器。LCL/滤波电容和变压器仍连接，因此允许保留约 0.31 Mvar 的可解释被动无功。

## 6. 电流执行与平均 PCS

当前 R2.1 没有执行初始化脚本中计算的 PI 电流环，而是采用 150 Hz 一阶跟踪：

$$
G_i(s)=\frac{1}{s/(2\pi\cdot150)+1}
$$

dq 到三相电流命令：

$$
i_a^*=I_d\sin\theta+I_q\cos\theta
$$

$$
i_b^*=I_d\sin(\theta-2\pi/3)+I_q\cos(\theta-2\pi/3)
$$

$$
i_c^*=I_d\sin(\theta+2\pi/3)+I_q\cos(\theta+2\pi/3)
$$

该命令直接驱动 average controlled-current PCS。初始化中的：

```text
current_Kp = L1 * 2π * 150
current_Ki = R1 * 2π * 150
```

是未来切换到平均电压源/显式 PI 电流环时的预留参数，不能在当前报告中描述成已运行环节。

## 7. 功率级参数

| 参数 | 数值 |
|---|---:|
| 低压侧 / PCC | 690 V / 10 kV |
| 变压器容量 | 6.3 MVA |
| `L1` | 19.398 µH |
| `L2` | 7.274 µH |
| `R1 = R2` | 0.38088 mΩ |
| `C_f` | 2.0893 mF |
| 滤波谐振频率 | 1513.83 Hz |
| 阻尼电阻 | 16.773 mΩ |
| 参数化 DC 电压 | 1295.78 V |

DC 电压当前只用于变流器可行性和未来升级接口，没有显式 DC 能量状态进入闭环；Resource Status 中 PV 的 `energy_state/Vdc/MPPT_capture` 暂用 `-1` 表示本模型不提供。

## 8. Resource Status 与保护顺序

PV 原始 16 通道状态依次为：

```text
t, P, Q, Pcmd, Qcmd, theta, frequency,
Id_ref, Iq_ref, Ilimit, phase_error,
Iactual, current_limit_factor, limit_active,
Vpcc_ll_rms, converter_enable
```

建议协调器的处理顺序保持：

```text
health / enable / mode interlock
        -> available-power clamp
        -> P/Q apparent-power feasibility
        -> local PV current-circle limit
        -> average PCS execution
```

上层可以依据 `available_power`、`power_headroom` 和 `current_limit_factor` 调整下一拍命令，但不能绕过本地圆形限流。

## 9. 已验证工况

独立强同步机验收包括：

- 零功率；
- 0→2 MW；
- 2→3 MW；
- 1 Mvar 无功阶跃；
- converter enable 1→0→1；
- 5 MW 额定有功；
- 5 MW、功率因数 0.9；
- 8 MW + 6 Mvar 过指令下的圆形限流。

Stage 2 三源验收进一步验证 PV 2→3 MW 时 BESS-GFM 自动减小输出，而 Wind-GFL 保持稳定。

## 10. 后续升级顺序

1. 保持 R2.1 作为系统级基线，不直接改冻结文件。
2. 在新派生版本中增加 `P_available` 的辐照度/MPPT动态，而不改变 AC 快速控制接口。
3. 如研究弱网稳定性，再将一阶电流跟踪替换为平均电压源 + 显式 dq PI、解耦和电压前馈。
4. 只有研究开关谐波、器件应力或滤波器高频行为时，才升级到 PWM/开关级模型。
5. 每次升级继续用同一组 P/Q、enable、限流和三源功率平衡回归，避免同时改变植物与协调算法。
