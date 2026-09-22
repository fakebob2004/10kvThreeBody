% Create an independent R2026a Average-VSC GFL commissioning model.
% Inputs are copied subsystems only; the resulting SLX has no runtime link
% to R8, MYVSC, the teammate SLX, or the reference project.
scriptDir=fileparts(mfilename('fullpath')); root=fileparts(scriptDir);
smSource=fullfile(root,'build','PV_GFL_Strong_SM_Commissioning.slx');
pvSource=fullfile(root,'build','BESS_GFM_PV_GFL_10kV_Stage1.slx');
model='PV_GFL_864_Average_SM_R1';
modelFile=fullfile(root,'build',[model '.slx']);
pngFile=fullfile(root,'build',[model '.png']);
assert(isfile(smSource)&&isfile(pvSource),'Commissioning source artifacts are missing.');
copyfile(smSource,modelFile,'f');
load_system(modelFile); load_system(pvSource); load_system(smSource);
run(fullfile(scriptDir,'init_pv_gfl_864_average_sm.m'));

% Remove the detailed PWM path from the copied strong-grid shell.
old={'01 PV Two-Level VSC','02 GFL Controller - PLL Commissioning', ...
    '03 PV Filter Transformer and PCC'};
for k=1:numel(old)
    p=[model '/' old{k}]; if getSimulinkBlockHandle(p)>0, delete_block(p); end
end

src='BESS_GFM_PV_GFL_10kV_Stage1/03 PV-GFL Branch';
dst=[model '/01 PV-GFL Average Branch (864 Logic)'];
add_block(src,dst,'Position',[210 205 650 500]);
set_param(dst,'BackgroundColor','[0.82,0.94,0.80]', ...
    'AttributesFormatString',sprintf([ ...
    '5 MW / 6.25 MVA | 1295.8 Vdc | 690 V / 10 kV\n' ...
    '864 topology: local PLL - dq - P/Q - current PI\n' ...
    'R2026a Average-VSC; no PWM gate pulses']));

% Replace the early Stage-1 reference-project PLL with the local SRF-PLL
% already validated against this same strong synchronous-machine bus.  The
% subsystem is copied (not library-linked), so the generated model remains
% self-contained.
oldPLL=[dst '/Reference_Project_PLL'];
if getSimulinkBlockHandle(oldPLL)>0,delete_block(oldPLL);end
pllSrc=['PV_GFL_Strong_SM_Commissioning/02 GFL Controller - PLL Commissioning/' ...
    '02 Synchronization SRF-PLL'];
pll=[dst '/02 Local SRF-PLL'];
add_block(pllSrc,pll,'Position',[875 345 1035 440]);
pllPH=get_param(pll,'PortHandles');
attached=unique([arrayfun(@(h)get_param(h,'Line'),pllPH.Inport), ...
    arrayfun(@(h)get_param(h,'Line'),pllPH.Outport)]);
for k=1:numel(attached),if attached(k)>0,delete_line(attached(k));end,end
add_line(dst,'vabc_Sensor_Filter/1','02 Local SRF-PLL/1','autorouting','on');
add_line(dst,'02 Local SRF-PLL/1','PLL_Phase_Inputs/2','autorouting','on');
add_line(dst,'02 Local SRF-PLL/1','DQ_Inputs/3','autorouting','on');
add_line(dst,'02 Local SRF-PLL/1','PLL_Phase_Angle/1','autorouting','on');
add_block('simulink/Math Operations/Gain',[dst '/PLL_omega_to_Hz'], ...
    'Position',[1650 805 1740 835],'Gain','1/(2*pi)');
add_line(dst,'02 Local SRF-PLL/2','PLL_omega_to_Hz/1','autorouting','on');
add_line(dst,'PLL_omega_to_Hz/1','PV_Result_Mux/10','autorouting','on');

% Put the AC sensor at the grid side of the LCL filter.  The first Stage-1
% prototype measured the commanded VSC terminal, which made the PLL and
% voltage feed-forward observe their own output instead of the strong bus.
vscPH=get_param([dst '/PV_Average_VSC'],'PortHandles');
senPH=get_param([dst '/PV_AC_IV_Sensor'],'PortHandles');
l1PH=get_param([dst '/PV_LCL_L1'],'PortHandles');
l2PH=get_param([dst '/PV_LCL_L2'],'PortHandles');
xfPH=get_param([dst '/T_PV_0p69_10kV'],'PortHandles');
oldLines=unique([get_param(vscPH.LConn(2),'Line'), ...
    get_param(senPH.RConn(3),'Line'),get_param(l2PH.RConn(1),'Line')]);
for k=1:numel(oldLines),if oldLines(k)>0,delete_line(oldLines(k));end,end
add_line(dst,vscPH.LConn(2),l1PH.LConn(1),'autorouting','on');
add_line(dst,l2PH.RConn(1),senPH.LConn(1),'autorouting','on');
add_line(dst,senPH.RConn(3),xfPH.LConn(1),'autorouting','on');
set_param([dst '/PV_AC_IV_Sensor'],'Position',[955 125 1045 205]);

% Use measured grid-side dq voltage as decoupling feed-forward.  This is
% the essential zero-current equilibrium; fixed nominal voltage cannot
% preserve it during PLL acquisition or machine-voltage transients.
vdCmdPH=get_param([dst '/Vd_Command'],'PortHandles');
vqCmdPH=get_param([dst '/Vq_Command'],'PortHandles');
delete_line(get_param(vdCmdPH.Inport(1),'Line'));
delete_line(get_param(vqCmdPH.Inport(1),'Line'));
add_line(dst,'Vd/1','Vd_Command/1','autorouting','on');
add_line(dst,'Vq/1','Vq_Command/1','autorouting','on');

sm=[model '/Strong Synchronous Machine (Governor + AVR)'];
set_param(sm,'Position',[835 205 1160 500]);
pvPH=get_param(dst,'PortHandles'); smPH=get_param(sm,'PortHandles');
add_line(model,pvPH.RConn(1),smPH.RConn(1),'autorouting','on');
% The original strong-grid shell kept its Solver Configuration inside the
% grid-interface subsystem removed above.  Promote one solver block to the
% top level so the combined PV/machine network has exactly one solver.
add_block('nesl_utility/Solver Configuration',[model '/Physical Network Solver'], ...
    'Position',[700 420 765 475]);
solverPH=get_param([model '/Physical Network Solver'],'PortHandles');
add_line(model,solverPH.RConn(1),pvPH.RConn(1),'autorouting','on');

anns=find_system(model,'FindAll','on','SearchDepth',1,'Type','annotation');
for k=1:numel(anns),delete(anns(k));end
a=Simulink.Annotation(model,sprintf([ ...
    'PV-GFL commissioning R1 — teammate 864 control structure migrated to R2026a native Average-VSC\n' ...
    'Strong 25 MVA synchronous machine (governor + AVR) supplies the 5 MW local load and establishes the 10 kV / 50 Hz bus.\n' ...
    'Acceptance order: zero-power synchronization, 0 to 2 MW, 2 to 3 MW, then reactive-power step. R8/BESS is not connected.']));
a.Position=[80 35 1290 125]; a.FontSize=14; a.FontWeight='bold';
set_param(model,'PreLoadFcn','');
set_param(model,'InitFcn', ...
    "run(fullfile(fileparts(get_param(bdroot,'FileName')),'..','scripts','init_pv_gfl_864_average_sm.m'));" );
set_param(model,'StopTime','0.20','MaxStep','1e-5','SolverType','Variable-step', ...
    'Solver','ode23t','Location',[60 60 1450 850]);
set_param(model,'ZoomFactor','FitSystem');
save_system(model,modelFile);
set_param(model,'SimulationCommand','update');
save_system(model,modelFile);
try,print(['-s' model],'-dpng',pngFile);catch ME,fprintf('PNG_WARNING=%s\n',ME.message);end
close_system(model,0); close_system('BESS_GFM_PV_GFL_10kV_Stage1',0);
close_system('PV_GFL_Strong_SM_Commissioning',0);
fprintf('PV_GFL_864_AVERAGE_MODEL=%s\n',modelFile);
