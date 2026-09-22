% One-process R8 stage: replace cross-subsystem Simulink wires by explicit
% named global routes.  Simscape conserving connections are never touched.
scriptDir=fileparts(mfilename('fullpath'));
projectRoot=fileparts(scriptDir);
modelName='BESS_GFM_10kV_Readable_R8';
modelFile=fullfile(projectRoot,'build',[modelName '.slx']);
load_system(modelFile);
route_top_level_signals(modelName);
save_system(modelName,modelFile);
close_system(modelName,0);
fprintf('R8_SIGNAL_ROUTING_OK=1\n');

function route_top_level_signals(model)
lines=find_system(model,'FindAll','on','SearchDepth',1,'Type','line');
routes=struct('src',{},'srcParent',{},'srcPort',{},'tag',{},'dst',{});
for k=1:numel(lines)
    src=get_param(lines(k),'SrcPortHandle');
    if isempty(src)||src<0||~strcmp(get_param(src,'PortType'),'outport'),continue;end
    dst=get_param(lines(k),'DstPortHandle');
    if isempty(dst),continue;end
    srcParent=get_param(src,'Parent');
    srcPort=as_number(get_param(src,'PortNumber'));
    idx=find([routes.src]==src,1);
    if isempty(idx)
        label=get_param(lines(k),'Name');if isempty(label),label='signal';end
        key=regexprep(get_param(srcParent,'Name'),'[^A-Za-z0-9]','_');
        tag=sprintf('R8_%s_p%d_%s',key,srcPort,regexprep(label,'[^A-Za-z0-9_]','_'));
        idx=numel(routes)+1;
        routes(idx)=struct('src',src,'srcParent',srcParent,'srcPort',srcPort, ...
            'tag',tag,'dst',dst(:).');
    else
        routes(idx).dst=unique([routes(idx).dst dst(:).'],'stable');
    end
end
if isempty(routes),return;end

% Delete the known ordinary top-level signal lines before changing ports.
for k=1:numel(routes)
    try
        h=get_param(routes(k).src,'Line');if h>0,delete_line(h);end
    catch
    end
end

keys=arrayfun(@(r)sprintf('%s|%08d',r.srcParent,999999-r.srcPort),routes, ...
    'UniformOutput',false);
[~,ix]=sort(keys);routes=routes(ix);
for k=1:numel(routes)
    r=routes(k);b=find_port_block(r.srcParent,'Outport',r.srcPort);
    if isempty(b),continue;end
    pos=get_param(b,'Position');p=get_param(b,'PortHandles');
    line=get_param(p.Inport,'Line');up=-1;if line>0,up=get_param(line,'SrcPortHandle');end
    delete_block(b);
    g=[r.srcParent '/route_' r.tag];
    add_block('simulink/Signal Routing/Goto',g,'GotoTag',r.tag, ...
        'TagVisibility','global','ShowName','off','Position',pos);
    gp=get_param(g,'PortHandles');
    if up>0&&get_param(gp.Inport,'Line')<0,add_line(r.srcParent,up,gp.Inport,'autorouting','on');end
end

dest=struct('parent',{},'port',{},'tag',{});
for k=1:numel(routes)
    for j=1:numel(routes(k).dst)
        d=routes(k).dst(j);
        if d<0||~strcmp(get_param(d,'PortType'),'inport'),continue;end
        dest(end+1)=struct('parent',get_param(d,'Parent'), ...
            'port',as_number(get_param(d,'PortNumber')),'tag',routes(k).tag); %#ok<AGROW>
    end
end
keys=arrayfun(@(d)sprintf('%s|%08d',d.parent,999999-d.port),dest, ...
    'UniformOutput',false);
[~,ix]=sort(keys);dest=dest(ix);
for k=1:numel(dest)
    d=dest(k);b=find_port_block(d.parent,'Inport',d.port);
    if isempty(b),continue;end
    pos=get_param(b,'Position');p=get_param(b,'PortHandles');
    line=get_param(p.Outport,'Line');down=[];
    if line>0,down=get_param(line,'DstPortHandle');end
    delete_block(b);
    f=[d.parent '/route_' d.tag];
    if getSimulinkBlockHandle(f)>0,f=[f '_' num2str(d.port)];end
    add_block('simulink/Signal Routing/From',f,'GotoTag',d.tag, ...
        'ShowName','off','Position',pos);
    fp=get_param(f,'PortHandles');
    for q=1:numel(down)
        if down(q)>0&&get_param(down(q),'Line')<0
            add_line(d.parent,fp.Outport,down(q),'autorouting','on');
        end
    end
end
end

function b=find_port_block(parent,type,port)
b=find_system(parent,'SearchDepth',1,'BlockType',type);keep=false(size(b));
for n=1:numel(b),keep(n)=as_number(get_param(b{n},'Port'))==port;end
b=b(keep);if isempty(b),b=[];else,b=b{1};end
end

function x=as_number(v)
if isnumeric(v),x=double(v);else,x=str2double(v);end
end
