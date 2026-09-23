function R = validate_r2024b_resource_exports()
%VALIDATE_R2024B_RESOURCE_EXPORTS Compile and smoke-test exported models.
% This runs in the installed MATLAB release. A final native-R2024b run is
% still required because Simscape Electrical reports a partial conversion.

root = fileparts(fileparts(mfilename('fullpath')));
setup_v2_paths;
define_resource_buses(true);
define_v2_parameters(true);
define_strong_machine_fixture(true);

spec = {
    'pv_resource_standalone',   'PV Command',   'pv_v2_result';
    'wind_resource_standalone', 'Wind Command', 'wind_v2_result'};
R = struct();
for k = 1:size(spec,1)
    model = spec{k,1}; command = spec{k,2}; resultName = spec{k,3};
    file = fullfile(root,'models','r2024b',[model '.slx']);
    assert(isfile(file),'Missing R2024b export: %s',file);
    if bdIsLoaded(model), close_system(model,0); end
    load_system(file);

    % Explicit compile/update check before the dynamic smoke test.
    set_param(model,'SimulationCommand','update');
    set_param([model '/' command '/P Base'],'Value','2e6');
    set_param([model '/' command '/P Increment'],'Time','10','After','0');
    set_param([model '/' command '/Q Base'],'Value','0');
    set_param([model '/' command '/Q Increment'],'Time','10','After','0');
    set_param(model,'StopTime','0.25');
    out = sim(model);
    x = out.get(resultName);
    assert(~isempty(x) && size(x,2)>=5,'%s produced no status record.',model);
    assert(all(isfinite(x),'all'),'%s produced non-finite status.',model);
    tail = x(:,1)>0.20;
    assert(any(tail),'%s smoke test has no tail samples.',model);
    p = mean(x(tail,2)); q = mean(x(tail,3));
    v = mean(x(tail,4)); f = mean(x(tail,5));
    assert(abs(p-2e6)<0.25e6,'%s active-power smoke check failed.',model);
    assert(abs(q)<0.20e6,'%s reactive-power smoke check failed.',model);
    assert(v>8.5e3 && v<11e3,'%s PCC-voltage smoke check failed.',model);
    assert(f>48 && f<51,'%s frequency smoke check failed.',model);
    R.(model) = struct('P_W',p,'Q_var',q,'Vpcc_V',v,'frequency_Hz',f);
    fprintf('R2024B_SMOKE_OK=%s P=%.4fMW Q=%.4fMvar V=%.3fkV f=%.3fHz\n', ...
        model,p/1e6,q/1e6,v/1e3,f);
    close_system(model,0);
end
fprintf('R2024B_RESOURCE_SMOKE_PASS=1\n');
end
