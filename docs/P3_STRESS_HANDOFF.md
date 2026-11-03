# 三源压力测试：R2026a 交接

以下命令从 Git 根目录、装有 Simulink 和 Simscape Electrical 的 MATLAB R2026a 执行。两个已装配的模型分别用于预带电计划解列和强网故障试验，不要把后者的结果当成孤岛成绩。参数目录中的 53 KB 运行点是仿真输入，不是结果波形。

## R2023b 入口

R2023b 用同一组命令：测试入口会改从 `models/r2023b/` 加载同名模型。不要把两个版本的模型目录都加入路径，也不要先打开 R2026a 原件。安装 MATLAB、Simulink、Stateflow、Simscape 和 Simscape Electrical 后，在 Git 根目录先执行：

    setup_v2_paths;
    p3_release_smoke_r2023b;

该检查用原生 R2023b 运行两个基座以及两套 A/B 夹具，均执行到 3 ms。它验证加载、编译、预带电初始化和起算，不代替 10.1 s 孤岛四事件或 3.6 s 强网故障指标。下文的最终 JSON 仍是 **R2026a** 的基准。

若需要从 R2026a 重做兼容版，先用 `save_system(model,target,'ExportToVersion','R2023b')` 将两个基座导出到**单独的临时目录**；从仓库根运行 `python3 scripts/p3_map_r2023b.py <临时目录>`，再用 R2023b 运行上述检查。普通降版导出不够：传感器、接地和断路器的原生三相组件路径在两个版本间不同；光伏数据表参数选项、预充开关的无内置二极管选项也需要映射。目标不包括 R2023a。

## 孤岛四事件

    setup_v2_paths;
    out = tempname; mkdir(out);
    p3_multi_island(0,out);   % 仅本地控制
    p3_multi_island(1,out);   % 同一物理系统，启用外层残差调度

2.8 s 允许计划解列；3.7 s 辐照度由 1000 降至 950 W/m²；5.3 s 投入标称 100 kW + 30 kvar 的 RL 支路；6.9 s 实际风速由 9 降至 8.7 m/s；8.5 s 光照恢复；10.1 s 结束。风光调度日程均固定 2 MW，显式禁用了基座在 10 s 的额外 PV 阶跃。两个批次通过调度日程、断口、稳态和暂态检查。轻度天气变化并未产生明显的稳态出力缺口，不代表重载或大故障验收。

## 强网：逐相过零切除

    setup_v2_paths;
    out = tempname; mkdir(out);
    p3_lvrt_zero_batch(out);

0.4 Ω 三相故障，2.65 s 投入，2.80 s 下达开断命令。两组均验证分相过零关断，但故障电流及恢复等指标未通过。应分别报告从开断命令起和从三相全部熄弧起算的过压。此例是保留的负结果，不是通过的 LVRT 认证。

## 验收证据

同目录 `p3_acceptance/` 中 `island/`、`zero_cross/` 各有两份最终 JSON；原始 MAT、运行缓存、试跑和本机日志均不入库。脚本在新输出目录生成原始波形和回执。
