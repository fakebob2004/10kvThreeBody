function s=add_pv_dynamic_current_control(parent,name,cfg,pos)
%ADD_PV_DYNAMIC_CURRENT_CONTROL Vdc outer PI, dq current PI and vector tracking.
s=pv_dyn_helpers('sub',parent,name,pos);d=[cfg '.dynamic'];
B=@(n,l,p,varargin)pv_dyn_helpers('block',s,n,l,p,varargin{:});
L=@(a,b)pv_dyn_helpers('line',s,a,b);
ports={'vabc','iabc','theta','Vdc','Ppv','Command'};
for k=1:6,pv_dyn_helpers('port',s,ports{k},k,'In',[15 30+50*k 45 44+50*k]);end
B('Measured abc and Angle','simulink/Signal Routing/Mux',[90 70 95 220],'Inputs','3');
L('vabc/1','Measured abc and Angle/1');L('iabc/1','Measured abc and Angle/2');L('theta/1','Measured abc and Angle/3');
park={'(2/3)*(u(1)*sin(u(7))+u(2)*sin(u(7)-2*pi/3)+u(3)*sin(u(7)+2*pi/3))', ...
 '(2/3)*(u(1)*cos(u(7))+u(2)*cos(u(7)-2*pi/3)+u(3)*cos(u(7)+2*pi/3))', ...
 '(2/3)*(u(4)*sin(u(7))+u(5)*sin(u(7)-2*pi/3)+u(6)*sin(u(7)+2*pi/3))', ...
 '(2/3)*(u(4)*cos(u(7))+u(5)*cos(u(7)-2*pi/3)+u(6)*cos(u(7)+2*pi/3))'};
pn={'Vd','Vq','Id','Iq'};
for k=1:4
 B(pn{k},'simulink/User-Defined Functions/Fcn',[145 35+55*k 400 70+55*k],'Expr',park{k});
 L('Measured abc and Angle/1',[pn{k} '/1']);
end
B('Command Selector','simulink/Signal Routing/Bus Selector',[80 360 85 450],'OutputSignals','Q_ref_var,enable');
L('Command/1','Command Selector/1');
B('Enable Ramp','simulink/Continuous/Transfer Fcn',[140 400 290 435], ...
 'Numerator','1','Denominator',['[' d '.enable_ramp_s 1]']);L('Command Selector/2','Enable Ramp/1');
B('DC Error','simulink/Math Operations/Sum',[330 360 360 410],'Inputs','+-');
B('DC Reference','simulink/Sources/Constant',[140 325 290 355],'Value',[d '.Vdc_ref_V']);
L('Vdc/1','DC Error/1');L('DC Reference/1','DC Error/2');
pv_dyn_helpers('pi',s,'DC Voltage PI',[d '.dc_Kp_ApV'],[d '.dc_Ki_ApVs'],[d '.dc_Kaw'], ...
 ['-' cfg '.control.Ilimit_peak_A'],[cfg '.control.Ilimit_peak_A'],[410 350 600 420],'0');
L('DC Error/1','DC Voltage PI/1');
B('Reference Inputs','simulink/Signal Routing/Mux',[650 80 655 410],'Inputs','6');
refs={'Vd/1','Ppv/1','Command Selector/1','Enable Ramp/1','Command Selector/2','DC Voltage PI/1'};
for k=1:6,L(refs{k},sprintf('Reference Inputs/%d',k));end
% Ramp feedforward to avoid exporting initial capacitor energy on enabling.
B('Id Unconstrained','simulink/User-Defined Functions/Fcn',[700 80 970 115], ...
 'Expr',['(u(2)/(1.5*max(abs(u(1)),200))*u(4)+u(6))*u(5)']);
B('Iq Unconstrained','simulink/User-Defined Functions/Fcn',[700 135 970 170], ...
 'Expr',['-(u(3)-2*pi*' cfg '.rating.f_Hz*' cfg '.filter.C_F*' ...
 cfg '.rating.V_ac_low_V^2)/(1.5*max(abs(u(1)),200))*u(4)*u(5)']);
L('Reference Inputs/1','Id Unconstrained/1');L('Reference Inputs/1','Iq Unconstrained/1');
B('Reference Pair','simulink/Signal Routing/Mux',[1010 75 1015 175],'Inputs','2');
L('Id Unconstrained/1','Reference Pair/1');L('Iq Unconstrained/1','Reference Pair/2');
B('Current Limit Factor','simulink/User-Defined Functions/Fcn',[1060 275 1320 310], ...
 'Expr',['min(1,' cfg '.control.Ilimit_peak_A/max(sqrt(u(1)^2+u(2)^2),1))']);
L('Reference Pair/1','Current Limit Factor/1');
for k=1:2
 n=['I' char('c'+k) ' Limited']; % Id / Ie replaced below by explicit names
 if k==1,n='Id Limited';else,n='Iq Limited';end
 B(n,'simulink/User-Defined Functions/Fcn',[1060 65+65*k 1320 100+65*k], ...
 'Expr',sprintf('u(%d)*min(1,%s.control.Ilimit_peak_A/max(sqrt(u(1)^2+u(2)^2),1))',k,cfg));
 L('Reference Pair/1',[n '/1']);
end
B('Id Error','simulink/Math Operations/Sum',[1380 100 1410 145],'Inputs','+-');
B('Iq Error','simulink/Math Operations/Sum',[1380 180 1410 225],'Inputs','+-');
L('Id Limited/1','Id Error/1');L('Id/1','Id Error/2');L('Iq Limited/1','Iq Error/1');L('Iq/1','Iq Error/2');
B('dq Integral','simulink/Continuous/Integrator',[1700 410 1740 450],'InitialCondition','[0;0]');
B('Controller Vector','simulink/Signal Routing/Mux',[1460 50 1465 480],'Inputs','9');
cs={'Vd/1','Vq/1','Id/1','Iq/1','Id Error/1','Iq Error/1','dq Integral/1','Vdc/1','Command Selector/2'};
for k=1:9,L(cs{k},sprintf('Controller Vector/%d',k));end
% Vector order: vd,vq,id,iq,ed,eq,zd,zq,Vdc,enable.
rl=[cfg '.filter.R1_ohm+' cfg '.filter.R2_ohm'];
ll=[cfg '.filter.L1_H+' cfg '.filter.L2_H'];
ed=['u(1)+(' rl ')*u(3)-2*pi*' cfg '.rating.f_Hz*(' ll ')*u(4)+' d '.current_Kp_ohm*u(5)+u(7)'];
eq=['u(2)+(' rl ')*u(4)+2*pi*' cfg '.rating.f_Hz*(' ll ')*u(3)+' d '.current_Kp_ohm*u(6)+u(8)'];
B('Vd Raw','simulink/User-Defined Functions/Fcn',[1510 70 1800 110],'Expr',ed);
B('Vq Raw','simulink/User-Defined Functions/Fcn',[1510 140 1800 180],'Expr',eq);
L('Controller Vector/1','Vd Raw/1');L('Controller Vector/1','Vq Raw/1');
B('Voltage Limit Vector','simulink/Signal Routing/Mux',[1840 65 1845 275],'Inputs','4');
vs={'Vd Raw/1','Vq Raw/1','Vdc/1','Command Selector/2'};
for k=1:4,L(vs{k},sprintf('Voltage Limit Vector/%d',k));end
lim=['min(1,(' d '.modulation_max*max(u(3),1)/2)/max(sqrt(u(1)^2+u(2)^2),1))'];
for k=1:2
 n=['V' char('c'+k) ' Applied'];if k==1,n='Vd Applied';else,n='Vq Applied';end
 B(n,'simulink/User-Defined Functions/Fcn',[1890 60+70*k 2160 100+70*k], ...
 'Expr',sprintf('u(%d)*%s',k,lim));L('Voltage Limit Vector/1',[n '/1']);
end
B('Tracking Vector','simulink/Signal Routing/Mux',[2190 340 2195 550],'Inputs','6');
ts={'Id Error/1','Iq Error/1','Vd Applied/1','Vq Applied/1','Vd Raw/1','Vq Raw/1'};
for k=1:6,L(ts{k},sprintf('Tracking Vector/%d',k));end
for k=1:2
 n=sprintf('Integral Derivative %d',k);
 B(n,'simulink/User-Defined Functions/Fcn',[2240 340+70*k 2520 380+70*k], ...
 'Expr',sprintf('%s.current_Ki_ohmps*u(%d)+%s.current_Kaw*(u(%d)-u(%d))',d,k,d,k+2,k+4));
 L('Tracking Vector/1',[n '/1']);
end
B('Integral Derivatives','simulink/Signal Routing/Mux',[2580 410 2585 510],'Inputs','2');
L('Integral Derivative 1/1','Integral Derivatives/1');L('Integral Derivative 2/1','Integral Derivatives/2');
L('Integral Derivatives/1','dq Integral/1');
B('Inverse Park Inputs','simulink/Signal Routing/Mux',[2210 80 2215 280],'Inputs','4');
is={'Vd Applied/1','Vq Applied/1','theta/1','Vdc/1'};
for k=1:4,L(is{k},sprintf('Inverse Park Inputs/%d',k));end
for k=1:3
 n=sprintf('Modulation %d',k);a=sprintf('u(3)+(%d)*2*pi/3',1-k);
 B(n,'simulink/User-Defined Functions/Fcn',[2260 35+70*k 2570 75+70*k], ...
 'Expr',['2*(u(1)*sin(' a ')+u(2)*cos(' a '))/max(u(4),1)']);
 L('Inverse Park Inputs/1',[n '/1']);
end
B('Modulation abc','simulink/Signal Routing/Mux',[2620 100 2625 290],'Inputs','3');
for k=1:3,L(sprintf('Modulation %d/1',k),sprintf('Modulation abc/%d',k));end
pv_dyn_helpers('port',s,'mabc',1,'Out',[2680 180 2710 194]);L('Modulation abc/1','mabc/1');
B('Control Telemetry','simulink/Signal Routing/Mux',[1380 550 1385 850],'Inputs','9');
tele={'Id Limited/1','Iq Limited/1','Id/1','Iq/1','Vd/1','Vq/1','DC Voltage PI/1','Enable Ramp/1','Current Limit Factor/1'};
for k=1:9,L(tele{k},sprintf('Control Telemetry/%d',k));end
pv_dyn_helpers('port',s,'Telemetry',2,'Out',[1450 700 1480 714]);L('Control Telemetry/1','Telemetry/1');
end
