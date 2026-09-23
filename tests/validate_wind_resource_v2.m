function R=validate_wind_resource_v2()
%VALIDATE_WIND_RESOURCE_V2 Functional acceptance of generated Wind-GFL v2.
root=fileparts(fileparts(mfilename('fullpath')));setup_v2_paths;
define_resource_buses(true);define_v2_parameters(true);define_wind_test_fixture(true);
m='wind_resource_standalone';load_system(fullfile(root,'models','resources',[m '.slx']));
w=[m '/Wind Resource'];ph=get_param(w,'PortHandles');
assert(numel(ph.Inport)==1&&numel(ph.Outport)==1&&numel([ph.LConn ph.RConn])==1);
assert(getSimulinkBlockHandle([w '/01 Wind Source and DC Side/DC Energy Delta'])>0);
assert(getSimulinkBlockHandle([w '/02 PCS/01 Local PLL'])>0);
assert(getSimulinkBlockHandle([w '/03 AC Interface/Step-up Transformer'])>0);
mark_bus(m,[w '/02 PCS/PCS Status'],'pcs_status');
mark_bus(m,[w '/01 Wind Source and DC Side/Source Status'],'source_status');
mark_bus(m,[w '/01 Wind Source and DC Side/PCS Command'],'wind_pcs_command');
R=struct();
R.A=run_case(m,'A_ZERO',5e6,0,0,0,0,0,10,11,0,.60);track(R.A,0,0,.12e6,.15e6);
R.B=run_case(m,'B_0_TO_2MW',5e6,0,0,2e6,0,0,10,11,0,.75);track(R.B,2e6,0,.16e6,.15e6);
R.C=run_case(m,'C_WIND_2_TO_3MW',2e6,1e6,5e6,0,0,0,10,11,0,.90);track(R.C,3e6,0,.24e6,.15e6);
assert(abs(R.C.ss.Pavailable-3e6)<.05e6&&abs(R.C.ss.Peffective-3e6)<.05e6);
R.D=run_case(m,'D_DISPATCH_2_TO_3MW',5e6,0,2e6,1e6,0,0,10,11,0,.90);track(R.D,3e6,0,.24e6,.15e6);
R.E=run_case(m,'E_Q_STEP',5e6,0,2e6,0,0,1e6,10,11,0,.90);track(R.E,2e6,1e6,.16e6,.12e6);
R.F=run_case(m,'F_ENABLE',5e6,0,2e6,0,0,0,.30,.55,1,.95);
off=R.F.x(:,1)>.40&R.F.x(:,1)<.52;rec=R.F.x(:,1)>.80;
assert(abs(mean(R.F.x(off,2)))<.15e6);
assert(max(abs(window(R.F.pcs.Id_ref_Apk,.40,.52)))<1);
assert(max(abs(window(R.F.pcs.Iq_ref_Apk,.40,.52)))<1);
assert(abs(mean(R.F.x(rec,2))-2e6)<.16e6);
R.G=run_case(m,'G_RATED_5MW',5e6,0,5e6,0,0,0,10,11,0,1.05);track(R.G,5e6,0,.40e6,.22e6);
R.H=run_case(m,'H_AVAILABLE_CAP',2e6,0,4e6,0,0,0,10,11,0,.90);track(R.H,2e6,0,.16e6,.15e6);
assert(abs(R.H.ss.Peffective-2e6)<.05e6);
R.I=run_case(m,'I_CIRCLE_LIMIT',8e6,0,8e6,0,6e6,0,10,11,0,1.10);
assert(R.I.ss.Pavailable<=5.001e6&&R.I.ss.Pdispatch<=5.001e6);
assert(R.I.ss.limit_factor<.98,'Wind circle limiter did not activate.');
Ilimit=evalin('base','V2.Wind.control.Ilimit_peak_A');
names=fieldnames(R);
for k=1:numel(names)
    r=R.(names{k});
    assert(all(isfinite(r.x),'all'),[r.name ' non-finite status']);
    assert(r.ss.phase_rms<.15,[r.name ' PLL phase error']);
    assert(r.ss.V>.85e4&&r.ss.V<1.10e4,[r.name ' PCC voltage band']);
    assert(r.ss.f>48&&r.ss.f<51,[r.name ' frequency band']);
    assert(r.dynamic.Iref_peak<=1.001*Ilimit,[r.name ' reference current limit']);
    assert(r.dynamic.Iactual_peak<=1.03*Ilimit,[r.name ' actual current limit']);
    assert(r.ss.energy>.80&&r.ss.energy<1.20,[r.name ' DC energy state']);
    assert(r.ss.Vdc>1200&&r.ss.Vdc<1800,[r.name ' DC voltage proxy']);
end
fprintf('WIND_RESOURCE_V2_ACCEPTANCE_PASS=1\n');close_system(m,0);
end

function mark_bus(m,p,name)
set_param(m,'SignalLogging','on','SignalLoggingName','logsout');ph=get_param(p,'PortHandles');
set_param(ph.Outport(1),'DataLogging','on','DataLoggingNameMode','Custom','DataLoggingName',name);
end

function r=run_case(m,name,pa0,dpa,p0,dp,q0,dq,toff,ton,drop,tstop)
s=[m '/Wind Command/'];src=[m '/Wind Resource/01 Wind Source and DC Side/'];
set_param([src 'Available Base'],'Value',num2str(pa0,16));
set_param([src 'Available Increment'],'After',num2str(dpa,16),'Time','.30');
set_param([s 'P Base'],'Value',num2str(p0,16));set_param([s 'P Increment'],'After',num2str(dp,16),'Time','.30');
set_param([s 'Q Base'],'Value',num2str(q0,16));set_param([s 'Q Increment'],'After',num2str(dq,16),'Time','.30');
set_param([s 'Enable Off'],'Time',num2str(toff,16),'After',num2str(-drop,16));
set_param([s 'Enable On'],'Time',num2str(ton,16),'After',num2str(drop,16));
set_param(m,'StopTime',num2str(tstop,16));o=sim(m);x=o.get('wind_v2_result');
pcs=read_bus(o.logsout.get('pcs_status').Values, ...
    {'phase_error_rad','Id_ref_Apk','Iq_ref_Apk','Iactual_Apk'});
srcb=read_bus(o.logsout.get('source_status').Values, ...
    {'available_power_W','dispatch_limit_W','energy_state_pu','Vdc_V'});
cmd=read_bus(o.logsout.get('wind_pcs_command').Values,{'P_ref_W'});
tail=x(:,1)>tstop-.12;r=struct('name',name,'x',x,'pcs',pcs,'source',srcb);
r.ss.P=mean(x(tail,2));r.ss.Q=mean(x(tail,3));r.ss.V=mean(x(tail,4));r.ss.f=mean(x(tail,5));
r.ss.Pavailable=mean(window(srcb.available_power_W,tstop-.12,tstop));
r.ss.Pdispatch=mean(window(srcb.dispatch_limit_W,tstop-.12,tstop));
r.ss.Peffective=mean(window(cmd.P_ref_W,tstop-.12,tstop));
r.ss.energy=mean(window(srcb.energy_state_pu,tstop-.12,tstop));
r.ss.Vdc=mean(window(srcb.Vdc_V,tstop-.12,tstop));
r.ss.limit_factor=mean(x(tail,8));
r.ss.phase_rms=rms(window(pcs.phase_error_rad,tstop-.12,tstop));
r.dynamic.Iref_peak=max(hypot(series(pcs.Id_ref_Apk),series(pcs.Iq_ref_Apk)));
r.dynamic.Iactual_peak=max(series(pcs.Iactual_Apk));print_case(r);
end

function b=read_bus(v,names)
b=struct();for k=1:numel(names),ts=v.(names{k});b.(names{k})=[ts.Time(:) squeeze(ts.Data(:))];end
end
function y=series(x),y=x(:,2);end
function y=window(x,a,b),k=x(:,1)>a&x(:,1)<b;y=x(k,2);end
function track(r,p,q,ptol,qtol)
assert(abs(r.ss.P-p)<ptol,[r.name ' P tracking']);assert(abs(r.ss.Q-q)<qtol,[r.name ' Q tracking']);
end
function print_case(r)
fprintf('%s P=%.4fMW Q=%.4fMvar Pav/Pdisp=%.3f/%.3fMW V=%.3fkV f=%.3fHz E=%.3f Vdc=%.1fV limit=%.4f Iref/Iactual=%.1f/%.1fA\n', ...
    r.name,r.ss.P/1e6,r.ss.Q/1e6,r.ss.Pavailable/1e6,r.ss.Pdispatch/1e6, ...
    r.ss.V/1e3,r.ss.f,r.ss.energy,r.ss.Vdc,r.ss.limit_factor, ...
    r.dynamic.Iref_peak,r.dynamic.Iactual_peak);
end
