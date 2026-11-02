function varargout=pv_dyn_helpers(action,varargin)
%PV_DYN_HELPERS Small standard-library primitives for the physical PV builder.
switch action
case 'sub'
 p=varargin{1}; n=varargin{2}; pos=varargin{3}; s=[p '/' n];
 add_block('built-in/Subsystem',s,'Position',pos,'ContentPreviewEnabled','off'); varargout={s};
case 'block'
 s=varargin{1}; n=varargin{2}; lib=varargin{3}; pos=varargin{4};
 args=varargin(5:end);
 if strcmp(lib,'simulink/User-Defined Functions/Fcn')
  % R2024b Fcn syntax accepts scalar symbols but not dotted structures.
  % Resolve only configuration fields; all numerical sources remain in V2.PV.
  ix=find(strcmp(args,'Expr'),1);
  if ~isempty(ix)
   e=args{ix+1};tokens=unique(regexp(e,'V2\.PV\.[A-Za-z0-9_\.]+','match'));
   for j=1:numel(tokens),e=strrep(e,tokens{j},sprintf('(%.17g)',evalin('base',tokens{j})));end
   args{ix+1}=lower_minmax(e);
  end
 end
 add_block(lib,[s '/' n],'Position',pos,args{:});
case 'line'
 s=varargin{1}; add_line(s,varargin{2},varargin{3},'autorouting','on');
case 'wire'
 s=varargin{1}; a=varargin{2}; aside=varargin{3}; ai=varargin{4};
 b=varargin{5}; bside=varargin{6}; bi=varargin{7};
 ap=[s '/' a];bp=[s '/' b];
 if strcmp(get_param(ap,'BlockType'),'PMIOPort'),ah=v2_physical_port(ap);else,ah=v2_port(ap,aside,ai);end
 if strcmp(get_param(bp,'BlockType'),'PMIOPort'),bh=v2_physical_port(bp);else,bh=v2_port(bp,bside,bi);end
 add_line(s,ah,bh,'autorouting','on');
case 'sps'
 s=varargin{1}; n=varargin{2}; unit=varargin{3}; pos=varargin{4};
 add_block(sprintf('nesl_utility/Simulink-PS\nConverter'),[s '/' n], ...
 'Position',pos,'Unit',unit,'FilteringAndDerivatives','zero');
case 'pss'
 s=varargin{1}; n=varargin{2}; unit=varargin{3}; pos=varargin{4};
 add_block(sprintf('nesl_utility/PS-Simulink\nConverter'),[s '/' n],'Position',pos,'Unit',unit);
case 'port'
 s=varargin{1}; n=varargin{2}; no=varargin{3}; dir=varargin{4}; pos=varargin{5};
 add_block(['simulink/Ports & Subsystems/' dir '1'],[s '/' n],'Port',num2str(no),'Position',pos);
case 'pi'
 s=varargin{1}; n=varargin{2}; kp=varargin{3}; ki=varargin{4}; kaw=varargin{5};
 lo=varargin{6}; hi=varargin{7}; pos=varargin{8}; ic=varargin{9};
 q=pv_dyn_helpers('sub',s,n,pos);
 B=@(name,lib,p,varargin)pv_dyn_helpers('block',q,name,lib,p,varargin{:});
 L=@(a,b)pv_dyn_helpers('line',q,a,b);
 pv_dyn_helpers('port',q,'error',1,'In',[15 40 45 54]);
 B('Kp','simulink/Math Operations/Gain',[75 20 130 50],'Gain',kp);
 B('Ki','simulink/Math Operations/Gain',[75 90 130 120],'Gain',ki);
 B('Integrator','simulink/Continuous/Integrator',[260 100 295 135],'InitialCondition',ic);
 B('Integral Derivative','simulink/Math Operations/Sum',[220 95 245 140],'Inputs','++');
 B('Unsaturated','simulink/Math Operations/Sum',[340 25 365 75],'Inputs','++');
 B('Limit','simulink/Discontinuities/Saturation',[410 30 475 70],'LowerLimit',lo,'UpperLimit',hi);
 B('Tracking Error','simulink/Math Operations/Sum',[410 130 440 175],'Inputs','+-');
 B('Kaw','simulink/Math Operations/Gain',[330 155 385 185],'Gain',kaw);
 pv_dyn_helpers('port',q,'output',1,'Out',[525 40 555 54]);
 L('error/1','Kp/1');L('error/1','Ki/1');L('Ki/1','Integral Derivative/1');
 L('Kaw/1','Integral Derivative/2');L('Integral Derivative/1','Integrator/1');
 L('Integrator/1','Unsaturated/2');L('Kp/1','Unsaturated/1');
 L('Unsaturated/1','Limit/1');L('Limit/1','output/1');
 L('Limit/1','Tracking Error/1');L('Unsaturated/1','Tracking Error/2');L('Tracking Error/1','Kaw/1');
 varargout={q};
otherwise,error('Unknown helper action: %s',action);
end
end

function e=lower_minmax(e)
% Fcn's R2024b expression grammar has no two-argument min/max.
while true
 [a,b]=regexp(e,'(min|max)\(','start','end');
 if isempty(a),break;end
 start=a(end);open=b(end);level=1;comma=0;stop=open;
 for k=open+1:numel(e)
  if e(k)=='(',level=level+1;elseif e(k)==')',level=level-1; ...
  elseif e(k)==','&&level==1,comma=k;end
  if level==0,stop=k;break;end
 end
 assert(comma>0,'Expected binary min/max expression');
 x=e(open+1:comma-1);y=e(comma+1:stop-1);sgn='+';
 if strcmp(e(start:start+2),'min'),sgn='-';end
 replacement=['(0.5*((' x ')+(' y ')' sgn 'abs((' x ')-(' y '))))'];
 e=[e(1:start-1) replacement e(stop+1:end)];
end
end
