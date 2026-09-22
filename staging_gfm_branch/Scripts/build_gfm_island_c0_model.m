%BUILD_GFM_ISLAND_C0_MODEL Create a readable 5 MW island-load scenario.
root=fileparts(fileparts(mfilename('fullpath')));
addpath(root,fullfile(root,'Parameters'));init_project;
run(fullfile(root,'Parameters','gfm_parameters.m'));
source='GFM_Inverter_C0';model='GFM_Island_Load_C0';
sourceFile=fullfile(root,[source '.slx']);modelFile=fullfile(root,[model '.slx']);
assert(isfile(sourceFile),'Build GFM_Inverter_C0 before the island scenario.');
bdclose('all');load_system(sourceFile);save_system(source,modelFile);close_system(source,0);
load_system(modelFile);

old=[model '/Grid Equivalent and Source'];
oldPorts=get_param(old,'PortHandles');oldLine=get_param(oldPorts.LConn(1),'Line');
if oldLine~=-1,delete_line(oldLine);end
delete_block(old);
loadName='Island Load (5 MW at 10 kV)';
add_block('built-in/Subsystem',[model '/' loadName], ...
    'Position',[1010 245 1280 390],'BackgroundColor','[0.87 1.00 0.87]', ...
    'FontWeight','bold','ContentPreviewEnabled','off');
buildIslandLoad([model '/' loadName]);
gi=get_param([model '/Grid Interface (Filter XFMR PCC)'],'PortHandles');
ld=get_param([model '/' loadName],'PortHandles');
lh=add_line(model,gi.RConn(1),ld.LConn(1),'autorouting','on');
set_param(lh,'Name','PCC_to_Island_Load');

anns=find_system(model,'FindAll','on','SearchDepth',1,'Type','annotation');
if ~isempty(anns),delete(anns);end
annotation(model,[40 215 585 285],sprintf([ ...
    'C0 GFM ISLAND LOAD SCENARIO\n' ...
    'Same converter and controller as GFM_Inverter_C0; external grid is replaced by a 5 MW grounded-wye load.']));
annotation(model,[610 420 1320 470], ...
    'Scenario-only ownership: the load is outside the plant/controller boundary and may be replaced without rewiring GFM internals.');
set_param(model,'PreLoadFcn',sprintf("addpath('%s'); init_project; run(fullfile('%s','Parameters','gfm_parameters.m')); assignin('base','GFM',GFM);", ...
    strrep(root,"'","''"),strrep(root,"'","''")));
set_param(model,'InitFcn', ...
    "init_project; run(fullfile(fileparts(get_param(bdroot,'FileName')),'Parameters','gfm_parameters.m')); assignin('base','GFM',GFM);");
set_param(model,'StopTime','GFM.StopTime','Description', ...
    'Independent 5 MW island-load scenario for the GFM-BESS C0 controller.');
set_param(model,'Location',[30 70 1760 810],'ZoomFactor','FitSystem');
save_system(model,modelFile);set_param(model,'SimulationCommand','update');save_system(model,modelFile);
try,print(['-s' model],'-dpng',fullfile(root,[model '.png']));catch,end
close_system(model,0);fprintf('Created: %s\n',modelFile);

function buildIslandLoad(sys)
add_block('nesl_utility/Connection Port',[sys '/From_PCC'], ...
    'Side','Left','Port','1','Position',[25 145 55 175],'Orientation','right');
add_block('simulink/Sources/Ramp',[sys '/Load Power Ramp'], ...
    'Position',[75 35 175 65], ...
    'slope','(GFM.IslandLoad_P_W-GFM.IslandLoad_Pmin_W)/GFM.IslandLoad_RampDuration_s', ...
    'start','GFM.IslandLoad_RampStart_s','X0','GFM.IslandLoad_Pmin_W');
add_block('simulink/Discontinuities/Saturation',[sys '/Limit 1 kW to 5 MW'], ...
    'Position',[215 30 300 70],'LowerLimit','GFM.IslandLoad_Pmin_W', ...
    'UpperLimit','GFM.IslandLoad_P_W');
add_block('nesl_utility/Simulink-PS Converter',[sys '/P Command to Physical Signal'], ...
    'Position',[340 30 450 70],'Unit','W');
loadLibrary=sprintf('ee_lib/Passive/RLC Assemblies/Wye-Connected\nVariable Load');
add_block(loadLibrary,[sys '/Ramped Resistive Load'], ...
    'Position',[260 120 470 270], ...
    'VRated','GFM.IslandLoad_Vll_V','Pmin','GFM.IslandLoad_Pmin_W');
add_block('ee_lib/Connectors & References/Electrical Reference',[sys '/Load Neutral Ground'], ...
    'Position',[535 230 575 270]);
port=innerPort([sys '/From_PCC']);
loadPorts=get_param([sys '/Ramped Resistive Load'],'PortHandles');
ref=get_param([sys '/Load Neutral Ground'],'PortHandles');
add_line(sys,'Load Power Ramp/1','Limit 1 kW to 5 MW/1','autorouting','on');
add_line(sys,'Limit 1 kW to 5 MW/1','P Command to Physical Signal/1','autorouting','on');
pconv=get_param([sys '/P Command to Physical Signal'],'PortHandles');
add_line(sys,pconv.RConn(1),loadPorts.LConn(1),'autorouting','on');
add_line(sys,port,loadPorts.LConn(2),'autorouting','on');
add_line(sys,loadPorts.RConn(1),ref.LConn(1),'autorouting','on');
annotation(sys,[90 310 620 365],sprintf([ ...
    'Grounded variable resistance: 1 kW initial load, then 0.02-0.07 s ramp to 5 MW at 10 kV.\n' ...
    'The ramp belongs to the test scenario, not to the GFM controller.']));
end

function h=innerPort(path)
ph=get_param(path,'PortHandles');
if ~isempty(ph.LConn),h=ph.LConn(1);else,h=ph.RConn(1);end
end

function annotation(sys,pos,text)
h=Simulink.Annotation(sys,text);h.Position=pos;h.FontSize=10;
end
