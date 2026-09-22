% Structural acceptance for the readability-only Stage-1 R1.1 derivative.
scriptDir=fileparts(mfilename('fullpath'));root=fileparts(scriptDir);
model='BESS_GFM_PV_GFL_Stage1_R1_1_Readable';
file=fullfile(root,'build',[model '.slx']);load_system(file);
pv=[model '/03 PV-GFL Branch'];pcs=[pv '/01 GFL PCS'];
sec=[pcs '/01 Secondary Control'];pri=[pcs '/02 Primary Converter and Filter'];
step=[pv '/02 Step-up and PCC'];

check_boundary(pv,1,1,1);
check_boundary(pcs,1,1,1);
check_boundary(step,0,0,2);
assert_blocks(sec,{'CommandBus','01 Local SRF-PLL', ...
    '02 Current Command Generation','03 Status Assembly','StatusBus'});
top=find_system(sec,'SearchDepth',1,'Type','Block');
top=top(~strcmp(top,sec));
allowed={'CommandBus','01 Local SRF-PLL','02 Current Command Generation', ...
    '03 Status Assembly','StatusBus'};
assert(all(ismember(cellfun(@(b)get_param(b,'Name'),top,'UniformOutput',false),allowed)), ...
    'Secondary Control first level contains historical loose blocks.');

pm=find_system(step,'SearchDepth',1,'BlockType','PMIOPort');
assert(numel(pm)==2&&all(ismember({'AC_690V','PCC_10kV'}, ...
    cellfun(@(b)get_param(b,'Name'),pm,'UniformOutput',false))), ...
    'Step-up conserving ports are not deterministic.');
check_connected_ports(pv);

assert(strcmp(get_param([pri '/AC_690V'],'BlockType'),'PMIOPort'), ...
    'Primary AC_690V is not a physical conserving port.');
assert(strcmp(get_param([step '/AC_690V'],'BlockType'),'PMIOPort')&& ...
    strcmp(get_param([step '/PCC_10kV'],'BlockType'),'PMIOPort'), ...
    'Step-up physical port types are invalid.');

set_param(model,'SimulationCommand','update');
fprintf(['STAGE1_R1_1_STRUCTURE_PASS=1\n' ...
    'PV_BOUNDARY=1_IN_1_OUT_1_PMIO\nPCS_BOUNDARY=1_IN_1_OUT_1_PMIO\n' ...
    'STEPUP_BOUNDARY=0_IN_0_OUT_2_PMIO\nSECONDARY_FUNCTIONAL_BLOCKS=3\n']);
close_system(model,0);

function check_boundary(sys,ni,no,np)
ph=get_param(sys,'PortHandles');
assert(numel(ph.Inport)==ni&&numel(ph.Outport)==no&& ...
    numel([ph.LConn ph.RConn])==np,['Boundary mismatch: ' sys]);
end

function assert_blocks(parent,names)
for k=1:numel(names)
    assert(getSimulinkBlockHandle([parent '/' names{k}])>0,['Missing block: ' names{k}]);
end
end

function check_connected_ports(root)
ports=find_system(root,'LookUnderMasks','all','RegExp','on', ...
    'BlockType','(Inport|Outport|PMIOPort)');
for k=1:numel(ports)
    ph=get_param(ports{k},'PortHandles');
    if strcmp(get_param(ports{k},'BlockType'),'Inport'), candidates=ph.Outport;
    elseif strcmp(get_param(ports{k},'BlockType'),'Outport'), candidates=ph.Inport;
    else,candidates=[ph.LConn ph.RConn];
    end
    assert(~isempty(candidates)&&any(arrayfun(@(p)get_param(p,'Line')>0,candidates)), ...
        ['Unconnected boundary port: ' ports{k}]);
end
end
