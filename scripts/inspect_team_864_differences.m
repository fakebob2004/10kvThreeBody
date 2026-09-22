% Read-only parameter comparison for the two teammate revisions.
root=fileparts(fileparts(mfilename('fullpath')));
mods={'Wind_PV_SOC_DCAC_864','Wind_PV_SOC_DCAC_864_5MW'};
warning('off','all');
for i=1:2,load_system(fullfile(root,[mods{i} '.slx']));end
A=scan_model(mods{1}); B=scan_model(mods{2});
allKeys=union(A.keys,B.keys);
fprintf('=== PARAMETER/BLOCK DIFFERENCES 864 -> 5MW ===\n');
for i=1:numel(allKeys)
    key=allKeys{i}; inA=isKey(A,key); inB=isKey(B,key);
    if ~inA
        fprintf('ADDED %s | %s\n',key,B(key));
    elseif ~inB
        fprintf('REMOVED %s | %s\n',key,A(key));
    elseif ~strcmp(A(key),B(key))
        fprintf('CHANGED %s\n A:%s\n B:%s\n',key,A(key),B(key));
    end
end
for i=1:2,close_system(mods{i},0);end

% The Chinese source filename cannot be loaded directly by this MATLAB
% release, so copy it read-only to an ASCII temporary filename for inspection.
tempInitial=fullfile(tempdir,'team_864_initial_readonly.slx');
copyfile(fullfile(root,'Wind_PV_SOC_DCAC_初始.slx'),tempInitial,'f');
h=load_system(tempInitial); initialModel=get_param(h,'Name');
load_system(fullfile(root,[mods{1} '.slx']));
A=scan_model(initialModel); B=scan_model(mods{1}); allKeys=union(A.keys,B.keys);
fprintf('=== PARAMETER/BLOCK DIFFERENCES INITIAL -> 864 ===\n');
for i=1:numel(allKeys)
    key=allKeys{i}; inA=isKey(A,key); inB=isKey(B,key);
    if ~inA
        fprintf('ADDED %s | %s\n',key,B(key));
    elseif ~inB
        fprintf('REMOVED %s | %s\n',key,A(key));
    elseif ~strcmp(A(key),B(key))
        fprintf('CHANGED %s\n A:%s\n B:%s\n',key,A(key),B(key));
    end
end
close_system(initialModel,0); close_system(mods{1},0);

function map=scan_model(model)
map=containers.Map('KeyType','char','ValueType','char');
blocks=find_system(model,'LookUnderMasks','all','FollowLinks','off','Type','Block');
for j=2:numel(blocks)
    rel=char(extractAfter(blocks{j},strlength(model)+1));
    blockType=get_param(blocks{j},'BlockType'); value=['type=' blockType];
    try
        switch blockType
            case 'Gain'
                value=[value '|Gain=' get_param(blocks{j},'Gain')];
            case 'Constant'
                value=[value '|Value=' get_param(blocks{j},'Value')];
            case 'TransferFcn'
                value=[value '|Num=' get_param(blocks{j},'Numerator') ...
                    '|Den=' get_param(blocks{j},'Denominator')];
            case 'DiscreteIntegrator'
                value=[value '|gain=' get_param(blocks{j},'gainval') ...
                    '|IC=' get_param(blocks{j},'InitialCondition')];
        end
    catch
    end
    try
        names=get_param(blocks{j},'MaskNames'); vals=get_param(blocks{j},'MaskValues');
        if ~isempty(names)
            value=[value '|MASK:' strjoin(strcat(names,'=',vals),';')];
        end
    catch
    end
    map(rel)=value;
end
end
