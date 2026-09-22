% Build a separate PV-GFL commissioning model.  No BESS-GFM is connected.
scriptDir=fileparts(mfilename('fullpath')); root=fileparts(scriptDir);
sourceFile='/Users/fakebob2004/Documents/MYVSC/GFL_Inverter_B2.slx';
referenceFile=fullfile(root,'references','Renewable-Energy-Integration-Simscape-master', ...
    'Models','PVPlant','BatteryStoragePVPlantGFM.slx');
model='PV_GFL_Strong_SM_Commissioning';
modelFile=fullfile(root,'build',[model '.slx']);
pngFile=fullfile(root,'build',[model '.png']);
assert(isfile(sourceFile)&&isfile(referenceFile),'Required reference model is missing.');
copyfile(sourceFile,modelFile,'f');
load_system(modelFile);
run(fullfile(scriptDir,'init_pv_gfl_sm_commissioning.m'));
load_system(referenceFile);

set_param([model '/Two-Level VSC'],'Name','01 PV Two-Level VSC');
set_param([model '/GFL Controller B2'],'Name','02 GFL Controller - PLL Commissioning');
set_param([model '/Grid Interface (Filter XFMR PCC)'], ...
    'Name','03 PV Filter Transformer and PCC');
set_param([model '/02 GFL Controller - PLL Commissioning/05 Open-Loop Modulation and PWM'], ...
    'Name','05 Open-Loop PWM - Current Loop Pending');

gridOld=[model '/Grid Equivalent and Source'];
oldPH=get_param(gridOld,'PortHandles'); oldLine=get_param(oldPH.LConn(1),'Line');
peer=get_param(oldLine,'SrcPortHandle');
if peer==oldPH.LConn(1),peer=get_param(oldLine,'DstPortHandle');end
delete_line(oldLine); delete_block(gridOld);

src=sprintf(['BatteryStoragePVPlantGFM/Conventional Source/Variant Subsystem/' ...
    'Synchronous Machine']);
sm=[model '/Strong Synchronous Machine (Governor + AVR)'];
add_block(src,sm,'Position',[1010 225 1320 410]);
% Scale the copied reference transformer to a transparent 10/10 kV unit.
xf=[sm '/230//24 kV'];
set_param(xf,'SRated','SM.MVA','FRated','Grid.frequency', ...
    'VRated1','Grid.voltage','VRated2','SM.Voltage');
% The copied governor/AVR is discrete; declare its physical-signal outputs
% piecewise constant so the variable-step Simscape solver does not request
% unavailable input derivatives.
psInputs=find_system(sm,'LookUnderMasks','all','FollowLinks','on', ...
    'MaskType',sprintf('Simulink-PS\nConverter'));
for k=1:numel(psInputs)
    if isfield(get_param(psInputs{k},'DialogParameters'),'FilteringAndDerivatives')
        set_param(psInputs{k},'FilteringAndDerivatives','zero');
    end
end
smPH=get_param(sm,'PortHandles');
add_line(model,peer,smPH.RConn(1),'autorouting','on');

set_param(model,'PreLoadFcn','');
set_param(model,'InitFcn', ...
    "run(fullfile(fileparts(get_param(bdroot,'FileName')),'..','scripts','init_pv_gfl_sm_commissioning.m'));" );
set_param(model,'StopTime','Base.Simulation.StopTime','MaxStep','Base.Simulation.MaxStep', ...
    'SolverType','Variable-step','Solver','ode23t', ...
    'Location',[60 60 1450 880]);
anns=find_system(model,'FindAll','on','SearchDepth',1,'Type','annotation');
for k=1:numel(anns),delete(anns(k));end
a=Simulink.Annotation(model,sprintf([ ...
    'GFL commissioning Stage S0 — PV inverter + strong synchronous machine\n' ...
    '25 MVA machine with governor and AVR balances a 5 MW local load. No BESS-GFM is connected.\n' ...
    'Commission order: PLL/measurements -> dq current loop -> P/Q steps -> later three-source synchronization.']));
a.Position=[55 25 1320 110]; a.FontSize=14; a.FontWeight='bold';
save_system(model,modelFile);
set_param(model,'SimulationCommand','update');
save_system(model,modelFile);
try,print(['-s' model],'-dpng',pngFile);catch ME,fprintf('PNG_WARNING=%s\n',ME.message);end
close_system(model,0); close_system('BatteryStoragePVPlantGFM',0);
fprintf('PV_GFL_SM_COMMISSIONING_UPDATE_OK=1\nMODEL=%s\n',modelFile);
