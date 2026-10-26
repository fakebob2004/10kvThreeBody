%INIT_WIND_COURSE_AVERAGE Parameters for the direct-drive average-GSC model.
root=fileparts(fileparts(mfilename('fullpath')));
run(fullfile(root,'parameters','init_wind_course_spwm_r2.m'));

% The electrical switching carrier is removed, so the system-level model can
% use a control/dynamic time step while retaining the same physical ratings.
Base.Simulation.StopTime=0.60;
Base.Simulation.MaxStep=2e-5;
Control.ActiveAngleSource='local SRF-PLL';
% The inherited PLL locks Vq=0 on the negative d axis after a first-order
% voltage prefilter.  Rotate to positive d and compensate the known 50 Hz
% prefilter lag before using the angle in the unfiltered current controller.
Control.PLL.ControlAngleBias=-pi+atan(Base.f/Control.PLL.VoltagePrefilterHz);
Converter.ModelType='Converter (Three-Phase), averaged-switch bridge';

assignin('base','Base',Base);assignin('base','Converter',Converter);
assignin('base','Control',Control);
fprintf(['Wind course average parameters: 5 MW turbine, 6.25 MVA PCS, ' ...
    '1500 Vdc, 690 V/10 kV, local PLL active\n']);
