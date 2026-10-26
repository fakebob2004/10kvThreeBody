% investigate_3pu_network_parameters.m
% Systematically find network and fault parameters that stably produce 3.0 pu BESS current.
scriptDir = fileparts(mfilename('fullpath'));
root = fileparts(scriptDir);
addpath(scriptDir);
addpath(fullfile(root, 'scripts'));
addpath(fullfile(root, 'build'));
addpath(fullfile(root, 'tests'));
set_param(0, 'ErrorIfLoadNewModel', 'off');

model = 'BESS_PV_WIND_STAGE2_R2_API';
if bdIsLoaded(model), close_system(model, 0); end
load_system(fullfile(root, 'build', [model '.slx']));
c = onCleanup(@() close_system(model, 0));

run(fullfile(scriptDir, 'init_bess_pv_wind_stage2_r1.m'));
set_param(model, 'InitFcn', '');

% Explicitly lock 07 Resource API Layer coordinator to discrete 5 ms sample time
apiSub = [model '/07 Resource API Layer'];
set_param([apiSub '/PV_ProfileCommand'], 'SampleTime', '0.005');
set_param([apiSub '/Wind_ProfileCommand'], 'SampleTime', '0.005');
set_param([apiSub '/MATLAB Function Coordinator'], 'SystemSampleTime', '0.005');

% Insert feeder impedances
insert_feeder_impedances_local(model);

% Configure overload fault scenario base
configure_overload_fault_scenario_local(model);

% Set BESS current limit to 3.0 pu in GFM control
G = evalin('base', 'G');
Iac_rated = G.control.Iac_rated_A;
G.control.Iac_limit_A = 3.00 * Iac_rated;
assignin('base', 'G', G);

% Set Coordinator to Mode 6.3
set_param([apiSub '/Coordinator Enable'], 'Value', '6.3');
set_param([apiSub '/Resource Modes'], 'Value', '[0 1 1]');
S2_API = evalin('base', 'S2_API');
cfg = S2_API.coordinator_config;
set_param([apiSub '/Coordinator Numeric Config'], 'Value', mat2str(cfg, 12));

set_param(model, 'StopTime', '0.85');

loadSys = [model '/05 Island Load'];

% Test a series of fault reactive power values on One_MW_Step_Load
% Since Z_eq = V_min^2 / Q_fault = 1e8 / Q_fault:
% Qf = 16 Mvar -> Z_eq = 6.25 Ohm -> I_BESS = 1.29 pu
% Qf = 32 Mvar -> Z_eq = 3.12 Ohm
% Qf = 60 Mvar -> Z_eq = 1.67 Ohm
% Qf = 100 Mvar -> Z_eq = 1.00 Ohm
% Qf = 150 Mvar -> Z_eq = 0.67 Ohm

Qf_list = [16e6, 30e6, 50e6, 80e6, 120e6, 160e6];

fprintf('\n%-12s %-12s %-12s %-12s %-12s %-12s %-12s\n', ...
    'Q_fault(Mvar)', 'Z_eq(Ohm)', 'I_BESS_max', 'I_BESS_mean', 'V_wind_min', 'Vdc_min', 'Vdc_max');
fprintf('%s\n', repmat('-', 1, 85));

for i = 1:numel(Qf_list)
    Qf = Qf_list(i);
    Z_eq = 1e8 / Qf;
    set_param([loadSys '/One_MW_Step_Load'], 'Vline_rms_min', '10000', ...
        'active_power', '0.0', 'reactive_power', num2str(Qf, 12), 'tau', '0.020');
    
    try
        clear stage2_coordinator_algorithm;
        tStart = tic;
        simOut = sim(model);
        elapsed = toc(tStart);
        
        raw = squeeze(simOut.get('stage2_result'));
        if size(raw, 2) ~= 54, raw = raw.'; end
        t = raw(:, 1);
        win_fault = (t >= 0.54) & (t <= 0.69);
        Ibess_pu = raw(:, 13) / Iac_rated;
        Vwind = raw(:, 46);
        Vdc = raw(:, 7);
        
        fprintf('%-12.1f %-12.2f %-12.3f %-12.3f %-12.0f %-12.1f %-12.1f (%.1f s)\n', ...
            Qf/1e6, Z_eq, max(Ibess_pu(win_fault)), mean(Ibess_pu(win_fault)), ...
            min(Vwind(win_fault)), min(Vdc(win_fault)), max(Vdc(win_fault)), elapsed);
    catch ME
        fprintf('%-12.1f %-12.2f FAILED: %s\n', Qf/1e6, Z_eq, ME.message);
    end
end

function configure_overload_fault_scenario_local(model)
sup     = [model '/06 Supervision and Results'];
pvCmd   = [sup '/01 PV Command Profile'];
windCmd = [sup '/02 Wind Command Profile'];
loadSys = [model '/05 Island Load'];

S_pcs_pq = 4.35e6;
Ibase_pq = S_pcs_pq / (sqrt(3) * 690.0);
Ilim_pq  = sqrt(2) * Ibase_pq;

S1  = evalin('base', 'S1');
S21 = evalin('base', 'S21');
W1  = evalin('base', 'W1');
S2_API = evalin('base', 'S2_API');

S1.pv.S_pcs_VA             = S_pcs_pq;
S1.control.Ilimit_A        = Ilim_pq;
S21.control.Ibase_rms_A    = Ibase_pq;
S21.control.Ilimit_peak_A  = Ilim_pq;
W1.wind.S_pcs_VA           = S_pcs_pq;
W1.control.Ibase_rms_A     = Ibase_pq;
W1.control.Ilimit_peak_A   = Ilim_pq;
S2_API.rating.S_VA         = [6.25e6, S_pcs_pq, S_pcs_pq];
S2_API.coordinator_config(9:11) = [6.25e6, S_pcs_pq, S_pcs_pq];

assignin('base', 'S1', S1);
assignin('base', 'S21', S21);
assignin('base', 'W1', W1);
assignin('base', 'S2_API', S2_API);

% Pre-fault renewable dispatch
set_param([pvCmd '/P Base Limit'], 'UpperLimit', '2.5e6');
set_param([pvCmd '/P Increment'], 'Time', '10.0', 'Before', '0', 'After', '0');
set_param([pvCmd '/Q Base Command'], 'Value', '0');
set_param([pvCmd '/Q Increment'], 'Time', '10.0', 'After', '0');

set_param([windCmd '/P Available Base'], 'Value', '3.5e6');
set_param([windCmd '/P Available Increment'], 'Time', '10.0', 'Before', '0', 'After', '0');
set_param([windCmd '/P Base Limit'], 'UpperLimit', '3.0e6');
set_param([windCmd '/P Increment'], 'Time', '10.0', 'Before', '0', 'After', '0');
set_param([windCmd '/Q Base Command'], 'Value', '0');
set_param([windCmd '/Q Increment'], 'Time', '10.0', 'After', '0');

% Base load 4.8 MW + j1.2 Mvar
set_param([loadSys '/Adjusted_Island_Load'], 'active_power', '4.8e6', 'reactive_power', '1.2e6');

set_param([loadSys '/Load_Step_Command'], 'Time', '0.50', 'Before', '1', 'After', '0');
fcBlk  = [loadSys '/Fault_Clear'];
sumBlk = [loadSys '/Trip_Sum'];
if getSimulinkBlockHandle(fcBlk) < 0
    add_block('simulink/Sources/Step', fcBlk, 'Position', [60 190 90 220], ...
        'Time', '0.70', 'Before', '0', 'After', '1', 'SampleTime', '0');
    add_block('simulink/Math Operations/Add', sumBlk, 'Position', [125 140 155 175], 'Inputs', '++');
    try, delete_line(loadSys, 'Load_Step_Command/1', 'Load_Step_to_PS/1'); catch, end
    add_line(loadSys, 'Load_Step_Command/1', 'Trip_Sum/1', 'autorouting', 'on');
    add_line(loadSys, 'Fault_Clear/1', 'Trip_Sum/2', 'autorouting', 'on');
    add_line(loadSys, 'Trip_Sum/1', 'Load_Step_to_PS/1', 'autorouting', 'on');
else
    set_param(fcBlk, 'Time', '0.70', 'Before', '0', 'After', '1');
end
end

function insert_feeder_impedances_local(model)
bessPH = get_param([model '/02 GFM PCS and Step-up'], 'PortHandles');
pvPH   = get_param([model '/03 PV-GFL Branch'], 'PortHandles');
windPH = get_param([model '/04 Wind-GFL Branch'], 'PortHandles');
loadPH = get_param([model '/05 Island Load'], 'PortHandles');

conns = [bessPH.RConn(1), pvPH.RConn(1), windPH.RConn(1), loadPH.LConn(1)];
for k = 1:numel(conns)
    ln = get_param(conns(k), 'Line');
    if ln > 0, try, delete_line(ln); catch, end; end
end

protoRL = [model '/02 GFM PCS and Step-up/04 PCS Filter and Transformer/LCL_L1'];
feederNames = {'Z_BESS_Feeder', 'Z_PV_Feeder', 'Z_Wind_Feeder'};
srcPorts    = [bessPH.RConn(1), pvPH.RConn(1), windPH.RConn(1)];
posList     = {[655 245 695 275], [1025 255 1065 285], [1025 580 1065 610]};

Z_base = 10.0; XR = 5.0; w0 = 2*pi*50;
z_asym = [0.02, 0.08, 0.20];

for r = 1:3
    fBlk = [model '/' feederNames{r}];
    if getSimulinkBlockHandle(fBlk) < 0
        add_block(protoRL, fBlk, 'Position', posList{r});
    end
    Z_ohm = z_asym(r) * Z_base;
    R_ohm = Z_ohm / sqrt(1.0 + XR*XR);
    X_ohm = R_ohm * XR;
    L_H   = X_ohm / w0;
    set_param(fBlk, 'R', num2str(R_ohm, 12), 'L', num2str(L_H, 12));
    fPH = get_param(fBlk, 'PortHandles');
    if get_param(fPH.LConn(1), 'Line') > 0
        try, delete_line(get_param(fPH.LConn(1), 'Line')); catch, end
    end
    if get_param(fPH.RConn(1), 'Line') > 0
        try, delete_line(get_param(fPH.RConn(1), 'Line')); catch, end
    end
    add_line(model, srcPorts(r), fPH.LConn(1), 'autorouting', 'on');
    add_line(model, fPH.RConn(1), loadPH.LConn(1), 'autorouting', 'on');
end
end
