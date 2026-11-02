function report=run_grid_supported_component_checks(selection)
%RUN_GRID_SUPPORTED_COMPONENT_CHECKS Read-only commissioning of supplied sources.
if nargin<1,selection={};end
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_v2_paths;
evidence=fullfile(root,'artifacts','grid_supported_integration');
if ~exist(evidence,'dir'),mkdir(evidence);end
cache=fullfile(tempdir,'pvwind_grid_supported_cache');if ~exist(cache,'dir'),mkdir(cache);end
Simulink.fileGenControl('set','CacheFolder',cache,'CodeGenFolder',cache);
report=struct('island_operation',false,'matlab_version',version, ...
 'pv_commit','ca7a100','stages',struct());
previous=fullfile(evidence,'component_checks.mat');
if ~isempty(selection)&&isfile(previous),old=load(previous,'report');report=old.report;end
names={'pv_dispatch','pv_mppt','pv_limit','wind_operating_point','wind_step'};
actions={@validate_pv_dynamic_physical,@validate_pv_dynamic_mppt, ...
 @validate_pv_dynamic_limit,@()evalin('base',sprintf('run(''%s'')',fullfile(root,'scripts','validate_wind_pmsg_transient_r3.m'))), ...
 @()evalin('base',sprintf('run(''%s'')',fullfile(root,'scripts','validate_wind_pmsg_transient_r3_step.m')))};
for k=1:numel(names)
 if ~isempty(selection)&&~ismember(names{k},selection),continue,end
 name=names{k};fprintf('\nINTEGRATION_COMPONENT_START=%s\n',name);started=tic;
 try
  if k<=3,result=actions{k}();else,actions{k}();result=struct();end
  report.stages.(name)=struct('pass',true,'elapsed_s',toc(started),'metrics',result);
 catch ME
  report.stages.(name)=struct('pass',false,'elapsed_s',toc(started), ...
   'identifier',ME.identifier,'error',getReport(ME,'extended','hyperlinks','off'));
  fprintf('INTEGRATION_COMPONENT_ERROR=%s\n%s\n',name,report.stages.(name).error);
 end
 fid=fopen(fullfile(evidence,'component_checks.json'),'w');
 fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));fclose(fid);
 save(fullfile(evidence,'component_checks.mat'),'report');
 bdclose('all');
 fprintf('INTEGRATION_COMPONENT_END=%s PASS=%d\n',name,report.stages.(name).pass);
end
fprintf('GRID_SUPPORTED_COMPONENT_CHECKS_FINISHED=1\n');
end
