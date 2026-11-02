function C=init_grid_supported_integration()
%INIT_GRID_SUPPORTED_INTEGRATION Independent PV parameters and Wind R3 namespace.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_v2_paths;
run(fullfile(root,'parameters','init_wind_pmsg_transient_r3.m'));
% Same local PLL alignment already commissioned by the average Wind R2 path.
Control.PLL.ControlAngleBias=-pi+atan(Base.f/Control.PLL.VoltagePrefilterHz);
assignin('base','Control',Control);
define_resource_buses(true);C=define_v2_parameters(false);
C.PV.dynamic.enabled=true;C.PV.filter.topology='LCL';
assignin('base','V2',C);
fprintf('GRID-SUPPORTED ADAPTER: Wind GSC averaged, local PLL active, synchronous machine always connected, no islanding.\n');
end
