function test_dvoc_controller_parity()
%TEST_DVOC_CONTROLLER_PARITY Verify reusable controller against frozen RHS.
root=setup_v2_paths();ids={'fresh_202610174_0021','fresh_202610174_0004','rep_02'};
worst=0;A=[1 1 0;-1 -1 1];w=2*pi*50;J=[0 -1;1 0];
for k=1:3
    c=load(fullfile(root,'artifacts','voc_attribution',[ids{k} '.mat']));
    for j=1:3
        t=c.oracle_times(j);x=c.oracle_states(j,:)';v=reshape(x(5:8),2,2);
        il=reshape(x(9:14),2,3);g=c.load_g(:);closed=ones(3,1);
        if t+1e-12>=c.entry&&t+1e-12<c.clear,g=g+c.fault_g(:);end
        if t+1e-12>=c.trip_time,closed=closed-c.trip_mask(:);end
        io=(A*(il.*closed')')'+v.*g';
        [dh,e]=dvoc_limited_controller(x(1:2),x(3:4),v(:,1),io(:,1),c.pref,c.qref,.03,.25);
        reference=c.oracle_rhs(j,:)';
        eReference=(.25/w)*(reference(3:4)+w*J*x(3:4))+v(:,1)+.03*x(3:4);
        worst=max(worst,max(abs([dh-reference(1:2);e-eReference])));
    end
end
assert(worst<1e-9,'Reusable controller differs from frozen Python oracle');
fprintf('DVOC_REUSABLE_CONTROLLER_PARITY_PASS=1 maxError=%.3g\n',worst);
end
