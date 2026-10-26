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

直驱验证包括层级与端口布局检查、六路门极二值/互补检查及直流电压冒烟测试。DFIG 验证包括实际复用层级、正序定子电流、PCC 物理功率传输、直流电压和转子滑差功率符号。

仿真启动时可能出现直流电容和滤波电感初值被 Simscape 放宽的警告；当前模型可继续收敛，并由验证脚本检查最终运行点。

## 编译报告

```bash
cd report
./compile_report.sh
```

输出为 `report/Wind_Turbine_Dual_Model_Report.pdf`。

报告封面已填写姓名、学号和专业信息，并按要求移除指导教师栏。
