%BUILD_WIND_DFIG_AVERAGE_R1 Build a readable averaged-converter DFIG model.
% The model is independent of the accepted direct-drive PMSG branch.
% It uses an explicit synchronous-dq wound-rotor induction-machine model,
% stator-flux-oriented RSC control, a shared physical-energy DC state, and an
% averaged GSC.  No MATLAB Function or switching-carrier block is used.

scriptDir=fileparts(mfilename('fullpath'));root=fileparts(scriptDir);
run(fullfile(root,'parameters','init_wind_dfig_average_r1.m'));
model='Wind_DFIG_Average_R1';
modelFile=fullfile(root,'build',[model '.slx']);
if bdIsLoaded(model),close_system(model,0);end
if isfile(modelFile),delete(modelFile);end
new_system(model);load_system(model);

set_param(model,'Solver','ode23t','SolverType','Variable-step', ...
    'StopTime','DFIG.Simulation.StopTime','MaxStep','DFIG.Simulation.MaxStep', ...
    'SignalLogging','on','SignalLoggingName','logsout', ...
    'InitFcn',char("root=fileparts(fileparts(get_param(bdroot,'FileName'))); " + ...
    "run(fullfile(root,'parameters','init_wind_dfig_average_r1.m'));"), ...
    'Description',['5 MW DFIG wind turbine with explicit dq electromagnetic ' ...
    'states and averaged rotor/grid converters. Stator is directly connected ' ...
    'to the 690 V grid; rotor slip power flows through the shared DC link.']);

add_block('built-in/Subsystem',[model '/01 Wind Turbine and Drive Train'], ...
    'Position',[50 150 300 350],'BackgroundColor','[0.78 0.91 0.78]', ...
    'ContentPreviewEnabled','off');
add_block('built-in/Subsystem',[model '/02 Wound-Rotor DFIG dq Plant'], ...
    'Position',[430 120 720 370],'BackgroundColor','[0.72 0.84 0.96]', ...
    'ContentPreviewEnabled','off');
add_block('built-in/Subsystem',[model '/03 Rotor-Side Average Converter Control'], ...
    'Position',[410 470 735 690],'BackgroundColor','[0.95 0.84 0.52]', ...
    'ContentPreviewEnabled','off');
add_block('built-in/Subsystem',[model '/04 DC Link and Grid-Side Average Converter'], ...
    'Position',[815 465 1135 700],'BackgroundColor','[0.94 0.76 0.62]', ...
    'ContentPreviewEnabled','off');
add_block('built-in/Subsystem',[model '/05 Stator Grid Transformer and PCC'], ...
    'Position',[1215 145 1510 365],'BackgroundColor','[0.82 0.88 0.96]', ...
    'ContentPreviewEnabled','off');
add_block('built-in/Subsystem',[model '/06 Supervisory and Protection Monitors'], ...
    'Position',[1215 500 1510 680],'BackgroundColor','[0.88 0.88 0.88]', ...
    'ContentPreviewEnabled','off');

buildWind([model '/01 Wind Turbine and Drive Train']);
buildMachine([model '/02 Wound-Rotor DFIG dq Plant']);
buildRSC([model '/03 Rotor-Side Average Converter Control']);
buildDCGSC([model '/04 DC Link and Grid-Side Average Converter']);
buildPCC([model '/05 Stator Grid Transformer and PCC']);
buildProtection([model '/06 Supervisory and Protection Monitors']);

% Top-level power/control interfaces.  The upper path is stator power direct
% to the PCC; the lower path is bidirectional rotor slip power through RSC/DC/GSC.
wire(model,'01 Wind Turbine and Drive Train/1','02 Wound-Rotor DFIG dq Plant/3','OmegaGen');
wire(model,'02 Wound-Rotor DFIG dq Plant/3','01 Wind Turbine and Drive Train/1','Te');
wire(model,'01 Wind Turbine and Drive Train/2','03 Rotor-Side Average Converter Control/1','TmCommand');
wire(model,'01 Wind Turbine and Drive Train/1','03 Rotor-Side Average Converter Control/2','');
wire(model,'05 Stator Grid Transformer and PCC/1','02 Wound-Rotor DFIG dq Plant/1','GridVdq');
wire(model,'05 Stator Grid Transformer and PCC/1','04 DC Link and Grid-Side Average Converter/3','');
wire(model,'03 Rotor-Side Average Converter Control/1','02 Wound-Rotor DFIG dq Plant/2','Vrdq');
wire(model,'03 Rotor-Side Average Converter Control/1','04 DC Link and Grid-Side Average Converter/1','');
wire(model,'02 Wound-Rotor DFIG dq Plant/2','03 Rotor-Side Average Converter Control/3','Irdq');
wire(model,'02 Wound-Rotor DFIG dq Plant/2','04 DC Link and Grid-Side Average Converter/2','');
wire(model,'02 Wound-Rotor DFIG dq Plant/5','03 Rotor-Side Average Converter Control/4','Fluxdq');
wire(model,'02 Wound-Rotor DFIG dq Plant/1','05 Stator Grid Transformer and PCC/1','Isdq');
wire(model,'04 DC Link and Grid-Side Average Converter/2','05 Stator Grid Transformer and PCC/2','Igdq');

% Compact diagnostics/protection interface on the lower-right.
wire(model,'04 DC Link and Grid-Side Average Converter/1','06 Supervisory and Protection Monitors/1','Vdc');
wire(model,'03 Rotor-Side Average Converter Control/2','06 Supervisory and Protection Monitors/2','IrReference');
wire(model,'02 Wound-Rotor DFIG dq Plant/2','06 Supervisory and Protection Monitors/3','');
wire(model,'03 Rotor-Side Average Converter Control/3','06 Supervisory and Protection Monitors/4','Slip');
wire(model,'05 Stator Grid Transformer and PCC/2','06 Supervisory and Protection Monitors/5','P_PCC');
wire(model,'05 Stator Grid Transformer and PCC/3','06 Supervisory and Protection Monitors/6','Q_PCC');

% Log useful internal results without exposing additional top-level ports.
logLine(model,'OmegaGen');logLine(model,'Te');logLine(model,'TmCommand');
logLine(model,'GridVdq');logLine(model,'Vrdq');logLine(model,'Irdq');
logLine(model,'Fluxdq');logLine(model,'Isdq');logLine(model,'Igdq');
logLine(model,'Vdc');logLine(model,'IrReference');logLine(model,'Slip');
logLine(model,'P_PCC');logLine(model,'Q_PCC');

note(model,[55 35 1500 92],sprintf([ ...
    '5 MW DFIG average-converter research baseline\n' ...
    'Upper path: stator -> transformer/PCC (direct grid connection).  ' ...
    'Lower path: rotor -> average RSC -> 1200 V DC link -> average GSC -> PCC.']));
note(model,[65 735 1500 790],[ ...
    'The direct-drive PMSG models are not modified.  This branch keeps explicit ' ...
    'flux states, slip, rotor current control, DC energy, current limits, and ' ...
    'protection monitors for later LVRT/crowbar/control-protection studies.']);

save_system(model,modelFile);
set_param(model,'SimulationCommand','update');
save_system(model,modelFile);
renderSystem(model,fullfile(root,'build','WIND_DFIG_R1_01_Top.png'));
renderSystem([model '/01 Wind Turbine and Drive Train'], ...
    fullfile(root,'build','WIND_DFIG_R1_02_Wind_Drive.png'));
renderSystem([model '/02 Wound-Rotor DFIG dq Plant'], ...
    fullfile(root,'build','WIND_DFIG_R1_03_DFIG_Plant.png'));
renderSystem([model '/03 Rotor-Side Average Converter Control'], ...
    fullfile(root,'build','WIND_DFIG_R1_04_RSC.png'));
renderSystem([model '/04 DC Link and Grid-Side Average Converter'], ...
    fullfile(root,'build','WIND_DFIG_R1_05_DC_GSC.png'));
renderSystem([model '/05 Stator Grid Transformer and PCC'], ...
    fullfile(root,'build','WIND_DFIG_R1_06_PCC.png'));
close_system(model,0);
fprintf('WIND_DFIG_AVERAGE_R1_BUILD_OK=1\nMODEL=%s\n',modelFile);

function buildWind(sys)
addIn(sys,'Electromagnetic Torque Te',1,[20 260 50 280]);
addOut(sys,'Generator Speed',1,[930 85 960 105]);
addOut(sys,'Mechanical Torque',2,[930 205 960 225]);
addOut(sys,'Aerodynamic Power',3,[930 325 960 345]);
addOut(sys,'Wind Speed',4,[930 405 960 425]);
addB('simulink/Sources/Step',[sys '/Wind 9 to 10 mps'],[35 70 105 105], ...
    'Time','DFIG.Wind.stepTime','Before','DFIG.Wind.v0', ...
    'After','DFIG.Wind.v0+DFIG.Wind.vStep');
addB('simulink/Math Operations/Math Function',[sys '/Wind Speed Squared'],[145 55 195 105],'Operator','square');
addB('simulink/Math Operations/Product',[sys '/Wind Speed Cubed'],[230 60 275 100],'Inputs','**');
addB('simulink/Math Operations/Gain',[sys '/Tip Speed Numerator'],[150 135 240 170], ...
    'Gain','DFIG.Wind.radius/DFIG.Drive.gearRatio');
addB('simulink/Math Operations/Product',[sys '/Tip Speed Ratio'],[295 125 345 175],'Inputs','*/');
addB('simulink/Sources/Constant',[sys '/Lambda Opt'],[290 205 350 235],'Value','DFIG.Wind.lambdaOpt');
addB('simulink/Math Operations/Sum',[sys '/Lambda Error'],[385 140 415 190],'Inputs','+-');
addB('simulink/Math Operations/Math Function',[sys '/Lambda Error Squared'],[450 145 510 185],'Operator','square');
addB('simulink/Math Operations/Gain',[sys '/Cp Exponent'],[545 145 625 185], ...
    'Gain','-1/DFIG.Wind.lambdaWidth^2');
addB('simulink/Math Operations/Math Function',[sys '/Cp Shape'],[660 145 720 185],'Operator','exp');
addB('simulink/Math Operations/Gain',[sys '/Cp Max'],[750 145 815 185],'Gain','DFIG.Wind.CpMax');
addB('simulink/Math Operations/Product',[sys '/Cp times V cubed'],[360 50 410 100],'Inputs','**');
addB('simulink/Math Operations/Gain',[sys '/Air Power Gain'],[455 55 585 95], ...
    'Gain','0.5*DFIG.Wind.rho*DFIG.Wind.area*DFIG.Wind.etaGear');
addB('simulink/Sources/Constant',[sys '/Minimum Speed'],[600 245 675 275],'Value','DFIG.Drive.omegaMin');
addB('simulink/Math Operations/MinMax',[sys '/Safe Generator Speed'],[710 225 765 275], ...
    'Function','max','Inputs','2');
addB('simulink/Math Operations/Product',[sys '/Mechanical Torque Command'],[815 195 865 245],'Inputs','*/');
addB('simulink/Math Operations/Gain',[sys '/Viscous Torque'],[145 325 230 360],'Gain','DFIG.Drive.B');
addB('simulink/Math Operations/Sum',[sys '/Mechanical Torque Balance'],[285 270 320 335],'Inputs','++-');
addB('simulink/Math Operations/Gain',[sys '/Inverse Inertia'],[355 285 425 325],'Gain','1/DFIG.Drive.J');
addB('simulink/Continuous/Integrator',[sys '/Generator Speed State'],[470 275 525 335], ...
    'InitialCondition','DFIG.Drive.omega0');

wire(sys,'Wind 9 to 10 mps/1','Wind Speed Squared/1','');
wire(sys,'Wind Speed Squared/1','Wind Speed Cubed/1','');wire(sys,'Wind 9 to 10 mps/1','Wind Speed Cubed/2','');
wire(sys,'Generator Speed State/1','Tip Speed Numerator/1','');
wire(sys,'Tip Speed Numerator/1','Tip Speed Ratio/1','');wire(sys,'Wind 9 to 10 mps/1','Tip Speed Ratio/2','');
wire(sys,'Tip Speed Ratio/1','Lambda Error/1','');wire(sys,'Lambda Opt/1','Lambda Error/2','');
wire(sys,'Lambda Error/1','Lambda Error Squared/1','');wire(sys,'Lambda Error Squared/1','Cp Exponent/1','');
wire(sys,'Cp Exponent/1','Cp Shape/1','');wire(sys,'Cp Shape/1','Cp Max/1','');
wire(sys,'Wind Speed Cubed/1','Cp times V cubed/1','');wire(sys,'Cp Max/1','Cp times V cubed/2','');
wire(sys,'Cp times V cubed/1','Air Power Gain/1','');
wire(sys,'Generator Speed State/1','Safe Generator Speed/1','');wire(sys,'Minimum Speed/1','Safe Generator Speed/2','');
wire(sys,'Air Power Gain/1','Mechanical Torque Command/1','');wire(sys,'Safe Generator Speed/1','Mechanical Torque Command/2','');
wire(sys,'Mechanical Torque Command/1','Mechanical Torque Balance/1','');
wire(sys,'Electromagnetic Torque Te/1','Mechanical Torque Balance/2','');
wire(sys,'Generator Speed State/1','Viscous Torque/1','');wire(sys,'Viscous Torque/1','Mechanical Torque Balance/3','');
wire(sys,'Mechanical Torque Balance/1','Inverse Inertia/1','');wire(sys,'Inverse Inertia/1','Generator Speed State/1','');
wire(sys,'Generator Speed State/1','Generator Speed/1','');wire(sys,'Mechanical Torque Command/1','Mechanical Torque/1','');
wire(sys,'Air Power Gain/1','Aerodynamic Power/1','');wire(sys,'Wind 9 to 10 mps/1','Wind Speed/1','');
note(sys,[60 455 900 500],'Cp(lambda) is smooth and explicit.  Mechanical equation: J*domega/dt = Tm + Te - B*omega; generator Te is negative in generating operation.');
end

function buildMachine(sys)
addIn(sys,'Stator Grid Voltage dq',1,[20 70 50 90]);
addIn(sys,'Rotor Converter Voltage dq',2,[20 190 50 210]);
addIn(sys,'Generator Speed',3,[20 330 50 350]);
addOut(sys,'Stator Current dq',1,[1120 65 1150 85]);
addOut(sys,'Rotor Current dq',2,[1120 155 1150 175]);
addOut(sys,'Electromagnetic Torque',3,[1120 255 1150 275]);
addOut(sys,'Stator P and Q',4,[1120 345 1150 365]);
addOut(sys,'Flux States',5,[1120 435 1150 455]);
addB('simulink/Continuous/Integrator',[sys '/Flux State Integrator'],[475 245 545 295], ...
    'InitialCondition','DFIG.Initial.flux');
addB('simulink/Math Operations/Gain',[sys '/Flux to Current Matrix'],[600 235 745 305], ...
    'Gain','DFIG.Machine.CurrentFromFlux','Multiplication','Matrix(K*u)');
addB('simulink/Signal Routing/Demux',[sys '/Separate Flux'],[570 335 575 485],'Outputs','4');
addB('simulink/Signal Routing/Demux',[sys '/Separate Currents'],[780 215 785 365],'Outputs','4');
addB('simulink/Signal Routing/Demux',[sys '/Separate Stator Voltage'],[105 50 110 120],'Outputs','2');
addB('simulink/Signal Routing/Demux',[sys '/Separate Rotor Voltage'],[105 170 110 240],'Outputs','2');
addB('simulink/Sources/Constant',[sys '/Synchronous Electrical Speed'],[90 285 205 315],'Value','DFIG.Base.ws');
addB('simulink/Math Operations/Gain',[sys '/Electrical Rotor Speed'],[95 340 205 375],'Gain','-DFIG.Machine.p');
addB('simulink/Math Operations/Sum',[sys '/Slip Frequency'],[245 300 280 350],'Inputs','++');
addB('simulink/Math Operations/Gain',[sys '/Minus Rs ids'],[145 35 235 65],'Gain','-DFIG.Machine.Rs');
addB('simulink/Math Operations/Gain',[sys '/Plus ws psiqs'],[145 75 235 105],'Gain','DFIG.Base.ws');
addB('simulink/Math Operations/Sum',[sys '/d psi ds'],[300 50 335 110],'Inputs','+++');
addB('simulink/Math Operations/Gain',[sys '/Minus Rs iqs'],[145 120 235 150],'Gain','-DFIG.Machine.Rs');
addB('simulink/Math Operations/Gain',[sys '/Minus ws psids'],[145 160 235 190],'Gain','-DFIG.Base.ws');
addB('simulink/Math Operations/Sum',[sys '/d psi qs'],[300 125 335 185],'Inputs','+++');
addB('simulink/Math Operations/Gain',[sys '/Minus Rr idr'],[145 215 235 245],'Gain','-DFIG.Machine.Rr');
addB('simulink/Math Operations/Product',[sys '/Slip psi qr'],[300 205 345 245],'Inputs','**');
addB('simulink/Math Operations/Sum',[sys '/d psi dr'],[385 195 420 255],'Inputs','+++');
addB('simulink/Math Operations/Gain',[sys '/Minus Rr iqr'],[145 245 235 275],'Gain','-DFIG.Machine.Rr');
addB('simulink/Math Operations/Product',[sys '/Slip psi dr'],[300 260 345 300],'Inputs','**');
addB('simulink/Math Operations/Gain',[sys '/Negate Slip psi dr'],[365 270 420 300],'Gain','-1');
addB('simulink/Math Operations/Sum',[sys '/d psi qr'],[385 315 420 375],'Inputs','+++');
addB('simulink/Signal Routing/Mux',[sys '/Flux Derivative Vector'],[445 70 450 220],'Inputs','4');
addB('simulink/Math Operations/Product',[sys '/psi ds times iqs'],[820 385 870 425],'Inputs','**');
addB('simulink/Math Operations/Product',[sys '/psi qs times ids'],[820 440 870 480],'Inputs','**');
addB('simulink/Math Operations/Sum',[sys '/Air Gap Torque Cross Product'],[900 395 935 465],'Inputs','+-');
addB('simulink/Math Operations/Gain',[sys '/Torque Gain'],[970 410 1040 450],'Gain','1.5*DFIG.Machine.p');
addB('simulink/Math Operations/Product',[sys '/Stator vd id'],[820 25 870 60],'Inputs','**');
addB('simulink/Math Operations/Product',[sys '/Stator vq iq'],[820 70 870 105],'Inputs','**');
addB('simulink/Math Operations/Sum',[sys '/Stator Active Sum'],[900 40 935 95],'Inputs','++');
addB('simulink/Math Operations/Gain',[sys '/Stator Active Power'],[970 50 1040 85],'Gain','1.5');
addB('simulink/Math Operations/Product',[sys '/Stator vq id'],[820 115 870 150],'Inputs','**');
addB('simulink/Math Operations/Product',[sys '/Stator vd iq'],[820 160 870 195],'Inputs','**');
addB('simulink/Math Operations/Sum',[sys '/Stator Reactive Sum'],[900 125 935 185],'Inputs','+-');
addB('simulink/Math Operations/Gain',[sys '/Stator Reactive Power'],[970 135 1040 170],'Gain','1.5');
addB('simulink/Signal Routing/Mux',[sys '/Stator PQ Vector'],[1070 110 1075 195],'Inputs','2');
addB('simulink/Signal Routing/Mux',[sys '/Stator Current Vector'],[1045 15 1050 90],'Inputs','2');
addB('simulink/Signal Routing/Mux',[sys '/Rotor Current Vector'],[1045 195 1050 270],'Inputs','2');

wire(sys,'Flux Derivative Vector/1','Flux State Integrator/1','');wire(sys,'Flux State Integrator/1','Flux to Current Matrix/1','');
wire(sys,'Flux State Integrator/1','Separate Flux/1','');wire(sys,'Flux to Current Matrix/1','Separate Currents/1','');
wire(sys,'Stator Grid Voltage dq/1','Separate Stator Voltage/1','');wire(sys,'Rotor Converter Voltage dq/1','Separate Rotor Voltage/1','');
wire(sys,'Synchronous Electrical Speed/1','Slip Frequency/1','');wire(sys,'Generator Speed/1','Electrical Rotor Speed/1','');wire(sys,'Electrical Rotor Speed/1','Slip Frequency/2','');
wire(sys,'Separate Currents/1','Minus Rs ids/1','');wire(sys,'Separate Flux/2','Plus ws psiqs/1','');
wire(sys,'Separate Stator Voltage/1','d psi ds/1','');wire(sys,'Minus Rs ids/1','d psi ds/2','');wire(sys,'Plus ws psiqs/1','d psi ds/3','');
wire(sys,'Separate Currents/2','Minus Rs iqs/1','');wire(sys,'Separate Flux/1','Minus ws psids/1','');
wire(sys,'Separate Stator Voltage/2','d psi qs/1','');wire(sys,'Minus Rs iqs/1','d psi qs/2','');wire(sys,'Minus ws psids/1','d psi qs/3','');
wire(sys,'Separate Currents/3','Minus Rr idr/1','');wire(sys,'Slip Frequency/1','Slip psi qr/1','');wire(sys,'Separate Flux/4','Slip psi qr/2','');
wire(sys,'Separate Rotor Voltage/1','d psi dr/1','');wire(sys,'Minus Rr idr/1','d psi dr/2','');wire(sys,'Slip psi qr/1','d psi dr/3','');
wire(sys,'Separate Currents/4','Minus Rr iqr/1','');wire(sys,'Slip Frequency/1','Slip psi dr/1','');wire(sys,'Separate Flux/3','Slip psi dr/2','');wire(sys,'Slip psi dr/1','Negate Slip psi dr/1','');
wire(sys,'Separate Rotor Voltage/2','d psi qr/1','');wire(sys,'Minus Rr iqr/1','d psi qr/2','');wire(sys,'Negate Slip psi dr/1','d psi qr/3','');
wire(sys,'d psi ds/1','Flux Derivative Vector/1','');wire(sys,'d psi qs/1','Flux Derivative Vector/2','');wire(sys,'d psi dr/1','Flux Derivative Vector/3','');wire(sys,'d psi qr/1','Flux Derivative Vector/4','');
wire(sys,'Separate Flux/1','psi ds times iqs/1','');wire(sys,'Separate Currents/2','psi ds times iqs/2','');
wire(sys,'Separate Flux/2','psi qs times ids/1','');wire(sys,'Separate Currents/1','psi qs times ids/2','');
wire(sys,'psi ds times iqs/1','Air Gap Torque Cross Product/1','');wire(sys,'psi qs times ids/1','Air Gap Torque Cross Product/2','');wire(sys,'Air Gap Torque Cross Product/1','Torque Gain/1','');
wire(sys,'Separate Stator Voltage/1','Stator vd id/1','');wire(sys,'Separate Currents/1','Stator vd id/2','');wire(sys,'Separate Stator Voltage/2','Stator vq iq/1','');wire(sys,'Separate Currents/2','Stator vq iq/2','');
wire(sys,'Stator vd id/1','Stator Active Sum/1','');wire(sys,'Stator vq iq/1','Stator Active Sum/2','');wire(sys,'Stator Active Sum/1','Stator Active Power/1','');
wire(sys,'Separate Stator Voltage/2','Stator vq id/1','');wire(sys,'Separate Currents/1','Stator vq id/2','');wire(sys,'Separate Stator Voltage/1','Stator vd iq/1','');wire(sys,'Separate Currents/2','Stator vd iq/2','');
wire(sys,'Stator vq id/1','Stator Reactive Sum/1','');wire(sys,'Stator vd iq/1','Stator Reactive Sum/2','');wire(sys,'Stator Reactive Sum/1','Stator Reactive Power/1','');
wire(sys,'Separate Currents/1','Stator Current Vector/1','');wire(sys,'Separate Currents/2','Stator Current Vector/2','');
wire(sys,'Separate Currents/3','Rotor Current Vector/1','');wire(sys,'Separate Currents/4','Rotor Current Vector/2','');
wire(sys,'Stator Active Power/1','Stator PQ Vector/1','');wire(sys,'Stator Reactive Power/1','Stator PQ Vector/2','');
wire(sys,'Stator Current Vector/1','Stator Current dq/1','');wire(sys,'Rotor Current Vector/1','Rotor Current dq/1','');wire(sys,'Torque Gain/1','Electromagnetic Torque/1','');wire(sys,'Stator PQ Vector/1','Stator P and Q/1','');wire(sys,'Flux State Integrator/1','Flux States/1','');
note(sys,[70 510 1080 555],'Flux order [psi_ds psi_qs psi_dr psi_qr]. Current map is the explicit inverse inductance matrix. Positive stator power is absorbed by the machine; generating torque and stator power are negative.');
end

function buildRSC(sys)
addIn(sys,'Mechanical Torque Command',1,[20 65 50 85]);addIn(sys,'Generator Speed',2,[20 155 50 175]);
addIn(sys,'Rotor Current dq',3,[20 255 50 275]);addIn(sys,'Flux States',4,[20 365 50 385]);
addOut(sys,'Rotor Voltage Command dq',1,[1080 155 1110 175]);addOut(sys,'Rotor Current Reference dq',2,[1080 285 1110 305]);addOut(sys,'Slip Frequency',3,[1080 395 1110 415]);
addB('simulink/Sources/Constant',[sys '/Idr Magnetizing Reference'],[85 40 180 70],'Value','DFIG.RSC.idrRef');
addB('simulink/Math Operations/Gain',[sys '/Torque to Iqr Reference'],[85 90 200 125],'Gain','DFIG.RSC.torqueToIqr');
addB('simulink/Math Operations/Math Function',[sys '/Idr Ref Squared'],[235 25 290 65],'Operator','square');addB('simulink/Math Operations/Math Function',[sys '/Iqr Ref Squared'],[235 85 290 125],'Operator','square');
addB('simulink/Math Operations/Sum',[sys '/Reference Magnitude Squared'],[325 45 360 105],'Inputs','++');addB('simulink/Math Operations/Math Function',[sys '/Reference Magnitude'],[395 55 450 95],'Operator','sqrt');
addB('simulink/Sources/Constant',[sys '/Magnitude Floor'],[390 125 455 150],'Value','1');addB('simulink/Math Operations/MinMax',[sys '/Safe Reference Magnitude'],[485 65 540 115],'Function','max','Inputs','2');
addB('simulink/Sources/Constant',[sys '/Rotor Current Limit'],[485 135 555 165],'Value','DFIG.RSC.Imax');addB('simulink/Math Operations/Product',[sys '/Limit Ratio'],[590 80 640 125],'Inputs','*/');
addB('simulink/Sources/Constant',[sys '/Unity Scale'],[590 145 650 175],'Value','1');addB('simulink/Math Operations/MinMax',[sys '/Circular Limit Scale'],[680 95 735 145],'Function','min','Inputs','2');
addB('simulink/Math Operations/Product',[sys '/Idr Limited Reference'],[770 45 820 85],'Inputs','**');addB('simulink/Math Operations/Product',[sys '/Iqr Limited Reference'],[770 105 820 145],'Inputs','**');
addB('simulink/Signal Routing/Demux',[sys '/Separate Rotor Current'],[85 225 90 315],'Outputs','2');addB('simulink/Signal Routing/Demux',[sys '/Separate Flux'],[85 335 90 455],'Outputs','4');
addB('simulink/Math Operations/Sum',[sys '/Idr Error'],[855 45 890 95],'Inputs','+-');addB('simulink/Math Operations/Sum',[sys '/Iqr Error'],[855 105 890 155],'Inputs','+-');
addB('simulink/Math Operations/Gain',[sys '/Idr Kp'],[920 35 980 65],'Gain','DFIG.RSC.Kp');addB('simulink/Math Operations/Gain',[sys '/Idr Ki'],[920 75 980 105],'Gain','DFIG.RSC.Ki');addB('simulink/Continuous/Integrator',[sys '/Idr Error Integrator'],[1000 75 1040 105]);
addB('simulink/Math Operations/Gain',[sys '/Iqr Kp'],[920 125 980 155],'Gain','DFIG.RSC.Kp');addB('simulink/Math Operations/Gain',[sys '/Iqr Ki'],[920 165 980 195],'Gain','DFIG.RSC.Ki');addB('simulink/Continuous/Integrator',[sys '/Iqr Error Integrator'],[1000 165 1040 195]);
addB('simulink/Sources/Constant',[sys '/Synchronous Speed'],[215 210 300 240],'Value','DFIG.Base.ws');addB('simulink/Math Operations/Gain',[sys '/Rotor Electrical Speed'],[215 255 310 290],'Gain','-DFIG.Machine.p');addB('simulink/Math Operations/Sum',[sys '/Slip'],[345 225 380 275],'Inputs','++');
addB('simulink/Math Operations/Gain',[sys '/Rr idr'],[425 215 480 245],'Gain','DFIG.Machine.Rr');addB('simulink/Math Operations/Product',[sys '/Slip psi qr'],[425 265 475 305],'Inputs','**');addB('simulink/Math Operations/Gain',[sys '/Negate Slip psi qr'],[500 270 555 300],'Gain','-1');
addB('simulink/Math Operations/Gain',[sys '/Rr iqr'],[425 325 480 355],'Gain','DFIG.Machine.Rr');addB('simulink/Math Operations/Product',[sys '/Slip psi dr'],[425 375 475 415],'Inputs','**');
addB('simulink/Math Operations/Sum',[sys '/Vdr Command Sum'],[690 215 725 285],'Inputs','++++');addB('simulink/Math Operations/Sum',[sys '/Vqr Command Sum'],[690 325 725 395],'Inputs','++++');
addB('simulink/Discontinuities/Saturation',[sys '/Vdr Average Bridge Limit'],[770 230 855 270],'UpperLimit','DFIG.RSC.Vmax','LowerLimit','-DFIG.RSC.Vmax');addB('simulink/Discontinuities/Saturation',[sys '/Vqr Average Bridge Limit'],[770 345 855 385],'UpperLimit','DFIG.RSC.Vmax','LowerLimit','-DFIG.RSC.Vmax');
addB('simulink/Signal Routing/Mux',[sys '/Rotor Voltage Vector'],[925 235 930 375],'Inputs','2');addB('simulink/Signal Routing/Mux',[sys '/Rotor Reference Vector'],[930 55 935 145],'Inputs','2');

wire(sys,'Mechanical Torque Command/1','Torque to Iqr Reference/1','');wire(sys,'Idr Magnetizing Reference/1','Idr Ref Squared/1','');wire(sys,'Torque to Iqr Reference/1','Iqr Ref Squared/1','');wire(sys,'Idr Ref Squared/1','Reference Magnitude Squared/1','');wire(sys,'Iqr Ref Squared/1','Reference Magnitude Squared/2','');wire(sys,'Reference Magnitude Squared/1','Reference Magnitude/1','');wire(sys,'Reference Magnitude/1','Safe Reference Magnitude/1','');wire(sys,'Magnitude Floor/1','Safe Reference Magnitude/2','');wire(sys,'Rotor Current Limit/1','Limit Ratio/1','');wire(sys,'Safe Reference Magnitude/1','Limit Ratio/2','');wire(sys,'Limit Ratio/1','Circular Limit Scale/1','');wire(sys,'Unity Scale/1','Circular Limit Scale/2','');wire(sys,'Idr Magnetizing Reference/1','Idr Limited Reference/1','');wire(sys,'Circular Limit Scale/1','Idr Limited Reference/2','');wire(sys,'Torque to Iqr Reference/1','Iqr Limited Reference/1','');wire(sys,'Circular Limit Scale/1','Iqr Limited Reference/2','');
wire(sys,'Rotor Current dq/1','Separate Rotor Current/1','');wire(sys,'Flux States/1','Separate Flux/1','');wire(sys,'Idr Limited Reference/1','Idr Error/1','');wire(sys,'Separate Rotor Current/1','Idr Error/2','');wire(sys,'Iqr Limited Reference/1','Iqr Error/1','');wire(sys,'Separate Rotor Current/2','Iqr Error/2','');wire(sys,'Idr Error/1','Idr Kp/1','');wire(sys,'Idr Error/1','Idr Ki/1','');wire(sys,'Idr Ki/1','Idr Error Integrator/1','');wire(sys,'Iqr Error/1','Iqr Kp/1','');wire(sys,'Iqr Error/1','Iqr Ki/1','');wire(sys,'Iqr Ki/1','Iqr Error Integrator/1','');
wire(sys,'Synchronous Speed/1','Slip/1','');wire(sys,'Generator Speed/1','Rotor Electrical Speed/1','');wire(sys,'Rotor Electrical Speed/1','Slip/2','');wire(sys,'Separate Rotor Current/1','Rr idr/1','');wire(sys,'Slip/1','Slip psi qr/1','');wire(sys,'Separate Flux/4','Slip psi qr/2','');wire(sys,'Slip psi qr/1','Negate Slip psi qr/1','');wire(sys,'Separate Rotor Current/2','Rr iqr/1','');wire(sys,'Slip/1','Slip psi dr/1','');wire(sys,'Separate Flux/3','Slip psi dr/2','');
wire(sys,'Rr idr/1','Vdr Command Sum/1','');wire(sys,'Negate Slip psi qr/1','Vdr Command Sum/2','');wire(sys,'Idr Kp/1','Vdr Command Sum/3','');wire(sys,'Idr Error Integrator/1','Vdr Command Sum/4','');wire(sys,'Rr iqr/1','Vqr Command Sum/1','');wire(sys,'Slip psi dr/1','Vqr Command Sum/2','');wire(sys,'Iqr Kp/1','Vqr Command Sum/3','');wire(sys,'Iqr Error Integrator/1','Vqr Command Sum/4','');wire(sys,'Vdr Command Sum/1','Vdr Average Bridge Limit/1','');wire(sys,'Vqr Command Sum/1','Vqr Average Bridge Limit/1','');wire(sys,'Vdr Average Bridge Limit/1','Rotor Voltage Vector/1','');wire(sys,'Vqr Average Bridge Limit/1','Rotor Voltage Vector/2','');wire(sys,'Idr Limited Reference/1','Rotor Reference Vector/1','');wire(sys,'Iqr Limited Reference/1','Rotor Reference Vector/2','');wire(sys,'Rotor Voltage Vector/1','Rotor Voltage Command dq/1','');wire(sys,'Rotor Reference Vector/1','Rotor Current Reference dq/1','');wire(sys,'Slip/1','Slip Frequency/1','');
note(sys,[75 475 1040 520],'Stator-flux-oriented RSC: idr supplies magnetization/reactive-power support; iqr sets generating torque. The average bridge is represented by bounded dq rotor voltage, with circular current limiting ahead of the PI loops.');
end

function buildDCGSC(sys)
addIn(sys,'Rotor Voltage dq',1,[20 60 50 80]);addIn(sys,'Rotor Current dq',2,[20 145 50 165]);addIn(sys,'Grid Voltage dq',3,[20 385 50 405]);
addOut(sys,'DC Link Voltage',1,[1120 70 1150 90]);addOut(sys,'GSC Current dq',2,[1120 210 1150 230]);addOut(sys,'GSC Voltage dq',3,[1120 325 1150 345]);addOut(sys,'GSC Active Power',4,[1120 430 1150 450]);
addB('simulink/Signal Routing/Demux',[sys '/Separate Rotor Voltage'],[85 35 90 105],'Outputs','2');addB('simulink/Signal Routing/Demux',[sys '/Separate Rotor Current'],[85 120 90 190],'Outputs','2');
addB('simulink/Math Operations/Product',[sys '/Rotor vd id'],[135 35 180 70],'Inputs','**');addB('simulink/Math Operations/Product',[sys '/Rotor vq iq'],[135 85 180 120],'Inputs','**');addB('simulink/Math Operations/Sum',[sys '/Rotor Power Sum'],[215 50 250 110],'Inputs','++');addB('simulink/Math Operations/Gain',[sys '/Rotor Electrical Power'],[280 65 345 100],'Gain','1.5');
addB('simulink/Continuous/Integrator',[sys '/DC Voltage State'],[520 65 580 110],'InitialCondition','DFIG.DC.Vnom');addB('simulink/Sources/Constant',[sys '/DC Voltage Reference'],[365 145 450 175],'Value','DFIG.DC.Vnom');addB('simulink/Math Operations/Sum',[sys '/DC Voltage Error'],[490 140 525 190],'Inputs','+-');addB('simulink/Math Operations/Gain',[sys '/Vdc Kp'],[560 135 620 165],'Gain','DFIG.GSC.VdcKp');addB('simulink/Math Operations/Gain',[sys '/Vdc Ki'],[560 180 620 210],'Gain','DFIG.GSC.VdcKi');addB('simulink/Continuous/Integrator',[sys '/Vdc Error Integrator'],[650 180 700 210],'InitialCondition','DFIG.Initial.igqGSC');addB('simulink/Math Operations/Sum',[sys '/GSC Iq Reference'],[735 135 770 195],'Inputs','++');addB('simulink/Discontinuities/Saturation',[sys '/GSC Current Limit'],[805 145 880 185],'UpperLimit','DFIG.GSC.Imax','LowerLimit','-DFIG.GSC.Imax');
addB('simulink/Sources/Constant',[sys '/GSC Id Reference'],[805 235 880 265],'Value','0');addB('simulink/Signal Routing/Demux',[sys '/Separate Grid Voltage'],[85 355 90 435],'Outputs','2');
addB('simulink/Continuous/Integrator',[sys '/GSC Id State'],[900 250 950 285],'InitialCondition','0');addB('simulink/Continuous/Integrator',[sys '/GSC Iq State'],[900 305 950 340],'InitialCondition','DFIG.Initial.igqGSC');
addB('simulink/Math Operations/Sum',[sys '/GSC Id Error'],[915 145 950 195],'Inputs','+-');addB('simulink/Math Operations/Sum',[sys '/GSC Iq Error'],[915 200 950 250],'Inputs','+-');
addB('simulink/Math Operations/Gain',[sys '/Id Kp'],[980 135 1035 165],'Gain','DFIG.GSC.Kp');addB('simulink/Math Operations/Gain',[sys '/Id Ki'],[980 170 1035 200],'Gain','DFIG.GSC.Ki');addB('simulink/Continuous/Integrator',[sys '/Id Error Integrator'],[1050 170 1090 200]);addB('simulink/Math Operations/Sum',[sys '/Id PI'],[1105 140 1140 195],'Inputs','++');
addB('simulink/Math Operations/Gain',[sys '/Iq Kp'],[980 215 1035 245],'Gain','DFIG.GSC.Kp');addB('simulink/Math Operations/Gain',[sys '/Iq Ki'],[980 250 1035 280],'Gain','DFIG.GSC.Ki');addB('simulink/Continuous/Integrator',[sys '/Iq Error Integrator'],[1050 250 1090 280]);addB('simulink/Math Operations/Sum',[sys '/Iq PI'],[1105 220 1140 275],'Inputs','++');
% Controller feedforward and plant equations are arranged in a lower band.
addB('simulink/Math Operations/Gain',[sys '/R id'],[145 330 200 360],'Gain','DFIG.GSC.R');addB('simulink/Math Operations/Gain',[sys '/Minus wL iq'],[145 370 220 400],'Gain','-DFIG.Base.ws*DFIG.GSC.L');addB('simulink/Math Operations/Sum',[sys '/Vcd Command'],[255 325 290 405],'Inputs','++++');addB('simulink/Discontinuities/Saturation',[sys '/Average GSC d Limit'],[325 345 400 385],'UpperLimit','DFIG.GSC.Vmax','LowerLimit','-DFIG.GSC.Vmax');
addB('simulink/Math Operations/Gain',[sys '/R iq'],[145 440 200 470],'Gain','DFIG.GSC.R');addB('simulink/Math Operations/Gain',[sys '/Plus wL id'],[145 480 220 510],'Gain','DFIG.Base.ws*DFIG.GSC.L');addB('simulink/Math Operations/Sum',[sys '/Vcq Command'],[255 435 290 515],'Inputs','++++');addB('simulink/Discontinuities/Saturation',[sys '/Average GSC q Limit'],[325 455 400 495],'UpperLimit','DFIG.GSC.Vmax','LowerLimit','-DFIG.GSC.Vmax');
addB('simulink/Math Operations/Gain',[sys '/Minus R id'],[445 330 505 360],'Gain','-DFIG.GSC.R');addB('simulink/Math Operations/Gain',[sys '/Plus wL iq'],[445 370 515 400],'Gain','DFIG.Base.ws*DFIG.GSC.L');addB('simulink/Math Operations/Gain',[sys '/Minus Grid Vd'],[445 410 515 440],'Gain','-1');addB('simulink/Math Operations/Sum',[sys '/GSC d Voltage Balance'],[550 340 585 430],'Inputs','++++');addB('simulink/Math Operations/Gain',[sys '/Inverse Filter L d'],[620 365 690 400],'Gain','1/DFIG.GSC.L');
addB('simulink/Math Operations/Gain',[sys '/Minus R iq'],[445 455 505 485],'Gain','-DFIG.GSC.R');addB('simulink/Math Operations/Gain',[sys '/Minus wL id'],[445 495 515 525],'Gain','-DFIG.Base.ws*DFIG.GSC.L');addB('simulink/Math Operations/Gain',[sys '/Minus Grid Vq'],[445 535 515 565],'Gain','-1');addB('simulink/Math Operations/Sum',[sys '/GSC q Voltage Balance'],[550 455 585 545],'Inputs','++++');addB('simulink/Math Operations/Gain',[sys '/Inverse Filter L q'],[620 485 690 520],'Gain','1/DFIG.GSC.L');
addB('simulink/Math Operations/Product',[sys '/Grid vd id'],[735 360 780 395],'Inputs','**');addB('simulink/Math Operations/Product',[sys '/Grid vq iq'],[735 410 780 445],'Inputs','**');addB('simulink/Math Operations/Sum',[sys '/GSC Power Sum'],[815 375 850 435],'Inputs','++');addB('simulink/Math Operations/Gain',[sys '/GSC Power'],[880 390 940 425],'Gain','1.5');
addB('simulink/Math Operations/Gain',[sys '/Negative Rotor Power'],[280 115 355 145],'Gain','-1');addB('simulink/Math Operations/Gain',[sys '/Negative GSC Power'],[880 440 950 470],'Gain','-1');addB('simulink/Sources/Constant',[sys '/Negative DC Loss'],[365 15 450 45],'Value','-DFIG.DC.lossW');addB('simulink/Math Operations/Sum',[sys '/DC Power Balance'],[405 55 440 125],'Inputs','+++');addB('simulink/Sources/Constant',[sys '/DC Voltage Floor'],[475 10 550 40],'Value','DFIG.DC.Vfloor');addB('simulink/Math Operations/MinMax',[sys '/Safe DC Voltage'],[605 45 660 95],'Function','max','Inputs','2');addB('simulink/Math Operations/Product',[sys '/DC Current Equivalent'],[690 45 740 95],'Inputs','*/');addB('simulink/Math Operations/Gain',[sys '/Inverse DC Capacitance'],[775 55 850 90],'Gain','1/DFIG.DC.C');
addB('simulink/Signal Routing/Mux',[sys '/GSC Current Vector'],[980 300 985 365],'Inputs','2');addB('simulink/Signal Routing/Mux',[sys '/GSC Voltage Vector'],[420 415 425 500],'Inputs','2');

wire(sys,'Rotor Voltage dq/1','Separate Rotor Voltage/1','');wire(sys,'Rotor Current dq/1','Separate Rotor Current/1','');wire(sys,'Separate Rotor Voltage/1','Rotor vd id/1','');wire(sys,'Separate Rotor Current/1','Rotor vd id/2','');wire(sys,'Separate Rotor Voltage/2','Rotor vq iq/1','');wire(sys,'Separate Rotor Current/2','Rotor vq iq/2','');wire(sys,'Rotor vd id/1','Rotor Power Sum/1','');wire(sys,'Rotor vq iq/1','Rotor Power Sum/2','');wire(sys,'Rotor Power Sum/1','Rotor Electrical Power/1','');
wire(sys,'DC Voltage State/1','DC Voltage Error/1','');wire(sys,'DC Voltage Reference/1','DC Voltage Error/2','');wire(sys,'DC Voltage Error/1','Vdc Kp/1','');wire(sys,'DC Voltage Error/1','Vdc Ki/1','');wire(sys,'Vdc Ki/1','Vdc Error Integrator/1','');wire(sys,'Vdc Kp/1','GSC Iq Reference/1','');wire(sys,'Vdc Error Integrator/1','GSC Iq Reference/2','');wire(sys,'GSC Iq Reference/1','GSC Current Limit/1','');
wire(sys,'Grid Voltage dq/1','Separate Grid Voltage/1','');wire(sys,'GSC Id Reference/1','GSC Id Error/1','');wire(sys,'GSC Id State/1','GSC Id Error/2','');wire(sys,'GSC Current Limit/1','GSC Iq Error/1','');wire(sys,'GSC Iq State/1','GSC Iq Error/2','');wire(sys,'GSC Id Error/1','Id Kp/1','');wire(sys,'GSC Id Error/1','Id Ki/1','');wire(sys,'Id Ki/1','Id Error Integrator/1','');wire(sys,'Id Kp/1','Id PI/1','');wire(sys,'Id Error Integrator/1','Id PI/2','');wire(sys,'GSC Iq Error/1','Iq Kp/1','');wire(sys,'GSC Iq Error/1','Iq Ki/1','');wire(sys,'Iq Ki/1','Iq Error Integrator/1','');wire(sys,'Iq Kp/1','Iq PI/1','');wire(sys,'Iq Error Integrator/1','Iq PI/2','');
wire(sys,'GSC Id State/1','R id/1','');wire(sys,'GSC Iq State/1','Minus wL iq/1','');wire(sys,'Separate Grid Voltage/1','Vcd Command/1','');wire(sys,'R id/1','Vcd Command/2','');wire(sys,'Minus wL iq/1','Vcd Command/3','');wire(sys,'Id PI/1','Vcd Command/4','');wire(sys,'Vcd Command/1','Average GSC d Limit/1','');wire(sys,'GSC Iq State/1','R iq/1','');wire(sys,'GSC Id State/1','Plus wL id/1','');wire(sys,'Separate Grid Voltage/2','Vcq Command/1','');wire(sys,'R iq/1','Vcq Command/2','');wire(sys,'Plus wL id/1','Vcq Command/3','');wire(sys,'Iq PI/1','Vcq Command/4','');wire(sys,'Vcq Command/1','Average GSC q Limit/1','');
wire(sys,'Average GSC d Limit/1','GSC d Voltage Balance/1','');wire(sys,'GSC Id State/1','Minus R id/1','');wire(sys,'Minus R id/1','GSC d Voltage Balance/2','');wire(sys,'GSC Iq State/1','Plus wL iq/1','');wire(sys,'Plus wL iq/1','GSC d Voltage Balance/3','');wire(sys,'Separate Grid Voltage/1','Minus Grid Vd/1','');wire(sys,'Minus Grid Vd/1','GSC d Voltage Balance/4','');wire(sys,'GSC d Voltage Balance/1','Inverse Filter L d/1','');wire(sys,'Inverse Filter L d/1','GSC Id State/1','');
wire(sys,'Average GSC q Limit/1','GSC q Voltage Balance/1','');wire(sys,'GSC Iq State/1','Minus R iq/1','');wire(sys,'Minus R iq/1','GSC q Voltage Balance/2','');wire(sys,'GSC Id State/1','Minus wL id/1','');wire(sys,'Minus wL id/1','GSC q Voltage Balance/3','');wire(sys,'Separate Grid Voltage/2','Minus Grid Vq/1','');wire(sys,'Minus Grid Vq/1','GSC q Voltage Balance/4','');wire(sys,'GSC q Voltage Balance/1','Inverse Filter L q/1','');wire(sys,'Inverse Filter L q/1','GSC Iq State/1','');
wire(sys,'Separate Grid Voltage/1','Grid vd id/1','');wire(sys,'GSC Id State/1','Grid vd id/2','');wire(sys,'Separate Grid Voltage/2','Grid vq iq/1','');wire(sys,'GSC Iq State/1','Grid vq iq/2','');wire(sys,'Grid vd id/1','GSC Power Sum/1','');wire(sys,'Grid vq iq/1','GSC Power Sum/2','');wire(sys,'GSC Power Sum/1','GSC Power/1','');
wire(sys,'Rotor Electrical Power/1','Negative Rotor Power/1','');wire(sys,'GSC Power/1','Negative GSC Power/1','');wire(sys,'Negative Rotor Power/1','DC Power Balance/1','');wire(sys,'Negative GSC Power/1','DC Power Balance/2','');wire(sys,'Negative DC Loss/1','DC Power Balance/3','');wire(sys,'DC Voltage State/1','Safe DC Voltage/1','');wire(sys,'DC Voltage Floor/1','Safe DC Voltage/2','');wire(sys,'DC Power Balance/1','DC Current Equivalent/1','');wire(sys,'Safe DC Voltage/1','DC Current Equivalent/2','');wire(sys,'DC Current Equivalent/1','Inverse DC Capacitance/1','');wire(sys,'Inverse DC Capacitance/1','DC Voltage State/1','');
wire(sys,'GSC Id State/1','GSC Current Vector/1','');wire(sys,'GSC Iq State/1','GSC Current Vector/2','');wire(sys,'Average GSC d Limit/1','GSC Voltage Vector/1','');wire(sys,'Average GSC q Limit/1','GSC Voltage Vector/2','');wire(sys,'DC Voltage State/1','DC Link Voltage/1','');wire(sys,'GSC Current Vector/1','GSC Current dq/1','');wire(sys,'GSC Voltage Vector/1','GSC Voltage dq/1','');wire(sys,'GSC Power/1','GSC Active Power/1','');
note(sys,[70 590 1080 640],'DC energy: C*Vdc*dVdc/dt = -P_rotor - P_GSC - P_loss. At subsynchronous speed the rotor absorbs slip power and the GSC draws that power from the grid; signs reverse naturally above synchronous speed.');
end

function buildPCC(sys)
addIn(sys,'DFIG Stator Current dq',1,[20 145 50 165]);addIn(sys,'GSC Current dq',2,[20 285 50 305]);
addOut(sys,'Grid Voltage dq',1,[850 75 880 95]);addOut(sys,'Total Active Power to Grid',2,[850 175 880 195]);addOut(sys,'Total Reactive Power to Grid',3,[850 245 880 265]);addOut(sys,'Stator Active Power to Grid',4,[850 335 880 355]);addOut(sys,'GSC Active Power to Grid',5,[850 405 880 425]);
addB('simulink/Sources/Constant',[sys '/Strong Grid dq Voltage'],[70 65 165 100],'Value','DFIG.Grid.Vdq');addB('simulink/Signal Routing/Demux',[sys '/Separate Grid Voltage'],[205 50 210 130],'Outputs','2');addB('simulink/Signal Routing/Demux',[sys '/Separate Stator Current'],[90 120 95 200],'Outputs','2');addB('simulink/Signal Routing/Demux',[sys '/Separate GSC Current'],[90 260 95 340],'Outputs','2');
addB('simulink/Math Operations/Product',[sys '/Stator vd id'],[250 120 295 155],'Inputs','**');addB('simulink/Math Operations/Product',[sys '/Stator vq iq'],[250 165 295 200],'Inputs','**');addB('simulink/Math Operations/Sum',[sys '/Stator P Absorbed Sum'],[330 135 365 195],'Inputs','++');addB('simulink/Math Operations/Gain',[sys '/Stator P to Grid'],[400 145 475 180],'Gain','-1.5');
addB('simulink/Math Operations/Product',[sys '/Stator vq id'],[250 215 295 250],'Inputs','**');addB('simulink/Math Operations/Product',[sys '/Stator vd iq'],[250 260 295 295],'Inputs','**');addB('simulink/Math Operations/Sum',[sys '/Stator Q Absorbed Sum'],[330 230 365 290],'Inputs','+-');addB('simulink/Math Operations/Gain',[sys '/Stator Q to Grid'],[400 240 475 275],'Gain','-1.5');
addB('simulink/Math Operations/Product',[sys '/GSC vd id'],[250 320 295 355],'Inputs','**');addB('simulink/Math Operations/Product',[sys '/GSC vq iq'],[250 365 295 400],'Inputs','**');addB('simulink/Math Operations/Sum',[sys '/GSC P Sum'],[330 335 365 395],'Inputs','++');addB('simulink/Math Operations/Gain',[sys '/GSC P to Grid'],[400 345 475 380],'Gain','1.5');
addB('simulink/Math Operations/Product',[sys '/GSC vq id'],[520 260 565 295],'Inputs','**');addB('simulink/Math Operations/Product',[sys '/GSC vd iq'],[520 305 565 340],'Inputs','**');addB('simulink/Math Operations/Sum',[sys '/GSC Q Sum'],[600 275 635 335],'Inputs','+-');addB('simulink/Math Operations/Gain',[sys '/GSC Q to Grid'],[670 285 735 320],'Gain','1.5');
addB('simulink/Math Operations/Sum',[sys '/Total P at PCC'],[540 145 575 205],'Inputs','++');addB('simulink/Math Operations/Sum',[sys '/Total Q at PCC'],[760 225 795 285],'Inputs','++');
wire(sys,'Strong Grid dq Voltage/1','Separate Grid Voltage/1','');wire(sys,'Strong Grid dq Voltage/1','Grid Voltage dq/1','');wire(sys,'DFIG Stator Current dq/1','Separate Stator Current/1','');wire(sys,'GSC Current dq/1','Separate GSC Current/1','');
wire(sys,'Separate Grid Voltage/1','Stator vd id/1','');wire(sys,'Separate Stator Current/1','Stator vd id/2','');wire(sys,'Separate Grid Voltage/2','Stator vq iq/1','');wire(sys,'Separate Stator Current/2','Stator vq iq/2','');wire(sys,'Stator vd id/1','Stator P Absorbed Sum/1','');wire(sys,'Stator vq iq/1','Stator P Absorbed Sum/2','');wire(sys,'Stator P Absorbed Sum/1','Stator P to Grid/1','');
wire(sys,'Separate Grid Voltage/2','Stator vq id/1','');wire(sys,'Separate Stator Current/1','Stator vq id/2','');wire(sys,'Separate Grid Voltage/1','Stator vd iq/1','');wire(sys,'Separate Stator Current/2','Stator vd iq/2','');wire(sys,'Stator vq id/1','Stator Q Absorbed Sum/1','');wire(sys,'Stator vd iq/1','Stator Q Absorbed Sum/2','');wire(sys,'Stator Q Absorbed Sum/1','Stator Q to Grid/1','');
wire(sys,'Separate Grid Voltage/1','GSC vd id/1','');wire(sys,'Separate GSC Current/1','GSC vd id/2','');wire(sys,'Separate Grid Voltage/2','GSC vq iq/1','');wire(sys,'Separate GSC Current/2','GSC vq iq/2','');wire(sys,'GSC vd id/1','GSC P Sum/1','');wire(sys,'GSC vq iq/1','GSC P Sum/2','');wire(sys,'GSC P Sum/1','GSC P to Grid/1','');
wire(sys,'Separate Grid Voltage/2','GSC vq id/1','');wire(sys,'Separate GSC Current/1','GSC vq id/2','');wire(sys,'Separate Grid Voltage/1','GSC vd iq/1','');wire(sys,'Separate GSC Current/2','GSC vd iq/2','');wire(sys,'GSC vq id/1','GSC Q Sum/1','');wire(sys,'GSC vd iq/1','GSC Q Sum/2','');wire(sys,'GSC Q Sum/1','GSC Q to Grid/1','');
wire(sys,'Stator P to Grid/1','Total P at PCC/1','');wire(sys,'GSC P to Grid/1','Total P at PCC/2','');wire(sys,'Stator Q to Grid/1','Total Q at PCC/1','');wire(sys,'GSC Q to Grid/1','Total Q at PCC/2','');wire(sys,'Total P at PCC/1','Total Active Power to Grid/1','');wire(sys,'Total Q at PCC/1','Total Reactive Power to Grid/1','');wire(sys,'Stator P to Grid/1','Stator Active Power to Grid/1','');wire(sys,'GSC P to Grid/1','GSC Active Power to Grid/1','');
note(sys,[70 470 820 515],'Strong-grid R1 boundary. The transformer is represented by the 690 V dq base; a later physical-network wrapper can replace this subsystem without changing the DFIG/RSC/DC contracts.');
end

function buildProtection(sys)
names={'Vdc','Rotor Current Reference','Rotor Current','Slip','P PCC','Q PCC'};
for k=1:6,addIn(sys,names{k},k,[20 35+65*(k-1) 50 55+65*(k-1)]);end
addB('simulink/Discontinuities/Saturation',[sys '/Vdc Monitor Limit'],[120 25 220 65],'UpperLimit','1.20*DFIG.DC.Vnom','LowerLimit','0.80*DFIG.DC.Vnom');
addB('simulink/Math Operations/Abs',[sys '/Slip Magnitude'],[120 215 175 245]);
addB('simulink/Sinks/Terminator',[sys '/Vdc Diagnostic Sink'],[300 35 320 55]);
addB('simulink/Sinks/Terminator',[sys '/Ir Ref Diagnostic Sink'],[300 100 320 120]);
addB('simulink/Sinks/Terminator',[sys '/Ir Diagnostic Sink'],[300 165 320 185]);
addB('simulink/Sinks/Terminator',[sys '/Slip Diagnostic Sink'],[300 230 320 250]);
addB('simulink/Sinks/Terminator',[sys '/P Diagnostic Sink'],[300 295 320 315]);
addB('simulink/Sinks/Terminator',[sys '/Q Diagnostic Sink'],[300 360 320 380]);
wire(sys,'Vdc/1','Vdc Monitor Limit/1','');wire(sys,'Vdc Monitor Limit/1','Vdc Diagnostic Sink/1','');wire(sys,'Rotor Current Reference/1','Ir Ref Diagnostic Sink/1','');wire(sys,'Rotor Current/1','Ir Diagnostic Sink/1','');wire(sys,'Slip/1','Slip Magnitude/1','');wire(sys,'Slip Magnitude/1','Slip Diagnostic Sink/1','');wire(sys,'P PCC/1','P Diagnostic Sink/1','');wire(sys,'Q PCC/1','Q Diagnostic Sink/1','');
note(sys,[380 80 850 340],[ ...
    'R1 keeps monitoring separate from control ownership.\n\n' ...
    'Reserved upgrades:\n' ...
    '  - crowbar and rotor overcurrent relay\n' ...
    '  - DC chopper hysteresis\n' ...
    '  - LVRT reactive-current priority\n' ...
    '  - stator breaker and resynchronization\n' ...
    '  - converter thermal/current duration limits']);
end

function addIn(sys,name,port,pos)
add_block('simulink/Ports & Subsystems/In1',[sys '/' name],'Position',pos,'Port',num2str(port));
end
function addOut(sys,name,port,pos)
add_block('simulink/Ports & Subsystems/Out1',[sys '/' name],'Position',pos,'Port',num2str(port));
end
function addB(lib,path,pos,varargin)
add_block(lib,path,'Position',pos,varargin{:});
end
function h=wire(sys,src,dst,name)
h=add_line(sys,src,dst,'autorouting','on');
if nargin>3 && ~isempty(name),set_param(h,'Name',name);end
end
function logLine(sys,name)
h=find_system(sys,'FindAll','on','SearchDepth',1,'Type','line','Name',name);
if ~isempty(h)
    src=get_param(h(1),'SrcPortHandle');
    set_param(src,'DataLogging','on','DataLoggingNameMode','Custom', ...
        'DataLoggingName',name);
end
end
function note(sys,pos,textValue)
a=Simulink.Annotation(sys,textValue);a.Position=pos;a.FontSize=10;a.ForegroundColor='blue';
end
function renderSystem(sys,file)
try
    open_system(sys);set_param(sys,'ZoomFactor','FitSystem');drawnow;
    print(['-s' sys],'-dpng','-r150',file);
catch ME
    warning('Render failed for %s: %s',sys,ME.message);
end
end
