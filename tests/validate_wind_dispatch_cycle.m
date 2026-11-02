function R=validate_wind_dispatch_cycle(model)
% Strong-grid event sequence. Enable controls generation, GSC maintains DC voltage.
if nargin==0, model='GRID_SUPPORTED_WIND_R1'; end
root=setup_v2_paths;
assert(~bdIsLoaded(model),'Close the model before running this in-memory harness.');
load_system(fullfile(root,'models','integration',[model '.slx']));
load_system('simulink');
cleanup=onCleanup(@()close_system(model,0));
in=Simulink.SimulationInput(model);
cmd=[model '/Wind Command'];
signals={'Q Reference','Enable'};
values={[0 0;.30 1e6;.60 -1e6;1.50 -1e6],[0 1;.88 0;1.15 1;1.50 1]};
for k=1:2
 b=[cmd '/' signals{k}];name=sprintf('windProfile%d',k);
 replace_block(cmd,'SearchDepth',1,'Name',signals{k},'simulink/Sources/From Workspace','noprompt');
 set_param(b,'VariableName',name,'Interpolate','off','OutputAfterFinalValue','Holding final value');
 in=in.setVariable(name,values{k});
end
in=in.setBlockParameter([model '/Wind Resource/01 Wind Turbine Two-Mass Aerodynamics/Wind Speed Step'],'Time','10');
if contains(model,'PV'),in=in.setBlockParameter([model '/PV Command/P Increment'],'Time','10');end
out=sim(in.setModelParameter('StopTime','1.5','SimulationMode','accelerator'));
w=out.integration_wind;t=w.Time;d=w.Data;
windows=[.53 .59;.81 .87;1.08 1.14;1.43 1.49];R=zeros(4,6);
for k=1:4
 ix=t>=windows(k,1)&t<=windows(k,2);v=d(ix,[1 2 4 6 9 11]);
 R(k,:)=trapz(t(ix),v)/(max(t(ix))-min(t(ix)));
end
disp(array2table(R,'VariableNames',{'P_W','Q_var','Hz','MSC_headroom_W','Vdc','healthy'}));
assert(max(abs(R(:,2)-[1e6;-1e6;0;-1e6]))<0.12e6,'Reactive tracking failed');
assert(abs(R(3,1))<.15e6&&min(R([1 2 4],1))>2.8e6,'Generation stop or recovery failed');
assert(max(abs(R(:,3)-50))<.05&&max(abs(R(:,5)-1500))<75&&all(R(:,6)>.99));
assert(max(R([1 2 4],4))<.1e6,'Full MPPT reports fictitious reserve');
assert(abs(R(3,4))<1,'Standby reports dispatchable reserve');
active=t>=.25;
fprintf('Event-window Vdc range %.1f to %.1f V; PLL range %.3f to %.3f Hz\n', ...
 min(d(active,9)),max(d(active,9)),min(d(active,4)),max(d(active,4)));
assert(all(isfinite(d(:))) && min(d(active,9))>1350 && max(d(active,9))<1650, ...
 'DC voltage exceeded the transient envelope during the switching sequence');
fprintf('WIND_DISPATCH_CYCLE_PASS=1\n');
end
