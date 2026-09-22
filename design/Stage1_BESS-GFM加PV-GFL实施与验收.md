# Stage 1：BESS-GFM + PV-GFL 实施与验收

## 冻结边界

Stage 0 的冻结基座为 `build/BESS_GFM_10kV_Readable_R8.slx`。Stage 1 必须复制
该模型后再开发，不允许修改 R8 文件，也不允许让 Stage 1 构建脚本重新生成 R8。

冻结版本 SHA-256：

```text
83f6cb534e71126fa7d6930047639230ba1ca2a531153e29cd9cc265325a40ba
```

## 架构

```text
1200 V BESS -> bidirectional DC/DC -> 1500 Vdc -> GFM PCS -> 0.69/10 kV --+
                                                                             +-- 10 kV PCC -> 5 MW load
PV DC equivalent -> 1295.8 Vdc -> PV GFL PCS -> LCL -> 0.69/10 kV ---------+
```

PV 与 BESS 不共直流母线。PV 控制器不读取 BESS 的内部相角、频率或功率参考；
二者在 Stage 1 的功能耦合只发生于 10 kV 交流网络。

## 本阶段包含

- 冻结的 5 MW / 10 MWh BESS-GFM R8；
- 5 MW PV、6.25 MVA PCS、690 V 交流侧、独立约 1295.8 V DC-link；
- PV 本地 SRF-PLL、dq 电流环、P/Q 参考、电流圆限幅和调制限幅；
- PV 专用 LCL、6.3 MVA 0.69/10 kV 变压器和 1 km 10 kV 馈线；
- 固定 5 MW + 1.5 Mvar 负荷；
- PV 有功参考在 0.30 s 从 2 MW 升至 3 MW，Q 初始设为 0。

本阶段不包含风机、severity index、上层协调器、公共 DC 母线或三源调度。

## 基线功率平衡

忽略损耗时：

```text
阶跃前：Pload = 5 MW, Ppv = 2 MW, Pbess ~= 3 MW
阶跃后：Pload = 5 MW, Ppv = 3 MW, Pbess ~= 2 MW
```

变压器、LCL 和馈线存在损耗，因此验收使用功率守恒残差带，而不是要求三个数字
精确相等。

## Stage 1 最低验收条件

1. PV 的 PLL 从 10 kV PCC 的本地电压测量锁相，不能借用 GFM 相角。
2. PV 阶跃前后有功分别进入 2 MW、3 MW 的容差带。
3. BESS 有功变化方向相反，变化量与 PV 变化量在损耗容差内一致。
4. `Pload - Ppv - Pbess` 的稳态残差与支路损耗相符。
5. PV 电流参考和实际交流电流均不超过设定上限。
6. DC-link、电压、频率、PLL 误差均无持续振荡或数值发散。
7. 输出至少记录 `Ppv`、`Qpv`、`Pbess`、`Qbess`、PCC 电压、频率、RoCoF、
   PV DC-link、电流限幅因子与 PLL 误差。

在此基线通过前，不加入 Stage 2 协调控制。

## 后续但不阻塞 Stage 1 的 R8 补充测试

- 5 MW -> 4 MW 卸载；
- SOC 实际运行至 20%/90% 的长时间或加速动态测试；
- 强制触发 `ac_limit_factor < 1`；
- 自动提取频率、电压、RoCoF 与恢复时间指标。
