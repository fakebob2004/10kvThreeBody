function result=diagnose_wind_start_targets()
% Compare the raw first sample for one change at a time on the same grid.
root=setup_v2_paths;model='GRID_SUPPORTED_PV_WIND_R1';
assert(~bdIsLoaded(model),'Close the joint model before running this comparison.');
load_system(fullfile(root,'models','integration',[model '.slx']));
cleanup=onCleanup(@()close_system(model,0));
w=[model '/Wind Resource'];cap=[w '/03 DC Link and Two-Level GSC/DC-Link Capacitor'];
xfmr=[w '/05 Filter Transformer and PCC/0.69 kV to 10 kV Step-Up Transformer'];
f=[w '/05 Filter Transformer and PCC/AC Filter Rf + Lf'];
base=Simulink.SimulationInput(model);base=base.setModelParameter('StopTime','0.003');
vc=base.setBlockParameter(cap,'v_specify','off');
vc=vc.setBlockParameter(cap,'vc_specify','on');
vc=vc.setBlockParameter(cap,'vc','Converter.Vdc_nom');
free=vc.setBlockParameter(f,'IL_specify','off');
withLeak=@(i)i.setBlockParameter(xfmr,'leakage_reactance_option','ee.enum.transformer_leakage.include');
cases={base,vc,withLeak(vc),free,withLeak(free)};
result=zeros(numel(cases),3);
for k=1:numel(cases)
 out=sim(cases{k});
 result(k,:)=[out.integration_wind.Data(1,9),out.integration_pv.Data(1,9),max(out.integration_sm.Data(:,3))];
end
result=array2table(result,'VariableNames',{'WindInitialVdc','PVInitialVdc','BusPeakV'}, ...
 'RowNames',{'Baseline','CapState','CapStateLeakage','CapStateFreeFilter','CapStateFreeFilterLeakage'});
disp(result);
end
