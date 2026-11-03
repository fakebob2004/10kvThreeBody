function p3_var_case(m,mode)
scrtag=regexp(mode,'_scr(\d+)$','tokens','once');mode=regexprep(mode,'_scr\d+$','');feed=endsWith(mode,'_feeders');mode=erase(mode,'_feeders');assert(ismember(mode,{'var_local','var_coordinated'}));on=strcmp(mode,'var_coordinated');
if feed
 % Series-only feeder equivalents from project design R2. Insert on private
 % two-port links; never delete a shared PCC trunk.
 own={'02 GFM PCS and Step-up','PV Resource','Wind Resource'};km=[.2 1 1];
 for j=1:3
  sys=[m '/' own{j}];p=get_param([sys '/PCC_10kV'],'PortHandles');term=[p.LConn(:);p.RConn(:)];assert(isscalar(term));ln=get_param(term,'Line');
  endpoints=[get_param(ln,'SrcPortHandle');reshape(get_param(ln,'DstPortHandle'),[],1)];other=endpoints(endpoints~=term & endpoints>0);assert(isscalar(other) && any(endpoints==term),'Expected a private two-port electrical link');delete_line(ln);
  z=[sys '/10 kV feeder equivalent'];add_block('ee_lib/Passive/RLC Assemblies/RLC (Three-Phase)',z,'component_structure','ee.enum.rlc.structure.SeriesRL','R',num2str(.125*km(j)),'L',num2str(.00030*km(j)));
  add_line(sys,other,v2_port(z,'LConn',1),'autorouting','on');add_line(sys,v2_port(z,'RConn',1),term,'autorouting','on');
 end
end
% Identical plant/AVR/virtual inertia in A and B. Only dispatch gain differs.
h=find_system(m,'Name','Inverse inertia');assert(numel(h)==1);set_param(h{1},'Gain','1/(2*8)');
g=[m '/Synchronous Machine PCC'];av=[m '/Strong Synchronous Machine - Always Connected'];
if ~isempty(scrtag)
 % Positive-sequence prospective SCR: 10 kV LL, 15 MW aggregate rated export,
 % source impedance only; no converter fault-current contribution or feeder Z.
 sm=[av '/Synchronous Machine'];assert(strcmp(get_param(sm,'param_unit'),'ee.enum.unit.si'));
 rr=str2double(get_param(sm,'R_si'));ll=str2double(get_param(sm,'L_si'));z0=hypot(rr,2*pi*50*ll);
 scr=str2double(scrtag{1});ratio=1e8/(15e6*scr*z0)-1;assert(ratio>0);
 mach=v2_port(av,'LConn',1);bus=v2_port(g,'LConn',1);old=get_param(mach,'Line');assert(old==get_param(bus,'Line'));delete_line(old);
 uz=[m '/Upstream Thevenin increment'];add_block('ee_lib/Passive/RLC Assemblies/RLC (Three-Phase)',uz,'component_structure','ee.enum.rlc.structure.SeriesRL','R',num2str(rr*ratio,16),'L',num2str(ll*ratio,16));add_line(m,mach,v2_port(uz,'LConn',1),'autorouting','on');add_line(m,v2_port(uz,'RConn',1),bus,'autorouting','on');
end
add_block('simulink/Signal Routing/Bus Selector',[m '/Grid measurements'],'OutputSignals','Vll_rms_V,Q_var');wire(m,'Synchronous Machine PCC/1','Grid measurements/1');
add_block('simulink/Math Operations/Bias',[m '/Voltage deviation'],'Bias','-10000');wire(m,'Grid measurements/1','Voltage deviation/1');
add_block('simulink/Continuous/Transfer Fcn',[m '/AVR incremental field'],'Numerator','-0.8','Denominator','[0.05 1]');wire(m,'Voltage deviation/1','AVR incremental field/1');
add_block('simulink/Discontinuities/Saturation',[m '/Field trim limit'],'UpperLimit','800','LowerLimit','-800');wire(m,'AVR incremental field/1','Field trim limit/1');
add_block('simulink/Sources/In1',[av '/Field trim']);wire(m,'Field trim limit/1','Strong Synchronous Machine - Always Connected/1');delete_line(av,'Excitation/1','Excitation PS/1');add_block('simulink/Math Operations/Sum',[av '/Field voltage'],'Inputs','++');wire(av,'Excitation/1','Field voltage/1');wire(av,'Field trim/1','Field voltage/2');wire(av,'Field voltage/1','Excitation PS/1');
% Switch on a physical three-phase inductive load at the common bus.
br=[m '/VAR load breaker'];add_block([m '/BESS intertie breaker'],br);z=[m '/1 Mvar bank'];add_block('ee_lib/Passive/RLC Assemblies/RLC (Three-Phase)',z,'component_structure','ee.enum.rlc.structure.L','L','10000^2/(2*pi*50*1e6)');ng=[m '/Bank neutral'];add_block(sprintf('ee_lib/Connectors &\nReferences/Grounded Neutral\n(Three-Phase)'),ng);
conn(m,g,'RConn',1,br,'LConn',2);conn(m,br,'RConn',1,z,'LConn',1);conn(m,z,'RConn',1,ng,'LConn',1);
add_block('simulink/Sources/Step',[m '/Apply VAR load'],'Time','2.65','Before','1','After','0');ps=[m '/Bank control PS'];add_block([m '/Intertie command PS'],ps);wire(m,'Apply VAR load/1','Bank control PS/1');conn(m,ps,'RConn',1,br,'LConn',1);
% Distribute positive measured grid Q, smoothly and below residual PCS capability
% for the test envelope Pwind <= 2 MW, |Pbess| <= 1 MW, 6.25 MVA each.
add_block('simulink/Continuous/Transfer Fcn',[m '/Grid Q filter'],'Numerator','1','Denominator','[.05 1]');wire(m,'Grid measurements/2','Grid Q filter/1');
for k=1:2
 n={'BESS VAR order','Wind VAR order'};n=n{k};add_block('simulink/Math Operations/Gain',[m '/' n],'Gain',num2str(on*[.9 .6]*[k==1;k==2]));wire(m,'Grid Q filter/1',[n '/1']);lim=[n ' limit'];add_block('simulink/Discontinuities/Saturation',[m '/' lim],'UpperLimit','1.25e6','LowerLimit','-1.25e6');wire(m,[n '/1'],[lim '/1']);
 if k==1,delete_line(m,'BESS Q request/1','BESS Synchronism and Dispatch/4');wire(m,[lim '/1'],'BESS Synchronism and Dispatch/4');
 else,w=[m '/Wind Command'];add_block('simulink/Sources/In1',[w '/Reactive dispatch']);delete_line(w,'Q Reference/1','Command/2');wire(w,'Reactive dispatch/1','Command/2');ph=get_param([w '/Command'],'PortHandles');set_param(get_param(ph.Inport(2),'Line'),'Name','Q_ref_var');wire(m,[lim '/1'],'Wind Command/1');end
end
end
function wire(m,a,b),add_line(m,a,b,'autorouting','on');end
function conn(m,a,ap,ai,b,bp,bi),add_line(m,v2_port(a,ap,ai),v2_port(b,bp,bi),'autorouting','on');end
