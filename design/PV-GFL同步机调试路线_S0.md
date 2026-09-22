# PV-GFL 同步机调试路线（S0）

## 顺序

1. `PV-GFL + 25 MVA 同步机（Governor + AVR）`：先验 PLL、测量和 dq 坐标。
2. 从 S0 复制生成 S1：闭合 dq 电流环，完成 0→2 MW、2→3 MW 与 Q 阶跃。
3. 同步机保持在线，再接 BESS-GFM；同步机承担功率差额，验证同期与功率分配。
4. 最后断开同步机，进入 BESS-GFM 主导的孤岛测试。

## 当前 S0 边界

- 模型：`build/PV_GFL_Strong_SM_Commissioning.slx`
- PV 功率级来自 MYVSC B2；同步机、Governor、AVR 来自 Renewable Energy Integration Design。
- 统一为 690 V 变流器侧、10 kV PCC、50 Hz、6.25 MVA PCS。
- S0 的 PWM 仍是开环，只允许验收 PLL/测量，不允许用 P/Q 判断 GFL 已完成。
- S1 必须从 S0 复制生成，不能回写 MYVSC、R8 或当前 S0 冻结基座。
