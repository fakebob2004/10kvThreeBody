% rebuild_stage2_r2023b.m
% Rebuild and fix R2023b compatibility for BESS_PV_WIND_STAGE2_R2_API

function rebuild_stage2_r2023b()
    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(root);
    addpath(fullfile(root, 'scripts'));
    setup_v2_paths;

    stage2Model = 'BESS_PV_WIND_STAGE2_R2_API';
    r2023bDir = fullfile(root, 'build', 'r2023b');
    slxPath = fullfile(r2023bDir, [stage2Model '.slx']);

    run(fullfile(root, 'scripts', 'init_bess_pv_wind_stage2_r1.m'));
    define_stage2_resource_api();

    if bdIsLoaded(stage2Model), close_system(stage2Model, 0); end
    load_system(slxPath);
    load_system('ee_lib');

    % 1. Set robust InitFcn
    set_param(stage2Model, 'InitFcn', 'init_bess_pv_wind_stage2_r1;');

    % 2. Define native library blocks
    bGround = sprintf('ee_lib/Connectors &\nReferences/Grounded Neutral\n(Three-Phase)');
    bSensor = sprintf('ee_lib/Sensors &\nTransducers/Current and Voltage\nSensor (Three-Phase)');
    bBreaker = sprintf('ee_lib/Switches & Breakers/Circuit Breaker\n(Three-Phase)');

    % 3. Replace Grounds
    replace_ground([stage2Model '/02 GFM PCS and Step-up/04 PCS Filter and Transformer/Filter_Ground'], bGround);
    replace_ground([stage2Model '/03 PV-GFL Branch/01 GFL PCS/02 Primary Converter and Filter/Filter Ground'], bGround);
    replace_ground([stage2Model '/04 Wind-GFL Branch/03 GFL PCS/02 Primary Converter and Filter/Filter Ground'], bGround);

    % 4. Replace Converter-Side VI Sensors
    replace_converter_sensor([stage2Model '/03 PV-GFL Branch/01 GFL PCS/02 Primary Converter and Filter'], bSensor);
    replace_converter_sensor([stage2Model '/04 Wind-GFL Branch/03 GFL PCS/02 Primary Converter and Filter'], bSensor);

    % 5. Replace PCC 10kV VI Sensors
    replace_pcc_sensor([stage2Model '/03 PV-GFL Branch/02 Step-up and PCC'], bSensor, 'T_PV_0p69_10kV', 'PV PCC Power Sensor');
    replace_pcc_sensor([stage2Model '/04 Wind-GFL Branch/04 Step-up and PCC'], bSensor, 'T_Wind_0p69_10kV', 'Wind PCC Power Sensor');

    % 6. Replace Breaker
    replace_breaker([stage2Model '/05 Island Load'], bBreaker);

    % 7. Configure Coordinator MATLAB Function block to DISCRETE rate in R2023b
    mf = [stage2Model '/07 Resource API Layer/MATLAB Function Coordinator'];
    rt = sfroot;
    chart = find(rt, '-isa', 'Stateflow.EMChart', 'Path', mf);
    if ~isempty(chart)
        chart.ChartUpdate = 'DISCRETE';
        chart.SampleTime = 'S2_API.sample_time_s';
        fprintf('Configured Coordinator MATLAB Function block to DISCRETE rate (Ts=%s)\n', chart.SampleTime);
    end

    % 7b. Configure Simulink-PS Converter filtering for controlled current sources
    psBlks = { ...
        [stage2Model '/03 PV-GFL Branch/01 GFL PCS/02 Primary Converter and Filter/Current Command to PS'], ...
        [stage2Model '/04 Wind-GFL Branch/03 GFL PCS/02 Primary Converter and Filter/Current Command to PS'] ...
    };
    for k = 1:numel(psBlks)
        try
            set_param(psBlks{k}, 'FilteringAndDerivatives', 'filter');
            set_param(psBlks{k}, 'SimscapeFilterOrder', '1');
            set_param(psBlks{k}, 'InputFilterTimeConstant', '1e-4');
            fprintf('Configured input filtering on %s\n', psBlks{k});
        catch me
            fprintf('Note configuring PS filter (%s): %s\n', psBlks{k}, me.message);
        end
    end

    % 8. Test model update in R2023b
    fprintf('--- Compiling model update in R2023b ---\n');
    set_param(stage2Model, 'SimulationCommand', 'update');
    fprintf('MODEL_UPDATE_PASSED_CLEANLY=1\n');

    % 9. Save repaired model
    save_system(stage2Model, slxPath);
    fprintf('SAVED_REPAIRED_R2023B_MODEL=%s\n', slxPath);
    close_system(stage2Model, 0);
end

function replace_ground(blk, sourceLibBlock)
    if isempty(find_system(bdroot(blk), 'SearchDepth', 10, 'FollowLinks', 'on', 'Name', get_param(blk, 'Name')))
        return;
    end
    parentSys = get_param(blk, 'Parent');
    pos = get_param(blk, 'Position');
    ph = get_param(blk, 'PortHandles');
    
    dstPort = [];
    if ~isempty(ph.LConn)
        ln = get_param(ph.LConn(1), 'Line');
        if ln > 0
            src = get_param(ln, 'SrcPortHandle');
            dst = get_param(ln, 'DstPortHandle');
            allP = [src(:); dst(:)];
            allP = allP(allP ~= ph.LConn(1) & allP > 0);
            dstPort = allP;
            delete_line(ln);
        end
    end
    delete_block(blk);
    add_block(sourceLibBlock, blk, 'Position', pos);
    newPh = get_param(blk, 'PortHandles');
    for k = 1:numel(dstPort)
        add_line(parentSys, newPh.LConn(1), dstPort(k), 'autorouting', 'on');
    end
end

function replace_converter_sensor(subsys, sourceLibBlock)
    sensorBlk = [subsys '/Converter-Side VI Sensor'];
    if isempty(find_system(bdroot(subsys), 'SearchDepth', 10, 'FollowLinks', 'on', 'Name', 'Converter-Side VI Sensor'))
        return;
    end
    pos = get_param(sensorBlk, 'Position');
    ph = get_param(sensorBlk, 'PortHandles');
    for f = {'LConn', 'RConn'}
        for p = 1:numel(ph.(f{1}))
            ln = get_param(ph.(f{1})(p), 'Line');
            if ln > 0, delete_line(ln); end
        end
    end
    delete_block(sensorBlk);
    add_block(sourceLibBlock, sensorBlk, 'Position', pos);
    set_param(sensorBlk, 'vMeasurementType', 'ee.enum.vmeasurement.ll', 'outputUnit', 'ee.enum.unit.si');

    newPh = get_param(sensorBlk, 'PortHandles');
    injPH = get_param([subsys '/Average GFL Current Injection'], 'PortHandles');
    rlPH = get_param([subsys '/Interface RL'], 'PortHandles');
    vpsPH = get_param([subsys '/vabc to Simulink'], 'PortHandles');
    ipsPH = get_param([subsys '/iabc to Simulink'], 'PortHandles');

    add_line(subsys, injPH.RConn(1), newPh.LConn(1), 'autorouting', 'on');
    add_line(subsys, newPh.RConn(3), rlPH.LConn(1), 'autorouting', 'on');
    add_line(subsys, newPh.RConn(1), vpsPH.LConn(1), 'autorouting', 'on');
    add_line(subsys, newPh.RConn(2), ipsPH.LConn(1), 'autorouting', 'on');
end

function replace_pcc_sensor(subsys, sourceLibBlock, xfName, pqName)
    sensorBlk = [subsys '/PCC 10kV VI Sensor'];
    if isempty(find_system(bdroot(subsys), 'SearchDepth', 10, 'FollowLinks', 'on', 'Name', 'PCC 10kV VI Sensor'))
        return;
    end
    pos = get_param(sensorBlk, 'Position');
    ph = get_param(sensorBlk, 'PortHandles');
    for f = {'LConn', 'RConn'}
        for p = 1:numel(ph.(f{1}))
            ln = get_param(ph.(f{1})(p), 'Line');
            if ln > 0, delete_line(ln); end
        end
    end
    delete_block(sensorBlk);
    add_block(sourceLibBlock, sensorBlk, 'Position', pos);
    set_param(sensorBlk, 'vMeasurementType', 'ee.enum.vmeasurement.ll', 'outputUnit', 'ee.enum.unit.si');

    newPh = get_param(sensorBlk, 'PortHandles');
    xfPH = get_param([subsys '/' xfName], 'PortHandles');
    pqPH = get_param([subsys '/' pqName], 'PortHandles');
    vpsPH = get_param([subsys '/PCC vabc to Simulink'], 'PortHandles');
    ipsPH = get_param([subsys '/PCC iabc to Simulink'], 'PortHandles');

    add_line(subsys, xfPH.RConn(1), newPh.LConn(1), 'autorouting', 'on');
    add_line(subsys, newPh.RConn(3), pqPH.LConn(1), 'autorouting', 'on');
    add_line(subsys, newPh.RConn(1), vpsPH.LConn(1), 'autorouting', 'on');
    add_line(subsys, newPh.RConn(2), ipsPH.LConn(1), 'autorouting', 'on');
end

function replace_breaker(subsys, sourceLibBlock)
    breakerBlk = [subsys '/Step_Load_Breaker'];
    if isempty(find_system(bdroot(subsys), 'SearchDepth', 10, 'FollowLinks', 'on', 'Name', 'Step_Load_Breaker'))
        return;
    end
    pos = get_param(breakerBlk, 'Position');
    ph = get_param(breakerBlk, 'PortHandles');
    for f = {'LConn', 'RConn'}
        for p = 1:numel(ph.(f{1}))
            ln = get_param(ph.(f{1})(p), 'Line');
            if ln > 0, delete_line(ln); end
        end
    end
    delete_block(breakerBlk);
    add_block(sourceLibBlock, breakerBlk, 'Position', pos);
    set_param(breakerBlk, 'R_closed', '0.001', 'G_open', '1e-6', 'threshold', '0.5');

    newPh = get_param(breakerBlk, 'PortHandles');
    psSource = get_param([subsys '/Load_Step_to_PS'], 'PortHandles');
    adjLoad = get_param([subsys '/Adjusted_Island_Load'], 'PortHandles');
    loadTarget = get_param([subsys '/One_MW_Step_Load'], 'PortHandles');

    add_line(subsys, psSource.RConn(1), newPh.LConn(1), 'autorouting', 'on');
    add_line(subsys, adjLoad.LConn(1), newPh.LConn(2), 'autorouting', 'on');
    add_line(subsys, newPh.RConn(1), loadTarget.LConn(1), 'autorouting', 'on');
end
