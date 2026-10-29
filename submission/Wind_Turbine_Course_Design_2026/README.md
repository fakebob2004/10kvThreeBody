# 风力发电系统课程设计提交包

本提交包包含两套 5 MW MATLAB/Simulink 风机模型：

1. `build/Wind_DirectDrive_SPWM_R2.slx`：直驱 PMSG 主模型，网侧两电平桥使用 5 kHz 显式 SPWM。
2. `build/Wind_DFIG_Reused_R2.slx`：双馈 DFIG 平均值扩展模型，复用直流/GSC/滤波器/变压器/PCC/电网物理链。

## 环境

- MATLAB/Simulink R2026a
- Simscape Electrical
- 报告编译：Tectonic 0.17 或兼容的 XeLaTeX

## 运行模型

在 MATLAB 中把当前目录设为本提交包根目录，然后执行：

```matlab
run('parameters/init_wind_course_spwm_r2.m');
open_system('build/Wind_DirectDrive_SPWM_R2.slx');

run('parameters/init_wind_dfig_reused_r2.m');
open_system('build/Wind_DFIG_Reused_R2.slx');
```

两个模型都带有 `InitFcn`，从 `build/` 直接打开时会按相对路径加载 `parameters/` 中的参数。

## 自动验证

```matlab
run('scripts/run_all_checks.m');
```

直驱模型验证包含主回路与控制层级结构核查、六路门极二值互补脉冲检查及直流母线电压初值校核；双馈模型验证包含复用拓扑结构核查、定子三相正序电流平衡度、PCC 有功与无功传输精度、直流母线电压及转子滑差功率流向校核。

仿真启动时刻 Simscape 求解器会自动松弛直流母线电容与滤波电感的高优先级初值约束并完成一致初始化，不影响后续暂态与稳态求解。

## 编译报告

```bash
cd report
./compile_report.sh
```

输出为 `report/Wind_Turbine_Dual_Model_Report.pdf`。
