% Unit acceptance for the external Resource API/coordinator contract.
run(fullfile(fileparts(mfilename('fullpath')),'define_stage2_resource_api.m'));
status=zeros(3,12);status(:,7)=1;status(:,8)=1;
status(1,9)=.55;status(2:3,5)=[3e6;2e6];
cmd=[1e6 0 1 1;4e6 0 1 1;4e6 0 1 1];
y=stage2_coordinator_algorithm(status,cmd,1,S2_API.coordinator_config);
assert(y(1,1)==1e6&&y(2,1)==3e6&&y(3,1)==2e6,'Available-power clamp failed.');
status(1,9)=.20;cmd(1,1)=2e6;y=stage2_coordinator_algorithm(status,cmd,1,S2_API.coordinator_config);
assert(y(1,1)<=0,'BESS SOC-min discharge interlock failed.');
status(1,9)=.90;cmd(1,1)=-2e6;y=stage2_coordinator_algorithm(status,cmd,1,S2_API.coordinator_config);
assert(y(1,1)>=0,'BESS SOC-max charge interlock failed.');
status(2,8)=0;y=stage2_coordinator_algorithm(status,cmd,1,S2_API.coordinator_config);
assert(all(y(2,1:3)==0),'Health interlock failed.');
cmd(:,4)=0;y=stage2_coordinator_algorithm(status,cmd,0,S2_API.coordinator_config);
assert(y(1,4)==0&&y(3,1)==cmd(3,1),'Autonomous pass-through failed.');
fprintf('STAGE2_RESOURCE_API_UNIT_PASS=1\n');
