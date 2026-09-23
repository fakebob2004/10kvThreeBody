function R=validate_pv_resource_v2()
%VALIDATE_PV_RESOURCE_V2 Functional acceptance of the generated PV resource.
root=fileparts(fileparts(mfilename('fullpath')));setup_v2_paths;
define_resource_buses(true);define_v2_parameters(true);define_strong_machine_fixture(true);
m='pv_resource_standalone';load_system(fullfile(root,'models','resources',[m '.slx']));
pv=[m '/PV Resource'];ph=get_param(pv,'PortHandles');
assert(numel(ph.Inport)==1&&numel(ph.Outport)==1&&numel([ph.LConn ph.RConn])==1, ...
    'PV Resource must expose CommandBus, StatusBus and one PCC port only.');
assert(getSimulinkBlockHandle([pv '/01 PV Source and DC Side'])>0);
assert(getSimulinkBlockHandle([pv '/02 PCS/01 Local PLL'])>0);
assert(getSimulinkBlockHandle([pv '/03 AC Interface/Step-up Transformer'])>0);
mark_pcs_status(m);
Qpf=5e6*tan(acos(.9));R=struct();
R.A=run_case(m,'A_ZERO',0,0,0,0,10,11,0,.60,.30);
track(R.A,0,0,.12e6,.12e6);
R.B=run_case(m,'B_0_TO_2MW',0,2e6,0,0,10,11,0,.75,.30);
track(R.B,2e6,0,.08*2e6,.15e6);
R.C=run_case(m,'C_2_TO_3MW',2e6,1e6,0,0,10,11,0,.90,.30);
track(R.C,3e6,0,.08*3e6,.15e6);
R.D=run_case(m,'D_Q_STEP',2e6,0,0,1e6,10,11,0,.90,.30);
track(R.D,2e6,1e6,.08*2e6,.12e6);
R.E=run_case(m,'E_ENABLE',2e6,0,0,0,.30,.55,1,.95,.30);
off=R.E.x(:,1)>.40&R.E.x(:,1)<.52;rec=R.E.x(:,1)>.80;
assert(abs(mean(R.E.x(off,2)))<.15e6,'Enable-off active power failed.');
assert(max(abs(window(R.E.pcs.Id_ref_Apk,.40,.52)))<1);
assert(max(abs(window(R.E.pcs.Iq_ref_Apk,.40,.52)))<1);
assert(abs(mean(R.E.x(rec,2))-2e6)<.16e6,'Enable recovery failed.');
R.F=run_case(m,'F_RATED_P',5e6,0,0,0,10,11,0,1.05,.30);
track(R.F,5e6,0,.08*5e6,.20e6);
R.G=run_case(m,'G_PF_0P9',5e6,0,Qpf,0,10,11,0,1.10,.30);
track(R.G,5e6,Qpf,.08*5e6,.20e6);
assert(hypot(R.G.ss.P,R.G.ss.Q)<6.25e6);
R.H=run_case(m,'H_CIRCLE_LIMIT',8e6,0,6e6,0,10,11,0,1.00,.30);
assert(R.H.ss.limit_factor<.98,'Circle limiter did not activate.');
Ilimit=evalin('base','V2.PV.control.Ilimit_peak_A');
assert(R.H.dynamic.Iref_peak<=1.001*Ilimit);
assert(R.H.dynamic.Iactual_peak<=1.03*Ilimit);
names=fieldnames(R);
for k=1:numel(names)
    r=R.(names{k});
    assert(all(isfinite(r.x),'all'),[r.name ' non-finite status']);
    assert(r.ss.phase_rms<.15,[r.name ' PLL phase error']);
    assert(r.ss.V>.85e4&&r.ss.V<1.10e4,[r.name ' PCC voltage band']);
    assert(r.ss.f>48&&r.ss.f<51,[r.name ' frequency band']);
end
fprintf('PV_RESOURCE_V2_ACCEPTANCE_PASS=1\n');close_system(m,0);
end

function mark_pcs_status(m)
p=[m '/PV Resource/02 PCS/PCS Status'];ph=get_param(p,'PortHandles');
set_param(m,'SignalLogging','on','SignalLoggingName','logsout');
set_param(ph.Outport(1),'DataLogging','on','DataLoggingNameMode','Custom','DataLoggingName','pcs_status');
end

function r=run_case(m,name,p0,dp,q0,dq,toff,ton,drop,tstop,event)
s=[m '/PV Command/'];
set_param([s 'P Base'],'Value',num2str(p0,16));
set_param([s 'P Increment'],'After',num2str(dp,16),'Time',num2str(event,16));
set_param([s 'Q Base'],'Value',num2str(q0,16));
set_param([s 'Q Increment'],'After',num2str(dq,16),'Time',num2str(event,16));
set_param([s 'Enable Off'],'Time',num2str(toff,16),'After',num2str(-drop,16));
set_param([s 'Enable On'],'Time',num2str(ton,16),'After',num2str(drop,16));
set_param(m,'StopTime',num2str(tstop,16));o=sim(m);x=o.get('pv_v2_result');
pcs=read_pcs(o.logsout.get('pcs_status').Values);tail=x(:,1)>tstop-.12;
r=struct('name',name,'x',x,'pcs',pcs);r.ss=struct( ...
    'P',mean(x(tail,2)),'Q',mean(x(tail,3)),'V',mean(x(tail,4)), ...
    'f',mean(x(tail,5)),'limit_factor',mean(x(tail,8)), ...
    'phase_rms',rms(window(pcs.phase_error_rad,tstop-.12,tstop)));
r.dynamic.Iref_peak=max(hypot(series(pcs.Id_ref_Apk),series(pcs.Iq_ref_Apk)));
r.dynamic.Iactual_peak=max(series(pcs.Iactual_Apk));
print_case(r);
end

function p=read_pcs(v)
names={'phase_error_rad','Id_ref_Apk','Iq_ref_Apk','Iactual_Apk'};p=struct();
for k=1:numel(names),ts=v.(names{k});p.(names{k})=[ts.Time(:) squeeze(ts.Data(:))];end
end
function y=series(x),y=x(:,2);end
function y=window(x,a,b),k=x(:,1)>a&x(:,1)<b;y=x(k,2);end
function track(r,p,q,ptol,qtol)
assert(abs(r.ss.P-p)<ptol,[r.name ' P tracking']);
assert(abs(r.ss.Q-q)<qtol,[r.name ' Q tracking']);
end
function print_case(r)
fprintf('%s P=%.4fMW Q=%.4fMvar V=%.3fkV f=%.3fHz phase=%.4f limit=%.4f Iref/Iactual=%.1f/%.1fApeak\n', ...
    r.name,r.ss.P/1e6,r.ss.Q/1e6,r.ss.V/1e3,r.ss.f,r.ss.phase_rms, ...
    r.ss.limit_factor,r.dynamic.Iref_peak,r.dynamic.Iactual_peak);
end
