%VALIDATE_WIND_COURSE_SPWM_R2 Structural and switching smoke checks.
root=fileparts(fileparts(mfilename('fullpath')));
model='Wind_DirectDrive_SPWM_R2';
modelFile=fullfile(root,'build',[model '.slx']);
assert(isfile(modelFile),'Missing model: %s',modelFile);
load_system(modelFile);
cleanupModel=onCleanup(@() closeIfLoaded(model));

required={ ...
    '01 Wind Turbine Aerodynamics', ...
    '02 PMSG and MSC Average Model', ...
    '03 DC Link and Two-Level GSC', ...
    '04 GFL Control and SPWM', ...
    '05 Filter Transformer and PCC', ...
    '06 Grid Equivalent and Source'};
for k=1:numel(required)
    assert(getSimulinkBlockHandle([model '/' required{k}])>0, ...
        'Missing top-level subsystem: %s',required{k});
end
assertPortOnSide([model '/01 Wind Turbine Aerodynamics'],'Inport',1,'RIGHT');
assertPortOnSide([model '/02 PMSG and MSC Average Model'],'Outport',1,'LEFT');
assertPortOnSide([model '/04 GFL Control and SPWM'],'Inport',1,'RIGHT');
assertPortOnSide([model '/04 GFL Control and SPWM'],'RConn',1,'RIGHT');
ctrl=[model '/04 GFL Control and SPWM'];
assert(getSimulinkBlockHandle([ctrl '/Converter Voltage abc'])<0, ...
    'Unused converter-voltage source must not remain in the controller.');
assertShortPhysicalConnection([ctrl '/06 SPWM and Physical Gate Interface'], ...
    [ctrl '/Gate Drive'],80);
dc=[model '/03 DC Link and Two-Level GSC'];
dcCtrl=[dc '/DC Control and Monitoring'];
assert(getSimulinkBlockHandle(dcCtrl)>0,'DC control/monitoring subsystem is missing.');
assert(getSimulinkBlockHandle([dcCtrl '/Sampled Vdc'])>0, ...
    'Sampled Vdc monitor output is missing.');
assert(getSimulinkBlockHandle([dcCtrl '/Brake Current'])>0, ...
    'Brake-current monitor output is missing.');
assert(getSimulinkBlockHandle([dc '/Vdc_Meas Tag'])<0, ...
    'The upper-level Vdc tag must be hidden inside DC control.');
assert(strcmp(get_param([dc '/Precharge Disconnect Switch'],'Orientation'),'down'), ...
    'Precharge switch is not parallel with the positive DC rail.');
assert(strcmp(get_param([dc '/DC-Link Capacitor'],'Orientation'),'down'), ...
    'DC-link capacitor must remain vertical across the rails.');
assert(strcmp(get_param([dc '/Vdc Sensor'],'Orientation'),'down'), ...
    'Vdc sensor must remain vertical across the rails.');
assert(strcmp(get_param([dc '/Gate Drive'],'Orientation'),'left'), ...
    'Gate Drive must face the bridge for a short connection.');
assertShortPhysicalConnection([dc '/Gate Drive'],[dc '/Two-Level Three-Phase Bridge'],80);
assertShortPhysicalConnection([dc '/Converter AC Measurement'], ...
    [dc '/Two-Level Three-Phase Bridge'],80);
assertShortPhysicalConnection([dc '/Vdc Sensor'],[dc '/Vdc to Simulink'],250);
iface=[model '/05 Filter Transformer and PCC'];
assertShortPhysicalConnection([iface '/From_VSC'],[iface '/AC Filter Rf + Lf'],60);
assertShortPhysicalConnection([iface '/AC Filter Rf + Lf'], ...
    [iface '/0.69 kV to 10 kV Step-Up Transformer'],80);
assertShortPhysicalConnection([iface '/0.69 kV to 10 kV Step-Up Transformer'], ...
    [iface '/PCC VI Sensor'],85);
assertShortPhysicalConnection([iface '/PCC VI Sensor'], ...
    [iface '/Vabc PCC to Simulink'],40);
assertShortPhysicalConnection([iface '/PCC VI Sensor'], ...
    [iface '/Iabc PCC to Simulink'],40);
grid=[model '/06 Grid Equivalent and Source'];
gridSource=[grid '/Ideal Three-Phase Grid Source'];
assert(strcmp(get_param(gridSource,'Orientation'),'left'), ...
    'Ideal grid source must face the explicit grid impedance.');
assert(strcmp(get_param(gridSource,'impedance_option'),'0'), ...
    'Ideal grid source internal impedance must remain disabled.');
assertShortPhysicalConnection([grid '/From_PCC'], ...
    [grid '/Grid Equivalent Rg + Lg'],45);
assertShortPhysicalConnection([grid '/Grid Equivalent Rg + Lg'], ...
    gridSource,60);
assertShortPhysicalConnection(gridSource,[grid '/Grid Neutral Ground'],75);
limiter=[ctrl '/04 Circular Current Limiter'];
assert(getSimulinkBlockHandle([limiter '/Id Raw Distribution'])>0 && ...
    getSimulinkBlockHandle([limiter '/Iq Raw Distribution'])>0, ...
    'Limiter local raw-current distribution is missing.');
inner=[ctrl '/05 dq Current Controller'];
assert(getSimulinkBlockHandle([inner '/Theta Distribution'])>0, ...
    'Current-controller local theta distribution is missing.');
pwm=[ctrl '/06 SPWM and Physical Gate Interface'];
assertShortSignalConnection([pwm '/Vabc mod'], ...
    [pwm '/Digital PWM Delay'],80);
assertShortSignalConnection([pwm '/Triangular Carrier'], ...
    [pwm '/Carrier Distribution'],180);
assert(getSimulinkBlockHandle([pwm '/Carrier Comparison PWM'])<0 && ...
    getSimulinkBlockHandle([pwm '/Six-Gate Physical Interface'])<0, ...
    'PWM comparison and physical gate wrappers must remain flattened.');
assert(getSimulinkBlockHandle([pwm '/Compare Phase A'])>0 && ...
    getSimulinkBlockHandle([pwm '/Gate 6 to Physical Signal'])>0 && ...
    getSimulinkBlockHandle([pwm '/Six-Pulse Gate Multiplexer'])>0, ...
    'Flattened PWM or physical gate chain is incomplete.');
assert(getSimulinkBlockHandle([pwm '/Converter Gate Order [AH AL BH BL CH CL]'])<0 && ...
    getSimulinkBlockHandle([pwm '/Six Gate Signals'])<0, ...
    'Redundant gate-vector Mux/Demux pair must remain removed.');
assert(getSimulinkBlockHandle([ctrl '/PLL Diagnostics'])<0 && ...
    getSimulinkBlockHandle([ctrl '/Measurement Diagnostics'])<0, ...
    'Controller-level diagnostic wrapper subsystems must remain removed.');
meas=[ctrl '/01 Measurements and dq'];
pll=[ctrl '/02 Synchronization SRF-PLL'];
assert(isempty(find_system(meas,'SearchDepth',1,'BlockType','Outport')) && ...
    isempty(find_system(pll,'SearchDepth',1,'BlockType','Outport')), ...
    '01/02 diagnostic signals must remain internal rather than exposed ports.');
assert(isempty(find_system(model,'LookUnderMasks','all', ...
    'FollowLinks','on','BlockType','MATLABSystem')), ...
    'MATLAB System blocks are not allowed in the course baseline.');
assert(isempty(find_system(model,'LookUnderMasks','all', ...
    'FollowLinks','on','BlockType','SubSystem','SFBlockType','MATLAB Function')), ...
    'MATLAB Function blocks are not allowed in the course baseline.');

set_param(model,'SimulationCommand','update');
set_param(model,'StopTime','0.008');
out=sim(model);
logs=out.logsout;
gateNames={'Gate_AH','Gate_AL','Gate_BH','Gate_BL','Gate_CH','Gate_CL'};
g=[];
for k=1:numel(gateNames)
    gateTs=firstTimeseries(logs,gateNames{k});
    if isempty(g),g=zeros(numel(gateTs.Data),numel(gateNames));end
    g(:,k)=gateTs.Data(:);
end
vdc=firstTimeseries(logs,'Vdc_Meas');
assert(isequal(unique(g(:)).',[0 1]),'Gate pulses are not binary.');
% Converter gate vector is [AH AL BH BL CH CL].
complementError=max(abs(g(:,1)+g(:,2)-1))+ ...
    max(abs(g(:,3)+g(:,4)-1))+ ...
    max(abs(g(:,5)+g(:,6)-1));
assert(complementError==0,'Bridge gate pairs are not complementary.');
tail=vdc.Data(vdc.Time>=0.006);
assert(~isempty(tail) && all(isfinite(tail)),'Vdc log is invalid.');
assert(mean(tail)>1400 && mean(tail)<1600, ...
    'DC support stage is outside 1400-1600 V.');

fprintf('WIND_COURSE_STRUCTURE_OK=1\n');
fprintf('WIND_COURSE_PORT_LAYOUT_OK=1\n');
fprintf('WIND_COURSE_SWITCHING_SMOKE_OK=1\n');
fprintf('GATE_COMPLEMENT_ERROR=%.9g\n',complementError);
fprintf('VDC_6_TO_8MS_MEAN_V=%.9g\n',mean(tail));
clear cleanupModel

function ts=firstTimeseries(logs,name)
for k=1:logs.numElements
    element=logs{k};
    if strcmp(element.Name,name) && isa(element.Values,'timeseries')
        ts=element.Values;
        return
    end
end
error('Logged timeseries not found: %s',name);
end

function closeIfLoaded(model)
if bdIsLoaded(model),close_system(model,0);end
end

function assertPortOnSide(blockPath,kind,index,side)
blockPos=get_param(blockPath,'Position');
ports=get_param(blockPath,'PortHandles');
assert(numel(ports.(kind))>=index,'%s %s %d is missing.',blockPath,kind,index);
portPos=get_param(ports.(kind)(index),'Position');
switch side
    case 'LEFT'
        ok=portPos(1)<blockPos(1);
    case 'RIGHT'
        ok=portPos(1)>blockPos(3);
    case 'TOP'
        ok=portPos(2)<blockPos(2);
    case 'BOTTOM'
        ok=portPos(2)>blockPos(4);
    otherwise
        error('Unknown side: %s',side);
end
assert(ok,'%s %s %d is not on the %s side.',blockPath,kind,index,side);
end

function assertShortPhysicalConnection(blockA,blockB,maxLength)
portsA=get_param(blockA,'PortHandles');
handles=[portsA.LConn portsA.RConn];
found=false;
for port=handles
    line=get_param(port,'Line');
    if isempty(line)||line<0,continue,end
    destinations=get_param(line,'DstPortHandle');
    source=get_param(line,'SrcPortHandle');
    connected=[source destinations(:).'];
    for other=connected
        if other>0 && strcmp(get_param(other,'Parent'),blockB)
            points=get_param(line,'Points');
            length=sum(sum(abs(diff(points,1,1)),2));
            assert(length<=maxLength, ...
                'Physical connection between %s and %s is too long.',blockA,blockB);
            found=true;
            break
        end
    end
    if found,break,end
end
assert(found,'Physical connection between %s and %s was not found.',blockA,blockB);
end

function assertShortSignalConnection(blockA,blockB,maxLength)
portsA=get_param(blockA,'PortHandles');
lines=[];
for port=[portsA.Inport portsA.Outport]
    line=get_param(port,'Line');
    if line>0,lines(end+1)=line;end %#ok<AGROW>
end
found=false;
for line=unique(lines)
    src=get_param(line,'SrcPortHandle');
    destinations=get_param(line,'DstPortHandle');
    connected=[src destinations(:).'];
    if any(arrayfun(@(h)h>0&&strcmp(get_param(h,'Parent'),blockB),connected))
        points=get_param(line,'Points');
        length=sum(sum(abs(diff(points,1,1)),2));
        assert(length<=maxLength, ...
            'Signal connection between %s and %s is too long.',blockA,blockB);
        found=true;
        break
    end
end
assert(found,'Signal connection between %s and %s was not found.',blockA,blockB);
end
