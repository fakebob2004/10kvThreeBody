# BESS-GFM + PV-GFL Stage 1 R1

本阶段是 10 kV 孤岛母线上的自然交流协调基线：BESS 使用冻结 R8 的 GFM，PV 使用已独立验收的 R2.1 GFL。两者唯一功能耦合是三相 10 kV 物理网络；无共享 DC、角度、频率指令、P/Q 指令、风电或上层协调器。

## 文件

- `build/PV_GFL_864_SystemLevel_SM_R2_1_Readable.slx`：可读 PV-GFL R2.1。
- `scripts/build_pv_gfl_r2_1_readable.m`：R2.1 构建脚本。
- `scripts/validate_pv_gfl_r2_1_standalone.m`：R2.1 A–H 独立验收。
- `build/BESS_GFM_PV_GFL_Stage1_R1.slx`：Stage 1 双源模型。
- `scripts/build_bess_pv_stage1_r1.m`：Stage 1 构建脚本。
- `scripts/validate_bess_pv_stage1_r1.m`：Stage 1 自动验收。
- `scripts/init_bess_pv_stage1_r1.m`：联合参数与通道定义。

运行：

```matlab
run('scripts/build_bess_pv_stage1_r1.m')
run('scripts/validate_bess_pv_stage1_r1.m')
```

成功标志：

```text
PV_GFL_R2_1_STANDALONE_ACCEPTANCE_PASS=1
BESS_PV_STAGE1_NATURAL_AC_COORDINATION_PASS=1
```

## 接口与工况

PV 分支外部仅有 `CommandBus=[P*,Q*,converter_enable]`、`PCC_10kV` 和 `StatusBus`。`converter_enable=0` 只停止换流器注流，不等于 PCC breaker trip；滤波器仍接网，因此允许存在可计算的被动无功。

Stage 1 固定负荷为 5 MW + j1.5 Mvar。BESS-GFM 先建立母线；PV 平滑进入 2 MW，并在 0.30 s 变为 3 MW，Q*=0。

## `stage1_result` 通道

| 通道 | 量 | 通道 | 量 |
|---:|---|---:|---|
| 1 | BESS 时间 s | 18 | PV Q var |
| 2 | BESS P W | 19 | PV P 指令 W |
| 3 | BESS Q var | 20 | PV Q 指令 var |
| 4 | BESS 频率 Hz | 21 | PV PLL 角度 rad |
| 5 | BESS 低压侧电压指令 V | 22 | PV PLL 频率 Hz |
| 6 | SOC pu | 23–24 | PV Id/Iq 参考 Apeak |
| 7 | BESS Vdc V | 25 | PV 电流上限 Apeak |
| 8 | 电池电流 A | 26 | PV PLL 相位误差 rad |
| 9 | BESS 调制量 | 27 | PV 实际电流幅值 Apeak |
| 10 | 电池功率 W | 28–29 | PV 限流因子/动作标志 |
| 11 | DC/DC duty | 30 | 10 kV PCC 线电压 RMS V |
| 12 | DC 限流电流 A | 31 | PV converter enable |
| 13 | BESS AC 电流 RMS A | 32 | 固定负荷 P W |
| 14 | BESS AC 限流因子 | 33 | 固定负荷 Q var |
| 15 | 负荷阶跃命令（Stage 1 为 0） |  |  |
| 16 | PV 时间 s |  |  |
| 17 | PV P W |  |  |

冻结基座不得覆盖：`BESS_GFM_10kV_Readable_R8.slx` 与 `PV_GFL_864_SystemLevel_SM_R2.slx`。
