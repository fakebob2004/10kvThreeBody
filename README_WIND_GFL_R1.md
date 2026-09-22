# Wind-GFL R1（强同步机独立调试基线）

主模型：`build/Wind_GFL_5MW_SystemLevel_SM_R1.slx`

本模型用于在接入 BESS-GFM 岛网之前，独立验证 5 MW 风机 GFL 支路。它是系统级平均模型，不包含 PWM 开关细节；强同步机只属于并网调试台，不属于最终三源孤岛架构。

## 额定值与电压骨架

- 风机额定有功：5 MW
- 网侧 PCS：6.25 MVA
- PCS 交流侧：690 V
- PCC：10 kV，50 Hz
- 升压变压器：0.69/10 kV（沿用已验收 PV-GFL 电气基座）
- 等效直流母线：1500 V，0.20 F（225 kJ，约 45 ms @ 5 MW）
- dq 峰值电流限值：8135.4 A

## 人类可读层级

风机支路顶层固定为四层串联：

1. `01 Aerodynamic and MPPT Available Power`
2. `02 DC Energy Buffer and MSC Equivalent`
3. `03 GFL PCS`
4. `04 Step-up and PCC`

外部只保留三个边界：

- `WindCommandBus = [Pavailable, Pdispatch, Q, enable]`
- `PCC_10kV` 三相物理端口
- 21 通道 `StatusBus`

其中 `enable` 是换流器使能，不是 PCC 断路器命令。`enable=0` 时电流指令归零，但滤波器与变压器仍接在 PCC，因此允许存在可计算的被动无功。

## 高精度升级接口

当前前两层是可替换的系统级抽象：可用风功率经过额定钳位和机械响应，再由 MSC/DC 等效层执行 `min(Pavailable,Pdispatch)`、功率爬坡与直流能量状态。未来可把这两层替换为：

`风轮气动 + 桨距/MPPT + PMSG + 机侧变流器 + 制动斩波器 + 物理 DC-link`

替换时保持 `WindCommandBus`、PCS CommandBus、Source StatusBus 和 PCC 边界不变，网侧 GFL、升压变压器与未来交流协调器无需重接线。

架构选择参考了 Renewable Energy Integration with Simscape 的全变流 PMSG 分层边界；队友 `Wind_PV_SOC_DCAC_864_5MW.slx` 仅用于识别原控制意图，没有沿用其直接放大容量后的低压 PWM 参数。

## 强同步机测试台

调试台为 25 MVA 同步机，最终采用统一参数：`H=10 s`、`D=0.2 pu`、`1%` 调速下垂、调速器/汽轮机时间常数 `0.05/0.10 s`。该组合用于形成足够强且可衰减的 10 kV/50 Hz 并网基准，不会迁移到最终 BESS-GFM 岛网。

## 验收

运行：

```matlab
run('scripts/validate_wind_gfl_system_level_sm_r1.m')
```

验收覆盖零功率同步、0→2 MW、风资源 2→3 MW、调度 2→3 MW、1 Mvar 阶跃、enable 往返、5 MW 额定、可用功率封顶和 dq 圆限流。最终标志：

```text
WIND_GFL_R1_STANDALONE_ACCEPTANCE_PASS=1
```

可读性截图位于 `build/Wind_GFL_R1_*.png`。生成脚本为 `scripts/build_wind_gfl_system_level_sm_r1.m`，参数脚本为 `scripts/init_wind_gfl_system_level_sm_r1.m`。
