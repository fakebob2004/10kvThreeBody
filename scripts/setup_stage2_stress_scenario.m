function setup_stage2_stress_scenario(model)
%SETUP_STAGE2_STRESS_SCENARIO Injects the 2.5s multi-event stress sequence.
%
% Event Timeline:
%   0.00 ~ 0.30 s: Baseline (Load=5.0 MW, PV=2.0 MW, Wind=2.0 MW, BESS=1.0 MW)
%   0.30 s:        PV available drops 2.0 MW -> 0.8 MW (irradiance cliff: -1.2 MW)
%   0.65 s:        Island load steps +1.0 MW + j0.3 Mvar (Total: 6.0 MW + j1.8 Mvar)
%   1.00 s:        Wind available drops 3.0 MW -> 1.0 MW (-2.0 MW drop)
%   1.35 s:        PV available recovers 0.8 MW -> 2.0 MW (+1.2 MW recovery)
%   StopTime:      2.50 s

sup     = [model '/06 Supervision and Results'];
pvCmd   = [sup '/01 PV Command Profile'];
windCmd = [sup '/02 Wind Command Profile'];
loadSys = [model '/05 Island Load'];

% 1. PV Profile: 2.0 MW baseline, drops to 0.8 MW at 0.30s, recovers at 1.35s
set_param([pvCmd '/P Base Limit'], 'UpperLimit', '2.0e6');
set_param([pvCmd '/P Increment'], 'Time', '0.30', 'Before', '0', 'After', '-1.2e6');

% Check if 'P Recovery' block exists; if not, create and connect it cleanly
pRecBlock = [pvCmd '/P Recovery'];
if getSimulinkBlockHandle(pRecBlock) < 0
    add_block('simulink/Sources/Step', pRecBlock, ...
        'Position', [25 240 95 270], ...
        'Time', '1.35', 'Before', '0', 'After', '1.2e6', 'SampleTime', '0');
    set_param([pvCmd '/P Command'], 'Inputs', '+++');
    add_line(pvCmd, 'P Recovery/1', 'P Command/3', 'autorouting', 'on');
else
    set_param(pRecBlock, 'Time', '1.35', 'Before', '0', 'After', '1.2e6');
end

set_param([pvCmd '/Q Base Command'], 'Value', '0');
set_param([pvCmd '/Q Increment'], 'Time', '10', 'After', '0');
set_param([pvCmd '/Enable Off'], 'Time', '10', 'After', '0');
set_param([pvCmd '/Enable On'], 'Time', '11', 'After', '0');

% 2. Wind Profile: 3.0 MW baseline available (1.0 MW headroom over 2.0 MW base dispatch),
% drops to 1.0 MW at 1.00s (-2.0 MW drop)
set_param([windCmd '/P Available Base'], 'Value', '3.0e6');
set_param([windCmd '/P Available Increment'], 'Time', '1.00', 'Before', '0', 'After', '-2.0e6');
set_param([windCmd '/P Base Limit'], 'UpperLimit', '2.0e6');
set_param([windCmd '/P Increment'], 'Time', '10', 'Before', '0', 'After', '0');
set_param([windCmd '/Q Base Command'], 'Value', '0');
set_param([windCmd '/Q Increment'], 'Time', '10', 'After', '0');
set_param([windCmd '/Enable Off'], 'Time', '10', 'After', '0');
set_param([windCmd '/Enable On'], 'Time', '11', 'After', '0');

% 3. Load Scenario: 5.0 MW base, +1.0 MW step at 0.65s
% In Simscape circuit breaker: Control port is Trip signal (1 = Open, 0 = Closed)
% Initially OPEN (Trip = 1), closes at 0.65s (Trip = 0) to connect the +1.0 MW load
set_param([loadSys '/Adjusted_Island_Load'], 'active_power', '5.0e6', 'reactive_power', '1.5e6');
set_param([loadSys '/One_MW_Step_Load'], 'active_power', '1.0e6', 'reactive_power', '0.3e6');
set_param([loadSys '/Load_Step_Command'], 'Time', '0.65', 'Before', '1', 'After', '0');

% 4. Simulation StopTime: 2.50 s
set_param(model, 'StopTime', '2.50');
end
