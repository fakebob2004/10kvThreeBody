function path=add_gfl_current_controller(parent,name,cfg,pos)
%ADD_GFL_CURRENT_CONTROLLER Finite-bandwidth dq tracking and dq-to-abc synthesis.
path=[parent '/' name];add_block('built-in/Subsystem',path,'Position',pos, ...
    'BackgroundColor','[0.92,0.90,1.00]','ContentPreviewEnabled','off');
ins={'Id_ref_Apk','Iq_ref_Apk','theta_rad'};
for k=1:3,add_block('simulink/Ports & Subsystems/In1',[path '/' ins{k}], ...
        'Port',num2str(k),'Position',[20 45+70*(k-1) 50 59+70*(k-1)]);end
den=['[1/(2*pi*' cfg '.control.current_bandwidth_Hz) 1]'];
add_block('simulink/Continuous/Transfer Fcn',[path '/Id Tracking'], ...
    'Position',[100 35 215 75],'Numerator','1','Denominator',den);
add_block('simulink/Continuous/Transfer Fcn',[path '/Iq Tracking'], ...
    'Position',[100 110 215 150],'Numerator','1','Denominator',den);
add_block('simulink/User-Defined Functions/Fcn',[path '/Line-to-Phase Angle'], ...
    'Position',[95 190 225 225],'Expr','u-pi/6');
add_block('simulink/Signal Routing/Mux',[path '/dq theta'], ...
    'Position',[275 40 280 225],'Inputs','3');
phase={'','-2*pi/3','+2*pi/3'};names={'ia','ib','ic'};
for k=1:3
    expr=sprintf('u(1)*sin(u(3)%s)+u(2)*cos(u(3)%s)',phase{k},phase{k});
    add_block('simulink/User-Defined Functions/Fcn',[path '/' names{k}], ...
        'Position',[330 40+65*(k-1) 510 70+65*(k-1)],'Expr',expr);
end
add_block('simulink/Signal Routing/Mux',[path '/iabc Command'], ...
    'Position',[555 35 560 225],'Inputs','3');
add_block('simulink/Ports & Subsystems/Out1',[path '/iabc_A'], ...
    'Port','1','Position',[620 100 650 114]);
add_line(path,'Id_ref_Apk/1','Id Tracking/1');add_line(path,'Iq_ref_Apk/1','Iq Tracking/1');
add_line(path,'theta_rad/1','Line-to-Phase Angle/1');
add_line(path,'Id Tracking/1','dq theta/1');add_line(path,'Iq Tracking/1','dq theta/2');
add_line(path,'Line-to-Phase Angle/1','dq theta/3');
for k=1:3,add_line(path,'dq theta/1',[names{k} '/1']);add_line(path,[names{k} '/1'],sprintf('iabc Command/%d',k));end
add_line(path,'iabc Command/1','iabc_A/1');
end
