function run_voc_attribution_replay(smokeOnly)
%RUN_VOC_ATTRIBUTION_REPLAY Independent MATLAB implementation and handoff.
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'scripts'));
out=fullfile(root,'artifacts','voc_attribution');
ids={'fresh_202610174_0021','fresh_202610174_0004','rep_02'};
if nargin>0 && smokeOnly
    build_harness(root,out,ids{1});
    fprintf('VOC_SIMULINK_SMOKE_PASS=1\n');return
end
rows=cell(1,numel(ids));dt=6.25e-6;
for k=1:numel(ids)
    cid=ids{k};c=load(fullfile(out,[cid '.mat']));c.x0=c.x0(:);
    rhsError=0;
    for j=1:3
        dx=voc_n2_rhs(c.oracle_times(j),c.oracle_states(j,:)',c);
        rhsError=max(rhsError,max(abs(dx-c.oracle_rhs(j,:)')));
    end
    assert(rhsError<1e-8,'MATLAB/Python RHS mismatch');
    % Complete native prefix; keep all states continuous at switching events.
    stop=c.clear+.05; count=round(stop/dt); x=c.x0;
    stride=16; data=zeros(count+1,30); n=0;
    fullData=zeros(count+1,30);
    peak=-inf;peakRow=zeros(1,30);clearError=nan;
    for j=0:count
        t=j*dt;[~,y]=voc_n2_rhs(t,x,c);row=[t x' y'];
        fullData(j+1,:)=row;
        if mod(j,stride)==0 || j==count || abs(t-c.clear)<.005
            n=n+1;data(n,:)=row;
        end
        if abs(t-c.clear)<dt/4
            clearError=max(abs(x-c.oracle_states(3,:)'));
        end
        if t>=c.clear && max(y(1:2))>peak
            peak=max(y(1:2));peakRow=row;
        end
        if j<count
            % Hold event topology for all RK4 substages, matching source.
            a=voc_n2_rhs(t,x,c);b=voc_n2_rhs(t,x+dt*a/2,c);
            cc=voc_n2_rhs(t,x+dt*b/2,c);d=voc_n2_rhs(t,x+dt*cc,c);
            x=x+dt*(a+2*b+2*cc+d)/6;
        end
    end
    data=sortrows(unique([data(1:n,:);peakRow],'rows'),1);
    assert(all(isfinite(data),'all'));
    names={'time_s','hat_d_pu','hat_q_pu','i1_d_pu','i1_q_pu', ...
        'v0_d_pu','v0_q_pu','v1_d_pu','v1_q_pu', ...
        'line0_d_pu','line0_q_pu','line1_d_pu','line1_q_pu', ...
        'line2_d_pu','line2_q_pu','mu_filter','sg_angle_rad','sg_speed_pu', ...
        'V0_pu','V1_pu','Ibridge_pu','Eosc_pu','Ebridge_pu','current_ref_factor', ...
        'modulation_factor','Pterminal_pu','Qterminal_pu','Pbridge_pu','fosc_Hz','fsg_Hz'};
    writetable(array2table(data,'VariableNames',names),fullfile(out,[cid '_waveforms.csv']));
    save(fullfile(out,[cid '_fullrate.mat']),'fullData','names','dt','-v7');
    tp=c.oracle_post_time(:)+c.clear; oracle=c.oracle_post_electrical;
    % Compare only shared saved instants; don't interpolate across sharp peaks.
    [ok,idx]=ismember(round(tp/dt),round(data(:,1)/dt));
    err=max(abs(data(idx(ok),4:15)-oracle(ok,:)),[],'all');
    oraclePeak=max(vecnorm(reshape(oracle(:,3:6)',2,[]),2,1));
    rows{k}=struct('case_id',cid,'dt_s',dt,'rhs_max_error',rhsError, ...
        'clearing_state_max_error',clearError,'shared_sample_max_error',err, ...
        'Vpeak_pu',peak,'python_Vpeak_pu',oraclePeak, ...
        'peak_after_clear_ms',(peakRow(1)-c.clear)*1000);
    assert(clearError<1e-7 && err<1e-6 && abs(peak-oraclePeak)<1e-6, ...
        'Frozen Python/MATLAB replay parity failed');
    fig=figure('Visible','off','Position',[50 50 1250 850]);
    tiledlayout(3,2,'TileSpacing','compact');
    nexttile;plot(data(:,1),data(:,19:20));xline(c.entry);xline(c.clear);ylabel('Node voltage (dq magnitude pu)');legend('v0','v1');grid on;
    nexttile;plot(1e3*(data(:,1)-c.clear),data(:,19:20));xlim([-.5 5]);ylabel('Node voltage (pu)');xlabel('After clearing (ms)');grid on;
    nexttile;plot(data(:,1),data(:,21:23));legend('bridge current','oscillator voltage','bridge voltage');ylabel('pu magnitude');grid on;
    nexttile;plot(data(:,1),data(:,24:25));legend('current reference factor','bridge voltage factor');ylim([0 1.05]);grid on;
    nexttile;plot(data(:,1),data(:,26:28));legend('P terminal','Q terminal','P bridge');ylabel('pu');xlabel('Time (s)');grid on;
    nexttile;plot(data(:,1),data(:,29:30));legend('oscillator','SG');ylabel('Hz');xlabel('Time (s)');grid on;
    sgtitle(strrep([cid ' | frozen N2 limited dVOC | MATLAB independent replay'],'_','\_'));
    exportgraphics(fig,fullfile(out,[cid '_waveforms.png']),'Resolution',150);close(fig);
    fprintf('%s Vpeak=%.9f RHSerr=%.3g stateError=%.3g\n',cid,peak,rhsError,err);
end
writetable(struct2table([rows{:}]),fullfile(out,'matlab_parity_summary.csv'));
build_harness(root,out,ids{1});
fprintf('VOC_ATTRIBUTION_MATLAB_PARITY_PASS=1\n');
end

function build_harness(root,out,cid)
c=load(fullfile(out,[cid '.mat']));assignin('base','VOC_N2_CASE',c);
m='voc_n2_attribution';if bdIsLoaded(m),close_system(m,0);end;new_system(m);
add_block('simulink/Sources/Clock',[m '/Time'],'Position',[40 40 70 70]);
add_block('simulink/Signal Routing/Mux',[m '/Time and State'],'Position',[120 40 125 160],'Inputs','2');
f=[m '/Frozen dVOC and N2 Dynamics'];
add_block('simulink/User-Defined Functions/MATLAB Function',f, ...
    'Position',[200 65 450 145]);
sf=sfroot;chart=sf.find('-isa','Stateflow.EMChart','Path',f);
chart.Script=sprintf(['function dx = dynamics(u)\n' ...
    '%% Research simulation adapter; not a code-generation interface.\n' ...
    'coder.extrinsic(''voc_n2_simulink_rhs'');\n' ...
    'dx=zeros(17,1);\ndx=voc_n2_simulink_rhs(u);\nend\n']);
add_block('simulink/Continuous/Integrator',[m '/Continuous Physical and Controller States'], ...
    'Position',[540 70 650 140],'InitialCondition','VOC_N2_CASE.x0(:)');
add_block('simulink/Sinks/To Workspace',[m '/State Waveforms'],'Position',[730 75 860 125], ...
    'VariableName','voc_n2_states','SaveFormat','Timeseries');
add_line(m,'Time/1','Time and State/1');add_line(m,'Continuous Physical and Controller States/1','Time and State/2','autorouting','on');
add_line(m,'Time and State/1','Frozen dVOC and N2 Dynamics/1');
add_line(m,'Frozen dVOC and N2 Dynamics/1','Continuous Physical and Controller States/1');
add_line(m,'Continuous Physical and Controller States/1','State Waveforms/1');
a=Simulink.Annotation(m,'Independent dq research replay: exact frozen controller + N2 ODE; not BESS Simscape migration.');
a.Position=[40 220 900 250];
set_param(m,'Solver','ode4','SolverType','Fixed-step','FixedStep','6.25e-6', ...
    'StopTime','VOC_N2_CASE.clear+0.05', ...
    'InitFcn',sprintf("addpath('%s'); VOC_N2_CASE=load('%s');", ...
    fullfile(root,'scripts'),fullfile(out,[cid '.mat'])));
set_param(m,'SimulationCommand','update');
save_system(m,fullfile(out,[m '.slx']));
% Short executable harness smoke test, then compare with independent RK4.
simout=sim(m,'StopTime','0.002');ts=simout.get('voc_n2_states');
x=c.x0(:);dt=6.25e-6;
for j=0:319
    t=j*dt;a=voc_n2_rhs(t,x,c);b=voc_n2_rhs(t,x+dt*a/2,c);
    cc=voc_n2_rhs(t,x+dt*b/2,c);d=voc_n2_rhs(t,x+dt*cc,c);
    x=x+dt*(a+2*b+2*cc+d)/6;
end
lastSample=getdatasamples(ts,numel(ts.Time));
smokeError=max(abs(lastSample(:)-x));
assert(smokeError<1e-7,'Simulink smoke parity failed');
writetable(table(.002,dt,smokeError,'VariableNames', ...
    {'stop_time_s','dt_s','state_max_error'}),fullfile(out,'simulink_smoke_summary.csv'));
close_system(m,0);
end
