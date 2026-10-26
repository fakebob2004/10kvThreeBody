%INIT_WIND_DFIG_REUSED_R2 Reused-plant DFIG average model parameters.
root=fileparts(fileparts(mfilename('fullpath')));
run(fullfile(root,'parameters','init_wind_course_average.m'));
run(fullfile(root,'parameters','init_wind_dfig_average_r1.m'));

% Reuse the accepted 6.25 MVA / 690 V / 10 kV physical grid-side plant.
% The wound-rotor machine remains 5 MW and its rotor converter handles slip
% power only.  R2 starts from the same 9 m/s optimum as the direct-drive seed.
DFIG.Wind.v0=Wind.wind_initial_mps;
DFIG.Wind.vStep=Wind.wind_step_mps;
DFIG.Wind.stepTime=0.35;
DFIG.Interface.StatorInjectionGain=-1;
DFIG.Interface.CurrentSourceParasiticConductance=1e-8;
DFIG.Interface.Angle0=0;
DFIG.Simulation.StopTime=0.60;
Base.Simulation.StopTime=DFIG.Simulation.StopTime;
Base.Simulation.MaxStep=2e-5;

assignin('base','Base',Base);assignin('base','Converter',Converter);
assignin('base','Filter',Filter);assignin('base','Transformer',Transformer);
assignin('base','Grid',Grid);assignin('base','Control',Control);
assignin('base','Wind',Wind);assignin('base','DFIG',DFIG);
fprintf(['DFIG reused R2 parameters: accepted physical DC/GSC/filter/transformer/' ...
    'PCC/grid retained; new wound-rotor DFIG and average RSC.\n']);
