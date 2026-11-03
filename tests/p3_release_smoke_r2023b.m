function p3_release_smoke_r2023b
% Native R2023b port/update/seed smoke, not full cross-release acceptance.
assert(strcmp(version('-release'),'2023b'));r=setup_v2_paths;
s=load(fullfile(r,'parameters','initial_states','bw_wind_grid_seed.mat'),'op');
for n={'PV_WIND_BESS_ISLAND_R1','PV_WIND_BESS_SM_FIXED_R1'}
 m=n{1};f=fullfile(r,'models','r2023b',[m '.slx']);assert(~bdIsLoaded(m));load_system(f);c=onCleanup(@()close_system(m,0));
 assert(strcmp(get_param(m,'FileName'),f));
 in=Simulink.SimulationInput(m);in=in.setVariable('p3ReleaseSeed',s.op).setBlockParameter([m '/Close permit'],'Value','0').setModelParameter('SimscapeUseOperatingPoints','on','SimscapeOperatingPoint','p3ReleaseSeed','StopTime','.003','ReturnWorkspaceOutputs','on');
 o=sim(in);pv=o.integration_pv;w=o.integration_wind;g=o.integration_sm;i=o.bw_tie;
 z=[g.Time(end),pv.Data(1,9),w.Data(1,9),max(g.Data(:,3)),max(abs(i.Data(:)))];
 fprintf('P3_R2023B_SMOKE %s %s\n',m,mat2str(z,8));
 assert(all(isfinite([pv.Data(:);w.Data(:);g.Data(:);i.Data(:)])) && z(1)>=.003-1e-9 && all(abs(z(2:3)-1500)<75) && z(4)<15000 && z(5)<2);
 clear c
end
tags={'local','coordinated'};out=tempname;mkdir(out);
for k=0:1
 p3_multi_island(k,out,true);q=jsondecode(fileread(fullfile(out,[tags{k+1} '.json'])));assert(strcmp(q.state,'smoke_only'));
end
out=tempname;mkdir(out);p3_lvrt_zero_batch(out,true);
for k=0:1
 q=jsondecode(fileread(fullfile(out,[tags{k+1} '.json'])));if isfield(q,'error'),error('%s',q.error);end;assert(strcmp(q.state,'smoke_only'));
end
disp('P3_R2023B_BOTH_HARNESSES_SMOKE_PASS');
end
