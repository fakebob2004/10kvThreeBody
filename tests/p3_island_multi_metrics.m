function R=p3_island_multi_metrics(o)
% Four sequential disturbances in an already energized island, no model writes.
% Currents into the auxiliary load are positive into the load. Source P/Q are
% positive injections. Signed bank Q from Clarke phasors, not nameplate or gate.
% Engineering screens for this test only; not protection/ride-through ratings.
trip=2.8;edges=[3.7 5.3 6.9 8.5];stop=10.1;
R=struct('pass',false,'complete',false,'course_test_only',true,'utility_trip_s',trip, ...
 'event_time_s',edges,'expected_end_s',stop,'resource_order','BESS, PV, Wind', ...
 'positive_direction','resource export / bank consumption / battery discharge', ...
 'steady_dwell','10 consecutive, non-overlapping 20ms cycles before each following event, plus baseline immediately before first event', ...
 'recovery_definition','first confirmation of 100ms dwell, from event, with 20ms causal means, no exclusion of unfiltered peaks in the separate transient screens', ...
 'frequency_estimator','Clarke alpha-beta PCC phase, 5 and 20ms trailing differences, then 10 and 20ms secant RoCoF, respectively; not local PLL output or relay specification');
R.thresholds=struct('continuous_PCS_fraction',.8,'SOC',[.20 .90],'battery_limit_A',4500,'steady_Vdc_tol_V',75, ...
 'steady_PCC_tol_V',500,'steady_freq_tol_Hz',.5,'PLL_tracking_tol_Hz',.1,'PF_target',.9,'PF_tol',.025, ...
 'transient_V_tol_V',1000,'transient_Vdc_tol_V',150,'resource_peak_current_A',[8875 sqrt(2)*1.1*6.25e6/(sqrt(3)*690) 9963.76811594203], ...
 'balance_tol_MW_Mvar',[.15 .20],'consecutive_cycle_span_MW_Mvar',[.05 .075],'frequency_report_bands_ms',[5 20], ...
 'sag_recovery_dwell_s',.10,'recovery_PQ_tol_MW_Mvar',[.030 .050]);
try
 [tv,v]=arr(o.integration_bus_vabc);[tg,g]=arr(o.integration_sm);[ttie,it]=arr(o.island_utility_current);[trel,rel]=arr(o.utility_release);
 [tl,l]=arr(o.vsm_iL1);[td,pd]=arr(o.pv_dynamic);[tp,p]=arr(o.integration_pv);[tw,w]=arr(o.integration_wind);
 [ti,id]=arr(o.logsout.get('Id_converter').Values);[tiq,iq]=arr(o.logsout.get('Iq_converter').Values);assert(isequal(ti,tiq));
 [tsun,sun]=arr(o.multi_sun);[twind,wind]=arr(o.multi_wind_mps);[tbank,open]=arr(o.multi_bank_open);[tc,cmd]=arr(o.multi_coord_W);[tbk,ibank]=arr(o.multi_bank_amps);
 b=squeeze(o.gfm_r7_result);if size(b,2)~=15,b=b.';end;assert(size(b,2)==15&&size(v,2)==3&&size(ibank,2)==3);tb=b(:,1);
 R.achieved_end_s=min([tv(end),tg(end),tb(end),tp(end),tw(end),ti(end),ttie(end),tbk(end),tl(end),td(end)]);R.complete=R.achieved_end_s>=stop-1e-7;assert(R.complete,'Record does not cover final plateau');
 raw={v,g,it,rel,l,pd,p,w,id,iq,b,sun,wind,open,cmd,ibank};R.finite=all(cellfun(@(x)all(isfinite(x(:))),raw));assert(R.finite,'Nonfinite raw channels');
 ix=ttie>=trip+.02;R.utility_off_peak_A=max(abs(it(ix,:)),[],'all');R.utility_before_peak_A=max(abs(it(ttie>=trip-.16 & ttie<trip-.02,:)),[],'all');
 R.utility_open_verified=all(rel(trel<trip)==0)&&all(rel(trel>=trip+.02)>.5)&&R.utility_off_peak_A<2&&R.utility_before_peak_A>R.utility_off_peak_A+1;
 R.utility_transition_PCC_V=ex(tg,g(:,3),trip,edges(1));R.utility_transition_scope='transfer before the event series, reported independently of the four event transitions';
 [~,ang]=abc(v);
 dt=median(diff(tv));assert(all(abs(diff(tv)-dt)<dt*.01),'PCC voltage logging not uniform; frequency estimator needs resampling');
 fs={};fts={};ros={};rts={};for j=1:2
  nn=round([.005 .02]/dt);n=nn(j);rr=round([.01 .02]/dt);h=rr(j);
  fts{j}=tv(n+1:end);fs{j}=(ang(n+1:end)-ang(1:end-n))./(2*pi*(tv(n+1:end)-tv(1:end-n)));
  ft=fts{j};x=fs{j};ros{j}=(x(h+1:end)-x(1:end-h))./(ft(h+1:end)-ft(1:end-h));rts{j}=ft(h+1:end);
 end
 % Interpolate instantaneous terminal voltages to bank-current timestamps.
 vx=interp1(tv,v,tbk,'linear');[vc,~]=abc(vx);[ic,~]=abc(ibank);
 pbk=sum(vx.*ibank,2)/1e6;qbk=1.5*imag(vc.*conj(ic))/1e6;
 pq={b(:,2:3)/1e6,p(:,1:2)/1e6,w(:,1:2)/1e6};tq={tb,tp,tw};dc={b(:,7),p(:,9),w(:,9)};
 amps={sqrt(2/3*sum(l.^2,2)),hypot(pd(:,9),pd(:,10)),hypot(id(:,1),iq(:,1))};ta={tl,td,ti};ibase=sqrt(2)*6.25e6/(sqrt(3)*690);
 % These are actual 50 Hz AC-source branch current envelopes; no new overload credits.
 finish=[edges stop];labels={'isolated_pre','after_sun_down','after_bank_on','after_wind_down','after_sun_return'};
 for h=1:5
  S=struct('name',labels{h},'window_s',[finish(h)-.2 finish(h)]);
  for k=1:10
   a=finish(h)-.2+(k-1)*.02;z=a+.02;
   S.PCC_V(k,1)=meanw(tg,g(:,3),a,z);S.frequency_Hz(k,1)=meanw(fts{2},fs{2},a,z);
   for j=1:3
    y=meanw(tq{j},pq{j},a,z);S.P_MW(k,j)=y(1);S.Q_Mvar(k,j)=y(2);S.S_pu(k,j)=hypot(y(1),y(2))/6.25;
    S.current_pu(k,j)=sqrt(meanw(ta{j},amps{j}.^2,a,z))/ibase;S.Vdc_V(k,j)=meanw(tq{j},dc{j},a,z);
   end
   S.PLL_Hz(k,:)=[meanw(tp,p(:,4),a,z) meanw(tw,w(:,4),a,z)];S.SOC(k,1)=meanw(tb,b(:,6),a,z);S.battery_I_A(k,1)=meanw(tb,b(:,8),a,z);
   S.PV_PF(k,1)=S.P_MW(k,2)/hypot(S.P_MW(k,2),S.Q_Mvar(k,2));S.weather(k,:)=[meanw(tsun,sun,a,z) meanw(twind,wind,a,z)];
   S.bank_open(k,1)=meanw(tbank,open,a,z);S.bank_PQ_M(k,:)=[meanw(tbk,pbk,a,z) meanw(tbk,qbk,a,z)];
   S.coord_W(k,:)=meanw(tc,cmd,a,z);S.available_MW(k,:)=[meanw(tp,p(:,5),a,z),meanw(tw,w(:,5),a,z)]/1e6;
   S.PQ_residual_M(k,:)=[sum(S.P_MW(k,:))-5-S.bank_PQ_M(k,1),sum(S.Q_Mvar(k,:))-1.5-S.bank_PQ_M(k,2)];
  end
  % Conservative PCS-circle estimates based on measured P, not guaranteed
  % delivered Q (feeder/transformer and local-voltage limitations not included).
  cap=.8*6.25*min(1,S.PCC_V/1e4);qc=sqrt(max(0,cap.^2-S.P_MW.^2));
  S.Q_up_estimate_Mvar=min(qc-S.Q_Mvar,[],1);S.Q_down_estimate_Mvar=min(qc+S.Q_Mvar,[],1);
  S.max_fraction_I=max(S.current_pu,[],1);S.max_fraction_S=max(S.S_pu,[],1);S.P_span_MW=range(S.P_MW,1);S.Q_span_Mvar=range(S.Q_Mvar,1);
  S.checks=struct('bus_voltage',all(abs(S.PCC_V-1e4)<500)&&range(S.PCC_V)<150,'freq',all(abs(S.frequency_Hz-50)<.5), ...
    'pll',all(abs(S.PLL_Hz-S.frequency_Hz)<.1,'all'),'PF',all(abs(S.PV_PF-.9)<.025)&&all(S.Q_Mvar(:,2)>0), ...
    'dc',all(abs(S.Vdc_V-1500)<75,'all'),'SOC',all(S.SOC>.20&S.SOC<.90),'battery_continuous',all(abs(S.battery_I_A)<.8*4500), ...
    'P_balance',all(abs(S.PQ_residual_M(:,1))<.15),'Q_balance',all(abs(S.PQ_residual_M(:,2))<.20), ...
    'reserves',all(S.current_pu<.8,'all')&&all(S.S_pu<.8,'all'),'no_cycle_drift',all(S.P_span_MW<.05)&&all(S.Q_span_Mvar<.075));
  S.pass=all(structfun(@(x)logical(x),S.checks));R.plateau(h)=S;
 end
 names={'irradiance_down','bank_connection','wind_speed_down','irradiance_recovery'};
 for h=1:4
  a=edges(h);bnd=finish(h+1);pre=R.plateau(h);post=R.plateau(h+1);
  E=struct('name',names{h},'window_s',[a bnd]);E.pre_weather=mean(pre.weather,1);E.post_weather=mean(post.weather,1);del=E.post_weather-E.pre_weather;E.delta_weather=del;
  E.delta_resource_P_MW=mean(post.P_MW,1)-mean(pre.P_MW,1);E.delta_resource_Q_Mvar=mean(post.Q_Mvar,1)-mean(pre.Q_Mvar,1);
  E.delta_reported_available_MW=mean(post.available_MW,1)-mean(pre.available_MW,1);E.bank_delta_PQ_M=mean(post.bank_PQ_M,1)-mean(pre.bank_PQ_M,1);E.coord_pre_W=mean(pre.coord_W,1);E.coord_post_W=mean(post.coord_W,1);
  % Measured source-side PV power can remain curtailed despite a real weather
  % change; quantify actual array P without using it as the irradiance proxy.
  E.delta_array_P_MW=(meanw(td,pd(:,1).*pd(:,2),post.window_s(1),post.window_s(2))-meanw(td,pd(:,1).*pd(:,2),pre.window_s(1),pre.window_s(2)))/1e6;
  E.P_response_gt_10kW=abs(E.delta_resource_P_MW)>.010;
  if h==1,E.input_verified=abs(E.pre_weather(1)-1000)<2 && abs(E.post_weather(1)-950)<2 && abs(del(2))<.02;
  elseif h==2
   % Compare real branch power against the load's voltage-squared admittance.
   ep=(mean(post.PCC_V)/10000)^2*[.1 .03];E.input_verified=all(pre.bank_open>.5)&&all(post.bank_open<.5)&&all(abs(mean(pre.bank_PQ_M,1))<[.005 .003])&&all(abs(mean(post.bank_PQ_M,1)-ep)<[.012 .006])&&abs(del(1))<2&&abs(del(2))<.02;
  elseif h==3,E.input_verified=abs(del(2)+.3)<.03&&abs(del(1))<2;
  else,E.input_verified=abs(E.pre_weather(1)-950)<2 && abs(E.post_weather(1)-1000)<2 && abs(del(2))<.02;end
  E.voltage_extrema_V=ex(tg,g(:,3),a,bnd);
  for j=1:2
   E.freq_extrema_Hz(j,:)=ex(fts{j},fs{j},a,bnd);E.RoCoF_Hz_per_s(j,:)=ex(rts{j},ros{j},a,bnd);
   E.prefreq_extrema_Hz(j,:)=ex(fts{j},fs{j},a-.2,a);E.preRoCoF_Hz_per_s(j,:)=ex(rts{j},ros{j},a-.2,a);
  end
  E.PV_PLL_Hz=ex(tp,p(:,4),a,bnd);E.Wind_PLL_Hz=ex(tw,w(:,4),a,bnd);E.tie_off_peak_A=max(abs(it(ttie>=a & ttie<bnd,:)),[],'all');
  for j=1:3
   E.peak_I_A(j)=max(amps{j}(ta{j}>=a & ta{j}<bnd));E.dc_extrema_V(j,:)=ex(tq{j},dc{j},a,bnd);
   E.P_extrema_MW(j,:)=ex(tq{j},pq{j}(:,1),a,bnd);E.Q_extrema_Mvar(j,:)=ex(tq{j},pq{j}(:,2),a,bnd);
  end
  % Joint return to measured post-event operating point. Power reference is
  % the settled plateau, not the isolated commanded delta. Confirm 100 ms,
  % require the last 100 ms remains inside; event recovery not spuriously
  % granted from nominal f/V if the source commands have not taken effect.
  t=(a-.020:.0001:bnd-.0001)';cm=@(x)movmean(x,[199 0]);
  fq=interp1(fts{2},fs{2},t,'linear');vg=cm(interp1(tg,g(:,3),t,'linear'));
  ok=abs(fq-mean(post.frequency_Hz))<.15 & abs(vg-mean(post.PCC_V))<200;
  for j=1:3
   pa=cm(interp1(tq{j},pq{j}(:,1),t,'linear'));qa=cm(interp1(tq{j},pq{j}(:,2),t,'linear'));
   ok=ok & abs(pa-mean(post.P_MW(:,j)))<.030 & abs(qa-mean(post.Q_Mvar(:,j)))<.050 & abs(cm(interp1(tq{j},dc{j},t,'linear'))-1500)<75;
  end
  ok=ok & abs(cm(interp1(tp,p(:,4),t,'linear'))-fq)<.1 & abs(cm(interp1(tw,w(:,4),t,'linear'))-fq)<.1;
  ok(t<a+.020)=false;z=find(movsum(double(ok),[999 0])==1000,1);
  E.recovery_confirmed_s=[];if ~isempty(z),E.recovery_confirmed_s=t(z)-a;end
  E.tail_dwell=all(ok(end-999:end));E.checks=struct('input_verified',E.input_verified,'utility_isolated',R.utility_open_verified&&E.tie_off_peak_A<2, ...
    'PCC_voltage',all(abs(E.voltage_extrema_V-1e4)<1000),'PCC_frequency',all(abs(E.freq_extrema_Hz(2,:)-50)<.5), ...
    'actual_current',all(E.peak_I_A<R.thresholds.resource_peak_current_A), ...
    'dc_peak',all(abs(E.dc_extrema_V-1500)<150,'all'),'recovery',~isempty(z)&&E.tail_dwell);
  E.transient_pass=all(structfun(@(x)logical(x),E.checks));R.event(h)=E;
 end
 R.steady_pass=R.complete&&R.finite&&R.utility_open_verified&&all([R.plateau.pass])&&all([R.event.input_verified]);
 R.transient_pass=R.complete&&R.finite&&R.utility_open_verified&&all([R.event.transient_pass]);R.pass=R.steady_pass&&R.transient_pass;
 R.limitations='RoCoF depends on the reported window and has no pass threshold. PLL frequency alone cannot exclude a momentary angle slip. Weather changes need not cause identical PCC power deltas under curtailment or coordination. Finite-duration steady case is not a large-fault certificate.';
catch ME,R.error=getReport(ME,'extended','hyperlinks','off');end
end
function [complexAB,angle]=abc(x),complexAB=(2*x(:,1)-x(:,2)-x(:,3))/3+1i*(x(:,2)-x(:,3))/sqrt(3);angle=unwrap(atan2(imag(complexAB),real(complexAB)));end
function [t,x]=arr(y)
t=y.Time(:);if y.IsTimeFirst,x=reshape(y.Data,numel(t),[]);else,x=reshape(y.Data,[],numel(t)).';end
[t,j]=unique(t,'last');x=x(j,:);assert(~isempty(t));
end
function y=meanw(t,x,a,b)
if isscalar(t),assert(t<=a+1e-10);y=x(1,:);return;end
i=t>=a-1e-10&t<b-1e-10;if nnz(i)>1,y=mean(x(i,:),1);else,j=find(t<=(a+b)/2+1e-10,1,'last');assert(~isempty(j));y=x(j,:);end
end
function q=ex(t,x,a,b),i=t>=a-1e-10&t<b-1e-10;assert(any(i));q=[min(x(i)) max(x(i))];end
