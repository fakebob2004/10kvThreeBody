function diagnose_pv_v2_electrical()
%DIAGNOSE_PV_V2_ELECTRICAL Compare accepted and v2 electrical block semantics.
root=fileparts(fileparts(mfilename('fullpath')));
setup_v2_paths; define_resource_buses(true); define_v2_parameters(true);
models={ ...
    fullfile(root,'build','PV_GFL_864_SystemLevel_SM_R2_1_Readable.slx'), ...
    fullfile(root,'models','resources','pv_resource_standalone.slx')};
paths={ ...
    'PV_GFL_864_SystemLevel_SM_R2_1_Readable/01 PV-GFL Branch R2.1', ...
    'pv_resource_standalone/PV Resource/03 AC Interface'};
for n=1:2
    load_system(models{n});
    fprintf('\n=== %s ===\n',bdroot(paths{n}));
    blocks=find_system(paths{n},'LookUnderMasks','all','FollowLinks','on','Type','Block');
    for k=1:numel(blocks)
        rt=get_param(blocks{k},'ReferenceBlock');
        if contains(rt,'Transformer') || contains(rt,'Current and Voltage') || contains(rt,'RLC')
            fprintf('\nBLOCK=%s\nREF=%s\n',blocks{k},rt);
            dump(blocks{k},{'Orientation','component_structure','R','L','C', ...
                'VRated1','VRated2','SRated','Winding1Connection','Winding2Connection', ...
                'pu_Rw1','pu_Rw2','leakage_reactance_option','vMeasurementType'});
            ph=get_param(blocks{k},'PortHandles');
            fprintf('PORTS L=%s R=%s\n',mat2str(ph.LConn),mat2str(ph.RConn));
        end
    end
end
fprintf('\nPV_V2_ELECTRICAL_DIAGNOSTIC_COMPLETE=1\n');
end

function dump(block,names)
for j=1:numel(names)
    try
        raw=get_param(block,names{j});
        fprintf('%s=%s\n',names{j},char(string(raw)));
    catch
    end
end
end
