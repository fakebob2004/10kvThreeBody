function metrics=validate_wind_balanced_sag()
% Wind-only commissioning fixture with physical machine excitation dip.
% The event exists only in memory. Rebuild the Wind harness before running.
root=setup_v2_paths; m='GRID_SUPPORTED_WIND_R1';
assert(~bdIsLoaded(m),'Close the Wind commissioning harness before this test.');
load_system(fullfile(root,'models','integration',[m '.slx']));
cleanup=onCleanup(@()close_system(m,0));
dc=[m '/Wind Resource/03 DC Link and Two-Level GSC/DC Control and Monitoring'];
assert(getSimulinkBlockHandle([dc '/Net DC Injection'])>0,'Rebuild the Wind harness first.');
fixture=[m '/Strong Synchronous Machine - Always Connected'];
load_system('simulink');
replace_block(fixture,'SearchDepth',1,'Name','Excitation','simulink/Sources/From Workspace','noprompt');
set_param([fixture '/Excitation'],'VariableName','excitationProfile','Interpolate','off', ...
 'OutputAfterFinalValue','Holding final value');
ctrl=[m '/Wind Resource/04 GFL Control and SPWM'];
observe([ctrl '/Converter Current abc'],'sag_actual_abc');
observe([dc '/Brake Current Limit'],'sag_brake_A');
observe([dc '/MSC DC Current Limit'],'sag_msc_A');
observe([dc '/Net DC Injection'],'sag_net_A');
in=Simulink.SimulationInput(m);
in=in.setVariable('excitationProfile',[0 1;.50 .35;.65 1;1.15 1].*[1 1e4*sqrt(2/3)]);
in=in.setBlockParameter([m '/Wind Resource/01 Wind Turbine Two-Mass Aerodynamics/Wind Speed Step'],'Time','10');
out=sim(in.setModelParameter('StopTime','1.15'));
w=out.integration_wind;t=w.Time;v=w.Data(:,9);
pre=t>=.40&t<.49;dip=t>=.54&t<.64;tail=t>=1.05;event=t>=.50;
metrics.pcc_dip_pu=mean(w.Data(dip,3))/mean(w.Data(pre,3));
metrics.peak_dc_V=max(v(event));metrics.recovered_dc_V=mean(v(tail));
metrics.recovered_P_ratio=mean(w.Data(tail,1))/mean(w.Data(pre,1));
metrics.recovered_pll_Hz=mean(w.Data(tail,4));
i=out.logsout.getElement('sag_actual_abc').Values;
if i.IsTimeFirst,abc=reshape(i.Data,numel(i.Time),3);else,abc=reshape(i.Data,3,numel(i.Time)).';end
converter=evalin('base','Converter');ibase=sqrt(2)*converter.Sn/(sqrt(3)*converter.Vll);
metrics.actual_phase_peak_pu=max(abs(abc(i.Time>=.50,:)),[],'all')/ibase;
br=out.logsout.getElement('sag_brake_A').Values;
msc=out.logsout.getElement('sag_msc_A').Values;net=out.logsout.getElement('sag_net_A').Values;
tb=net.Time(:);ib=sampleHold(br,tb);
metrics.brake_peak_A=max(ib(tb>=.50));
metrics.current_balance_A=max(abs(net.Data(:)-sampleHold(msc,tb)+ib));
metrics.brake_energy_J=trapz(tb,max(0,ib).*interp1(t,v,tb,'linear','extrap'));
disp(metrics);
assert(all(isfinite(struct2array(metrics))) && metrics.pcc_dip_pu<.65 && metrics.pcc_dip_pu>.15);
assert(abs(mean(v(pre))-1500)<75 && mean(w.Data(pre,1))>2e6);
assert(metrics.current_balance_A<1e-4 && metrics.brake_energy_J>0 && metrics.brake_peak_A<=4000);
assert(metrics.peak_dc_V<1800 && abs(metrics.recovered_dc_V-1500)<75);
assert(metrics.actual_phase_peak_pu<1.6 && abs(metrics.recovered_P_ratio-1)<.1);
assert(abs(metrics.recovered_pll_Hz-50)<.1);
end
function observe(block,name)
p=get_param(block,'PortHandles');
set_param(p.Outport(1),'DataLogging','on','DataLoggingNameMode','Custom','DataLoggingName',name);
end
function y=sampleHold(x,t)
[tx,k]=unique(x.Time,'last');y=interp1(tx,x.Data(k),t,'previous','extrap');y=y(:);
end
