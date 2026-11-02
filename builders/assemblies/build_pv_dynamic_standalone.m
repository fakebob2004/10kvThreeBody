function modelFile=build_pv_dynamic_standalone()
%BUILD_PV_DYNAMIC_STANDALONE R2024b physical PV / strong synchronous machine.
root=setup_v2_paths;define_resource_buses(true);C=define_v2_parameters(false);
C.PV.dynamic.enabled=true;C.PV.filter.topology='LCL';assignin('base','V2',C);
m='pv_resource_dynamic_standalone';folder=fullfile(root,'models','resources');
if ~exist(folder,'dir'),mkdir(folder);end
modelFile=fullfile(folder,[m '.slx']);if bdIsLoaded(m),close_system(m,0);end
new_system(m);open_system(m);load_system('ee_lib');load_system('fl_lib');load_system('nesl_utility');
build_pv_resource(m,'PV Resource','V2.PV',[280 170 660 430]);
add_command(m);
pv_dyn_helpers('line',m,'PV Command/1','PV Resource/1');
add_machine(m);
pv_dyn_helpers('block',m,'Physical Solver','nesl_utility/Solver Configuration',[740 520 810 575]);
pv_dyn_helpers('wire',m,'Physical Solver','RConn',1,'PV Resource','RConn',1);
pv_dyn_helpers('block',m,'Telemetry','simulink/Sinks/To Workspace',[720 450 880 490], ...
 'VariableName','pv_dynamic_status','SaveFormat','Timeseries','MaxDataPoints','inf');
pv_dyn_helpers('line',m,'PV Resource/1','Telemetry/1');
set_param(m,'SolverType','Fixed-step','Solver','ode14x','FixedStep','5e-5', ...
 'SimulationMode','accelerator','StopTime','1.0', ...
 'ReturnWorkspaceOutputs','on','InitFcn', ...
 ['setup_v2_paths; define_resource_buses(true); V2=define_v2_parameters(false); ' ...
 'V2.PV.dynamic.enabled=true; V2.PV.filter.topology=''LCL'';']);
v2_disable_previews(m);v2_route_level(m);
set_param(m,'SimulationCommand','update');save_system(m,modelFile);
fprintf('PV_DYNAMIC_BUILD_PASS=1\nMODEL=%s\n',modelFile);
end

function add_command(m)
s=pv_dyn_helpers('sub',m,'PV Command',[35 210 210 390]);
B=@(n,l,p,varargin)pv_dyn_helpers('block',s,n,l,p,varargin{:});L=@(a,b)pv_dyn_helpers('line',s,a,b);
B('P Base','simulink/Sources/Constant',[20 30 110 60],'Value','2e6');
B('P Increment','simulink/Sources/Step',[20 90 110 120],'Time','0.3','Before','0','After','1e6');
B('P ref','simulink/Math Operations/Sum',[155 40 185 100],'Inputs','++');
L('P Base/1','P ref/1');L('P Increment/1','P ref/2');
names={'Q Base','V ref','f ref','Enable','Mode'};vals={'0','690','50','1','0'};
for k=1:5,B(names{k},'simulink/Sources/Constant',[220 20+60*k 310 50+60*k],'Value',vals{k});end
B('Enable Off','simulink/Sources/Step',[220 410 310 440],'Time','10','Before','0','After','-1');
B('Enable On','simulink/Sources/Step',[220 460 310 490],'Time','11','Before','0','After','1');
B('Enable Profile','simulink/Math Operations/Sum',[335 350 365 440],'Inputs','+++');
L('Enable/1','Enable Profile/1');L('Enable Off/1','Enable Profile/2');L('Enable On/1','Enable Profile/3');
B('Resource Command','simulink/Signal Routing/Bus Creator',[370 30 375 360], ...
 'Inputs','6','OutDataTypeStr','Bus: ResourceCommandBus');
sig={'P ref/1','Q Base/1','V ref/1','f ref/1','Enable Profile/1','Mode/1'};
fields={'P_ref_W','Q_ref_var','V_ref_V','f_ref_Hz','enable','mode'};
for k=1:6,v2_named_line(s,sig{k},sprintf('Resource Command/%d',k),fields{k});end
pv_dyn_helpers('port',s,'ResourceCommandBus',1,'Out',[435 180 465 194]);L('Resource Command/1','ResourceCommandBus/1');
end

function add_machine(m)
s=pv_dyn_helpers('sub',m,'Strong Synchronous Machine Test Grid',[850 160 1230 430]);
B=@(n,l,p,varargin)pv_dyn_helpers('block',s,n,l,p,varargin{:});
L=@(a,b)pv_dyn_helpers('line',s,a,b);W=@(a,as,ai,b,bs,bi)pv_dyn_helpers('wire',s,a,as,ai,b,bs,bi);
v2_add_pmio(s,'PCC',1,'Left','foundation.electrical.three_phase',[20 90 50 120]);
B('Synchronous Machine',sprintf('ee_lib/Electromechanical/Synchronous/Simplified\nSynchronous Machine'), ...
 [420 70 550 200],'SRated','100e6','VRated','10e3','FRated','50', ...
 'nPolePairs','1','Vmag0','10e3','Pt0','0','Qt0','0','R_si','0.01','L_si','0.001');
W('PCC','LConn',1,'Synchronous Machine','RConn',2);
B('Neutral','fl_lib/Electrical/Electrical Elements/Electrical Reference',[620 210 650 240]);
W('Synchronous Machine','RConn',3,'Neutral','LConn',1);
B('Excitation','simulink/Sources/Constant',[40 260 160 290],'Value','1e4*sqrt(2/3)');
pv_dyn_helpers('sps',s,'Excitation PS','V',[220 260 320 295]);L('Excitation/1','Excitation PS/1');
W('Excitation PS','RConn',1,'Synchronous Machine','LConn',1);
B('Governor Speed','simulink/Sources/Constant',[40 350 160 380],'Value','2*pi*50');
pv_dyn_helpers('sps',s,'Speed PS','rad/s',[220 350 320 385]);L('Governor Speed/1','Speed PS/1');
B('Ideal Governor',sprintf('fl_lib/Mechanical/Mechanical Sources/Ideal Angular\nVelocity Source'),[430 330 490 390]);
B('Mechanical Reference',sprintf('fl_lib/Mechanical/Rotational Elements/Mechanical\nRotational Reference'),[550 420 590 450]);
W('Speed PS','RConn',1,'Ideal Governor','RConn',1);
W('Ideal Governor','LConn',1,'Synchronous Machine','LConn',2);
W('Ideal Governor','RConn',2,'Mechanical Reference','LConn',1);
W('Synchronous Machine','LConn',3,'Mechanical Reference','LConn',1);
% Consume the machine's physical measurement output explicitly.
pv_dyn_helpers('pss',s,'Machine Measurements','1',[620 90 740 125]);
W('Synchronous Machine','RConn',1,'Machine Measurements','LConn',1);
B('Machine Record','simulink/Sinks/To Workspace',[790 90 930 125], ...
 'VariableName','pv_test_machine','SaveFormat','Timeseries');L('Machine Measurements/1','Machine Record/1');
pv_dyn_helpers('wire',m,'PV Resource','RConn',1,'Strong Synchronous Machine Test Grid','LConn',1);
end
