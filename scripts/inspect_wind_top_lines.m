root=fileparts(fileparts(mfilename('fullpath')));m='Wind_GFL_5MW_SystemLevel_SM_R1';
load_system(fullfile(root,'build',[m '.slx']));
ln=find_system(m,'FindAll','on','SearchDepth',1,'Type','line');
for k=1:numel(ln)
 s=get_param(ln(k),'SrcPortHandle');d=get_param(ln(k),'DstPortHandle');
 try,c=get_param(ln(k),'Connected');catch,c='?';end
 fprintf('line=%g src=%s dst=%s connected=%s pts=%s\n',ln(k),mat2str(s),mat2str(d),string(c),mat2str(get_param(ln(k),'Points')));
end
fprintf('\nPORTS\n');
b=find_system(m,'SearchDepth',1,'Type','Block');
for k=2:numel(b)
 p=get_param(b{k},'PortHandles');
 fprintf('%s pos=%s in=%s out=%s L=%s R=%s\n',get_param(b{k},'Name'), ...
  mat2str(get_param(b{k},'Position')),mat2str(p.Inport),mat2str(p.Outport),mat2str(p.LConn),mat2str(p.RConn));
end
for path={[m '/01 Wind-GFL System-Level Branch'],[m '/Strong Synchronous Machine (Governor + AVR)'],[m '/Physical Network Solver']}
 p=get_param(path{1},'PortHandles');fprintf('EXPLICIT %s\n',path{1});
 hs=[p.Inport(:);p.Outport(:);p.LConn(:);p.RConn(:)];
 for h=hs.'
  fprintf(' port=%g type=%s line=%g pos=%s\n',h,get_param(h,'PortType'),get_param(h,'Line'),mat2str(get_param(h,'Position')));
 end
end
close_system(m,0);
