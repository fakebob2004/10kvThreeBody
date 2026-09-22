# Wind-GFL R1 独立调试基座

额定值：5 MW 风机、6.25 MVA PCS、690 V 变流器交流侧、10 kV PCC、50 Hz。当前采用系统级平均受控电流源；70 m 风轮、4/11/23 m/s 切入/额定/切出风速仅为未来高精度模型的接口元数据，不参与本版功率动态计算。

外部接口只有：

- `WindCommandBus = [P_available, P_dispatch, Q_command, converter_enable]`
- 一个三相 `PCC_10kV` 物理端口
- 一个 21 通道 `StatusBus`

内部边界固定为 `Aerodynamic/MPPT abstraction → MSC/DC energy buffer → GFL PCS → 0.69/10 kV transformer/PCC`。未来可把前两层替换为风轮、PMSG、机侧变流器和真实直流链路，不改变外部接口。

StatusBus 通道：

1. time_s
2. P_pcc_W
3. Q_pcc_var
4. P_pcs_command_W
5. Q_command_var
6. pll_theta_rad
7. pll_frequency_Hz
8. Id_ref_Apeak
9. Iq_ref_Apeak
10. current_limit_Apeak
11. pll_phase_error_rad
12. actual_current_Apeak
13. current_limit_factor
14. current_limit_active
15. PCC_voltage_ll_rms_V
16. converter_enable
17. mechanical_available_power_W
18. dispatch_limit_W
19. MSC_DC_power_to_PCS_W
20. DC_voltage_energy_proxy_V
21. MPPT_capture_pu

`converter_enable=0` 仅停止变流器电流命令，并不打开 PCC 断路器；因此滤波器被动无功仍然存在。
