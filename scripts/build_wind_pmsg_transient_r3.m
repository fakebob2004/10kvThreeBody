%BUILD_WIND_PMSG_TRANSIENT_R3 Build the derived direct-drive transient model.
% Keeps the accepted R2 DC link, switching GSC and grid interface. Replaces
% only the turbine/MSC source with a two-mass shaft, continuous PMSG dq
% states and an averaged machine-side current controller.

scriptDir=fileparts(mfilename('fullpath')); root=fileparts(scriptDir);
sourceFile=fullfile(root,'build','Wind_DirectDrive_SPWM_R2.slx');
model='Wind_PMSG_Transient_R3'; modelFile=fullfile(root,'build',[model '.slx']);
assert(isfile(sourceFile),'Missing accepted R2 model: %s',sourceFile);
run(fullfile(root,'parameters','init_wind_pmsg_transient_r3.m'));
if bdIsLoaded(model),close_system(model,0);end
copyfile(sourceFile,modelFile,'f'); load_system(modelFile);
initCmd=char("root=fileparts(fileparts(get_param(bdroot,'FileName'))); " + ...
    "run(fullfile(root,'parameters','init_wind_pmsg_transient_r3.m'));");
set_param(model,'InitFcn',initCmd,'StopTime','Base.Simulation.StopTime', ...
    'MaxStep','Base.Simulation.MaxStep','SignalLogging','on', ...
    'SignalLoggingName','logsout','Location',[30 50 1700 930]);

deleteBlockAndLines([model '/01 Wind Turbine Aerodynamics']);
deleteBlockAndLines([model '/02 PMSG and MSC Average Model']);
aero=[model '/01 Wind Turbine Two-Mass Aerodynamics'];
msc=[model '/02 PMSG dq Machine and Average MSC'];
add_block('built-in/Subsystem',aero,'Position',[45 70 350 240], ...
    'BackgroundColor','[0.84,0.94,0.82]','FontWeight','bold','ContentPreviewEnabled','off');
add_block('built-in/Subsystem',msc,'Position',[430 70 735 240], ...
    'BackgroundColor','[0.96,0.91,0.76]','FontWeight','bold','ContentPreviewEnabled','off');
buildTwoMass(aero); buildPMSGMSC(msc);

wire(model,'01 Wind Turbine Two-Mass Aerodynamics/2', ...
    '02 PMSG dq Machine and Average MSC/1','omega_generator_rad_s');
wire(model,'02 PMSG dq Machine and Average MSC/1', ...
    '01 Wind Turbine Two-Mass Aerodynamics/1','T_e_Nm');
wire(model,'02 PMSG dq Machine and Average MSC/2', ...
    '03 DC Link and Two-Level GSC/1','P_msc_W');
wire(model,'02 PMSG dq Machine and Average MSC/2','04 GFL Control and SPWM/1','');

anns=find_system(model,'FindAll','on','SearchDepth',1,'Type','annotation');
if ~isempty(anns),delete(anns);end
note(model,[45 535 1690 590],sprintf([ ...
    'DIRECT-DRIVE PMSG TRANSIENT MODEL — 5 MW / 6.25 MVA\n' ...
    'Cp(lambda) + two-mass shaft -> PMSG dq + average MSC FOC -> physical DC link -> switching GSC -> 10 kV PCC']));
note(model,[50 610 1690 650], ...
    'MSC switching is averaged. Shaft, electromagnetic, current-control, DC-link and grid-side switching transients are retained.');

for n={'wind_speed_mps','P_aero_W','omega_turbine_rad_s', ...
        'omega_generator_rad_s','T_shaft_Nm','T_e_Nm','T_e_ref_Nm', ...
        'PMSG_id_A','PMSG_iq_A','PMSG_id_ref_A','PMSG_iq_ref_A', ...
        'MSC_vd_V','MSC_vq_V','P_msc_W','Vdc_Meas', ...
        'Gate_AH','Gate_AL','Gate_BH','Gate_BL','Gate_CH','Gate_CL','P_PCC','Q_PCC'}
    enableNamedSignalLogging(model,n{1});
end
set_param(model,'Description',[ ...
    'Derived transient model: two-mass direct-drive shaft, explicit PMSG dq ' ...
    'states and average MSC FOC feeding the accepted switching GSC and grid interface.']);
disableSubsystemPreviews(model); save_system(model,modelFile);
set_param(model,'SimulationCommand','update'); save_system(model,modelFile);
close_system(model,0);
fprintf('WIND_PMSG_TRANSIENT_R3_BUILD_OK=1\nMODEL=%s\n',modelFile);

function buildTwoMass(s)
inport(s,'Electromagnetic Torque Te',1,[20 315 50 335]);
outport(s,'Aerodynamic Power',1,[1000 70 1030 90]);
outport(s,'Generator Speed omega_g',2,[1000 280 1030 300]);
outport(s,'Wind Speed',3,[245 105 275 125]);
blk(s,'simulink/Sources/Constant','Initial Wind Speed',[25 30 135 60], ...
    'Value','Wind.wind_initial_mps');
blk(s,'simulink/Sources/Step','Wind Speed Step',[25 90 135 120], ...
    'Time','Wind.wind_step_time_s','Before','0','After','Wind.wind_step_mps');
blk(s,'simulink/Math Operations/Sum','Wind Speed Profile',[175 45 210 115],'Inputs','++');
blk(s,'simulink/Signal Routing/Mux','lambda inputs',[315 45 320 125],'Inputs','2');
blk(s,'simulink/User-Defined Functions/Fcn','Tip-Speed Ratio',[355 60 475 100], ...
    'Expr','2*u(1)*Wind.rotor_radius_m/(u(2)+0.1+abs(u(2)-0.1))');
blk(s,'simulink/User-Defined Functions/Fcn','Cp Curve',[505 60 625 100], ...
    'Expr','Wind.Cp_max*exp(-((u-Wind.lambda_opt)/Wind.Cp_width)^2)');
blk(s,'simulink/Signal Routing/Mux','Power inputs',[655 45 660 125],'Inputs','2');
blk(s,'simulink/User-Defined Functions/Fcn','Aerodynamic Power Equation',[695 60 825 100], ...
    'Expr','0.5*Wind.rho_kg_m3*Wind.rotor_area_m2*u(1)*u(2)^3');
blk(s,'simulink/Discontinuities/Saturation','Power Limit',[855 60 950 100], ...
    'LowerLimit','0','UpperLimit','1.10*Wind.P_rated_W');
blk(s,'simulink/Signal Routing/Mux','Aero Torque inputs',[315 155 320 225],'Inputs','2');
blk(s,'simulink/User-Defined Functions/Fcn','Aerodynamic Torque',[355 170 475 210], ...
    'Expr','2*u(1)/(u(2)+0.2+abs(u(2)-0.2))');
blk(s,'simulink/Continuous/Integrator','Turbine Inertia',[700 170 740 210], ...
    'InitialCondition','PMSG.Init.omega_rad_s');
blk(s,'simulink/Continuous/Integrator','Generator Inertia',[700 270 740 310], ...
    'InitialCondition','PMSG.Init.omega_rad_s');
blk(s,'simulink/Continuous/Integrator','Shaft Twist',[700 365 740 405], ...
    'InitialCondition','PMSG.Init.shaft_angle_rad');
blk(s,'simulink/Signal Routing/Mux','Shaft inputs',[790 180 795 290],'Inputs','3');
blk(s,'simulink/User-Defined Functions/Fcn','Flexible Shaft',[830 215 950 255], ...
    'Expr','Drive.K_shaft_Nm_per_rad*u(1)+Drive.D_shaft_Nms_per_rad*(u(2)-u(3))');
blk(s,'simulink/Signal Routing/Mux','Turbine accel inputs',[510 150 515 240],'Inputs','3');
blk(s,'simulink/User-Defined Functions/Fcn','Turbine Acceleration',[550 175 655 215], ...
    'Expr','(u(1)-u(2)-Drive.B_turbine_Nms_per_rad*u(3))/Drive.J_turbine_kg_m2');
blk(s,'simulink/Signal Routing/Mux','Generator accel inputs',[510 250 515 340],'Inputs','3');
blk(s,'simulink/User-Defined Functions/Fcn','Generator Acceleration',[550 275 655 315], ...
    'Expr','(u(1)-u(2)-Drive.B_generator_Nms_per_rad*u(3))/Drive.J_generator_kg_m2');
blk(s,'simulink/Math Operations/Sum','Shaft Speed Difference',[565 370 600 405],'Inputs','+-');

wire(s,'Initial Wind Speed/1','Wind Speed Profile/1',''); wire(s,'Wind Speed Step/1','Wind Speed Profile/2','');
wire(s,'Wind Speed Profile/1','Wind Speed/1','wind_speed_mps'); wire(s,'Wind Speed Profile/1','lambda inputs/2','');
wire(s,'Turbine Inertia/1','lambda inputs/1','omega_turbine_rad_s'); wire(s,'lambda inputs/1','Tip-Speed Ratio/1','');
wire(s,'Tip-Speed Ratio/1','Cp Curve/1',''); wire(s,'Cp Curve/1','Power inputs/1','');
wire(s,'Wind Speed Profile/1','Power inputs/2',''); wire(s,'Power inputs/1','Aerodynamic Power Equation/1','');
wire(s,'Aerodynamic Power Equation/1','Power Limit/1',''); wire(s,'Power Limit/1','Aerodynamic Power/1','P_aero_W');
wire(s,'Power Limit/1','Aero Torque inputs/1',''); wire(s,'Turbine Inertia/1','Aero Torque inputs/2','');
wire(s,'Aero Torque inputs/1','Aerodynamic Torque/1','');
wire(s,'Aerodynamic Torque/1','Turbine accel inputs/1','T_aero_Nm');
wire(s,'Flexible Shaft/1','Turbine accel inputs/2','T_shaft_Nm'); wire(s,'Turbine Inertia/1','Turbine accel inputs/3','');
wire(s,'Turbine accel inputs/1','Turbine Acceleration/1',''); wire(s,'Turbine Acceleration/1','Turbine Inertia/1','');
wire(s,'Flexible Shaft/1','Generator accel inputs/1',''); wire(s,'Electromagnetic Torque Te/1','Generator accel inputs/2','');
wire(s,'Generator Inertia/1','Generator accel inputs/3',''); wire(s,'Generator accel inputs/1','Generator Acceleration/1','');
wire(s,'Generator Acceleration/1','Generator Inertia/1',''); wire(s,'Turbine Inertia/1','Shaft Speed Difference/1','');
wire(s,'Generator Inertia/1','Shaft Speed Difference/2',''); wire(s,'Shaft Speed Difference/1','Shaft Twist/1','');
wire(s,'Shaft Twist/1','Shaft inputs/1',''); wire(s,'Turbine Inertia/1','Shaft inputs/2','');
wire(s,'Generator Inertia/1','Shaft inputs/3',''); wire(s,'Shaft inputs/1','Flexible Shaft/1','');
wire(s,'Generator Inertia/1','Generator Speed omega_g/1','omega_generator_rad_s');
note(s,[45 450 1000 490], ...
    'Jt*dwt=Taero-Tshaft-Bt*wt; Jg*dwg=Tshaft-Te-Bg*wg; d(delta)/dt=wt-wg.');
end

function buildPMSGMSC(s)
% One readable signal-flow sheet; final geometric cleanup is intentionally deferred.
inport(s,'Generator Speed omega_g',1,[20 245 50 265]);
outport(s,'Electromagnetic Torque Te',1,[1120 90 1150 110]);
outport(s,'MSC DC Power',2,[1120 390 1150 410]);
blk(s,'simulink/Signal Routing/From','Measured DC Voltage',[25 360 130 390],'GotoTag','Vdc_Meas');
blk(s,'simulink/Discrete/Unit Delay','Sampled Vdc',[160 355 225 395], ...
    'SampleTime','Control.Ts','InitialCondition','Converter.Vdc_nom');
blk(s,'simulink/User-Defined Functions/Fcn','MPPT Torque Reference',[90 65 250 105], ...
    'Expr','0.5*(Wind.Kopt_Nm_per_rad_s2*u^2+PMSG.torque_limit_Nm-abs(Wind.Kopt_Nm_per_rad_s2*u^2-PMSG.torque_limit_Nm))');
blk(s,'simulink/Sources/Constant','id Reference',[100 125 210 155],'Value','0');
blk(s,'simulink/Math Operations/Gain','Torque to iq',[285 65 400 105], ...
    'Gain','-1/(1.5*PMSG.pole_pairs*PMSG.psi_f_Wb)');
blk(s,'simulink/Discontinuities/Saturation','iq Limit',[430 65 520 105], ...
    'LowerLimit','-PMSG.current_limit_A','UpperLimit','PMSG.current_limit_A');
blk(s,'simulink/Math Operations/Sum','id Error',[285 135 320 175],'Inputs','+-');
blk(s,'simulink/Math Operations/Sum','iq Error',[285 190 320 230],'Inputs','+-');
for a={'d','q'}
    ax=a{1}; y=strcmp(ax,'d')*140+strcmp(ax,'q')*195;
    blk(s,'simulink/Math Operations/Gain',['Kp ' ax],[350 y 410 y+30],'Gain','PMSG.current_Kp');
    blk(s,'simulink/Math Operations/Gain',['Ki ' ax],[350 y+35 410 y+65],'Gain','PMSG.current_Ki');
    blk(s,'simulink/Continuous/Integrator',['Integral ' ax],[440 y+35 480 y+65], ...
        'InitialCondition',['PMSG.Init.v' ax '_pi_V']);
    blk(s,'simulink/Discontinuities/Saturation',['I Limit ' ax],[505 y+35 555 y+65], ...
        'LowerLimit','-PMSG.integrator_limit_V','UpperLimit','PMSG.integrator_limit_V');
    blk(s,'simulink/Math Operations/Sum',['PI ' ax],[585 y 620 y+55],'Inputs','++');
end
blk(s,'simulink/Math Operations/Gain','Electrical Speed',[285 265 390 295],'Gain','PMSG.pole_pairs');
blk(s,'simulink/Signal Routing/Mux','vd inputs',[650 125 655 200],'Inputs','3');
blk(s,'simulink/User-Defined Functions/Fcn','vd Decoupling',[685 145 810 185], ...
    'Expr','u(1)-u(2)*PMSG.Lq_H*u(3)');
blk(s,'simulink/Signal Routing/Mux','vq inputs',[650 215 655 290],'Inputs','3');
blk(s,'simulink/User-Defined Functions/Fcn','vq Decoupling',[685 235 810 275], ...
    'Expr','u(1)+u(2)*(PMSG.Ld_H*u(3)+PMSG.psi_f_Wb)');
blk(s,'simulink/Signal Routing/Mux','Voltage limit inputs',[840 145 845 285],'Inputs','3');
blk(s,'simulink/User-Defined Functions/Fcn','Circular Voltage Scale',[875 190 1025 230], ...
    'Expr','0.5*(1+0.5*PMSG.modulation_max*u(3)/(sqrt(u(1)^2+u(2)^2)+1e-6)-abs(1-0.5*PMSG.modulation_max*u(3)/(sqrt(u(1)^2+u(2)^2)+1e-6)))');
blk(s,'simulink/Math Operations/Product','Limited vd',[1050 145 1080 175]);
blk(s,'simulink/Math Operations/Product','Limited vq',[1050 255 1080 285]);

blk(s,'simulink/Signal Routing/Mux','did inputs',[700 315 705 405],'Inputs','4');
blk(s,'simulink/User-Defined Functions/Fcn','did dt',[740 335 875 375], ...
    'Expr','(u(1)-PMSG.Rs_ohm*u(2)+u(3)*PMSG.Lq_H*u(4))/PMSG.Ld_H');
blk(s,'simulink/Continuous/Integrator','id State',[910 335 950 375],'InitialCondition','PMSG.Init.id_A');
blk(s,'simulink/Signal Routing/Mux','diq inputs',[700 420 705 510],'Inputs','4');
blk(s,'simulink/User-Defined Functions/Fcn','diq dt',[740 440 875 480], ...
    'Expr','(u(1)-PMSG.Rs_ohm*u(2)-u(3)*(PMSG.Ld_H*u(4)+PMSG.psi_f_Wb))/PMSG.Lq_H');
blk(s,'simulink/Continuous/Integrator','iq State',[910 440 950 480],'InitialCondition','PMSG.Init.iq_A');
blk(s,'simulink/Signal Routing/Mux','Torque inputs',[985 345 990 415],'Inputs','2');
blk(s,'simulink/User-Defined Functions/Fcn','Electromagnetic Torque',[1020 360 1090 400], ...
    'Expr','-1.5*PMSG.pole_pairs*(PMSG.psi_f_Wb*u(2)+(PMSG.Ld_H-PMSG.Lq_H)*u(1)*u(2))');
blk(s,'simulink/Signal Routing/Mux','Power inputs',[985 445 990 560],'Inputs','4');
blk(s,'simulink/User-Defined Functions/Fcn','Generated DC Power',[1020 475 1090 515], ...
    'Expr','-1.5*(u(1)*u(3)+u(2)*u(4))*PMSG.msc_efficiency-PMSG.loss_constant_W');
blk(s,'simulink/Discontinuities/Saturation','MSC Power Limit',[1020 530 1090 565], ...
    'LowerLimit','0','UpperLimit','PMSG.Sn_W');

wire(s,'Generator Speed omega_g/1','MPPT Torque Reference/1',''); wire(s,'MPPT Torque Reference/1','Torque to iq/1','T_e_ref_Nm');
wire(s,'Torque to iq/1','iq Limit/1',''); wire(s,'iq Limit/1','iq Error/1','PMSG_iq_ref_A');
wire(s,'id Reference/1','id Error/1','PMSG_id_ref_A'); wire(s,'id State/1','id Error/2','PMSG_id_A'); wire(s,'iq State/1','iq Error/2','PMSG_iq_A');
for a={'d','q'}
    ax=a{1}; err=['i' ax ' Error']; wire(s,[err '/1'],['Kp ' ax '/1'],''); wire(s,[err '/1'],['Ki ' ax '/1'],'');
    wire(s,['Ki ' ax '/1'],['Integral ' ax '/1'],''); wire(s,['Integral ' ax '/1'],['I Limit ' ax '/1'],'');
    wire(s,['Kp ' ax '/1'],['PI ' ax '/1'],''); wire(s,['I Limit ' ax '/1'],['PI ' ax '/2'],'');
end
wire(s,'Generator Speed omega_g/1','Electrical Speed/1','');
wire(s,'PI d/1','vd inputs/1',''); wire(s,'Electrical Speed/1','vd inputs/2',''); wire(s,'iq State/1','vd inputs/3',''); wire(s,'vd inputs/1','vd Decoupling/1','');
wire(s,'PI q/1','vq inputs/1',''); wire(s,'Electrical Speed/1','vq inputs/2',''); wire(s,'id State/1','vq inputs/3',''); wire(s,'vq inputs/1','vq Decoupling/1','');
wire(s,'vd Decoupling/1','Voltage limit inputs/1',''); wire(s,'vq Decoupling/1','Voltage limit inputs/2','');
wire(s,'Measured DC Voltage/1','Sampled Vdc/1',''); wire(s,'Sampled Vdc/1','Voltage limit inputs/3',''); wire(s,'Voltage limit inputs/1','Circular Voltage Scale/1','');
wire(s,'vd Decoupling/1','Limited vd/1',''); wire(s,'Circular Voltage Scale/1','Limited vd/2','');
wire(s,'vq Decoupling/1','Limited vq/1',''); wire(s,'Circular Voltage Scale/1','Limited vq/2','');
wire(s,'Limited vd/1','did inputs/1','MSC_vd_V'); wire(s,'id State/1','did inputs/2',''); wire(s,'Electrical Speed/1','did inputs/3',''); wire(s,'iq State/1','did inputs/4','');
wire(s,'did inputs/1','did dt/1',''); wire(s,'did dt/1','id State/1','');
wire(s,'Limited vq/1','diq inputs/1','MSC_vq_V'); wire(s,'iq State/1','diq inputs/2',''); wire(s,'Electrical Speed/1','diq inputs/3',''); wire(s,'id State/1','diq inputs/4','');
wire(s,'diq inputs/1','diq dt/1',''); wire(s,'diq dt/1','iq State/1','');
wire(s,'id State/1','Torque inputs/1',''); wire(s,'iq State/1','Torque inputs/2',''); wire(s,'Torque inputs/1','Electromagnetic Torque/1','');
wire(s,'Electromagnetic Torque/1','Electromagnetic Torque Te/1','T_e_Nm');
wire(s,'Limited vd/1','Power inputs/1',''); wire(s,'Limited vq/1','Power inputs/2',''); wire(s,'id State/1','Power inputs/3',''); wire(s,'iq State/1','Power inputs/4','');
wire(s,'Power inputs/1','Generated DC Power/1',''); wire(s,'Generated DC Power/1','MSC Power Limit/1',''); wire(s,'MSC Power Limit/1','MSC DC Power/1','P_msc_W');
note(s,[45 610 1120 655], ...
    'dq convention: generating iq < 0 and Te > 0. Voltage commands include cross-coupling and back-EMF feedforward plus circular Vdc limit.');
end

function blk(s,lib,n,pos,varargin),add_block(lib,[s '/' n],'Position',pos,varargin{:});end
function inport(s,n,p,pos),add_block('simulink/Ports & Subsystems/In1',[s '/' n],'Port',num2str(p),'Position',pos);end
function outport(s,n,p,pos),add_block('simulink/Ports & Subsystems/Out1',[s '/' n],'Port',num2str(p),'Position',pos);end
function h=wire(s,a,b,n),h=add_line(s,a,b,'autorouting','on');if ~isempty(n),set_param(h,'Name',n);end,end
function note(s,pos,t),a=Simulink.Annotation(s,t);a.Position=pos;a.FontSize=10;a.ForegroundColor='blue';end
function deleteBlockAndLines(path)
if getSimulinkBlockHandle(path)<0,return,end
p=get_param(path,'PortHandles'); fields={'Inport','Outport','LConn','RConn'}; lines=[];
for f=1:numel(fields),for h=p.(fields{f}),try,ln=get_param(h,'Line');if ln>0,lines(end+1)=ln;end,catch,end,end,end %#ok<AGROW>
if ~isempty(lines),delete_line(unique(lines));end
delete_block(path);
end
function enableNamedSignalLogging(model,name)
lines=find_system(model,'FindAll','on','Type','line');
for k=1:numel(lines)
    if strcmp(get_param(lines(k),'Name'),name)
        src=get_param(lines(k),'SrcPortHandle');
        try,set_param(src,'DataLogging','on','DataLoggingNameMode','Custom','DataLoggingName',name);return,catch,end
    end
end
error('Named log signal not found: %s',name);
end
function disableSubsystemPreviews(model)
b=find_system(model,'LookUnderMasks','all','FollowLinks','on','BlockType','SubSystem');
for k=1:numel(b),try,set_param(b{k},'ContentPreviewEnabled','off');catch,end,end
end
