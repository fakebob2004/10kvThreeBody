function T=define_wind_test_fixture(assignToBase)
%DEFINE_WIND_TEST_FIXTURE Strong-machine tuning used only for Wind GFL tests.
if nargin<1,assignToBase=true;end
T=define_strong_machine_fixture(false);
T.SM.inertia=10.0;T.SM.damping=0.20;T.SM.droop_p=1;
T.SM.governor_time_constant=0.05;T.SM.time_constsnt_steamchest=0.10;
if assignToBase
    assignin('base','Grid',T.Grid);assignin('base','GridTransformer',T.GridTransformer);
    assignin('base','SM',T.SM);assignin('base','SimulationTime',T.SimulationTime);
    assignin('base','Ts',T.Ts);
end
end
