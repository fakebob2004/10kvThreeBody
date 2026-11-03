function R=p3_lvrt_metrics_new(o,expected_sag_pu)
% Strong-grid balanced-sag diagnostic. Course design screens, not grid-code
% certification. expected_sag_pu optionally specifies allowed mean measured PCC
% interval in pu of 10 kV; keep identical for A and B only if prescribed.
if nargin<2,expected_sag_pu=[0 .90];end
assert(numel(expected_sag_pu)==2 && expected_sag_pu(1)>=0 && expected_sag_pu(1)<expected_sag_pu(2));
on=2.65;off=2.80;finish=3.6;
R=struct('pass',false,'result_scope','Pre-energized strong-grid averaged LVRT: engineering screens, not device/grid-code certification.','resource_order','BESS, PV, Wind; grid is fourth for P/Q','fault_command_s',[on off],'expected_sag_pu',expected_sag_pu);
[tg,g]=matTS(o.integration_sm);[tp,p]=matTS(o.integration_pv);[tw,w]=matTS(o.integration_wind);[tl,l]=matTS(o.vsm_iL1);[td,d]=matTS(o.pv_dynamic);
[ti,id]=matTS(o.logsout.get('Id_converter').Values);[tq,iq]=matTS(o.logsout.get('Iq_converter').Values);assert(isequal(ti,tq));
[ts,s]=matTS(o.bw_sync);
b=squeeze(o.gfm_r7_result);if size(b,2)~=15,b=b.';end;assert(size(b,2)==15);tb=b(:,1);
tt={tb,tp,tw,tg};pq={b(:,2:3),p(:,1:2),w(:,1:2),g(:,1:2)};dc={b(:,7),p(:,9),w(:,9)};pl={p(:,4),w(:,4)};
R.threshold_note='Selected predeclared screens: nominal voltage 10 kV, DC 1500 V, sustained dip below 0.90 pu for >=0.10 s, phase-current envelope from commissioning dq limits, post-fault voltage peak <=1.20 pu, recovery checks for 100 ms. No 20% steady reserve imposed during faults.';
R.thresholds=struct('post_clear_peak_pu',1.20,'dc_excursion_V',300,'recovered_dc_excursion_V',75,'recovered_PLL_error_Hz',.10,'recovery_PF_error',.02,'recovered_voltage_error_pu',.05,'dwell_s',.10,'power_recovery_rel',.10,'power_recovery_floor_MW',.05);
R.checks.complete=all(cellfun(@(t)t(1)<=on-.12 && t(end)>=finish-1e-8,[tt,{tl,td,ti,ts}]));
R.checks.finite=all(cellfun(@(x)all(isfinite(x(:))),[pq,dc,pl,{g,l,d,id,iq,s}]));
R.checks.tie_closed=all(s(ts>=on-.12,1)<.5); % physical branch current logged separately
win=[on-.12 on-.02;on+.03 off-.01;off+.08 off+.18;finish-.14 finish-.02];
R.PQ_window_order='pre, sag plateau, early recovery, tail';R.PQ_window_s=win;
for a=1:4
 for j=1:4,R.mean_P_MW(j,a)=avg(tt{a},pq{a}(:,1),win(j,:))/1e6;R.mean_Q_Mvar(j,a)=avg(tt{a},pq{a}(:,2),win(j,:))/1e6;end
end
R.delta_fault_Q_Mvar=R.mean_Q_Mvar(2,:)-R.mean_Q_Mvar(1,:);
R.PV_PF=R.mean_P_MW(:,2)./hypot(R.mean_P_MW(:,2),R.mean_Q_Mvar(:,2));
pu=g(:,3)/1e4;R.nominal_reference_V=1e4;R.pre_PCC_pu=avg(tg,pu,win(1,:));
R.sag_mean_pu=avg(tg,pu,win(2,:));R.sag_to_pre=R.sag_mean_pu/R.pre_PCC_pu;
y=pu(tg>=on&tg<off);R.sag_min_pu=min(y);R.post_clear_peak_pu=max(pu(tg>=off));
% Longest consecutive run below threshold overlapping the commanded dip.
idx=find(tg>=on-.02 & tg<=finish);t=tg(idx);v=pu(idx);lo=v<.9;ed=diff([false;lo;false]);st=find(ed==1);en=find(ed==-1)-1;
ends=t(min(en+1,numel(t)));ok=t(st)<off & ends>on;R.longest_dip_s=0;R.measured_dip_interval_s=[];
if any(ok),st=st(ok);ends=ends(ok);[R.longest_dip_s,j]=max(ends-t(st));R.measured_dip_interval_s=[t(st(j)) ends(j)];end
R.checks.actual_sag=R.sag_mean_pu>=expected_sag_pu(1)&&R.sag_mean_pu<expected_sag_pu(2)&&R.longest_dip_s>=.10 && R.pre_PCC_pu>=.95 && R.pre_PCC_pu<=1.05;
amps={sqrt(2/3*sum(l.^2,2)),hypot(d(:,9),d(:,10)),hypot(id,iq)};ta={tl,td,ti};
% Freeze the conservative existing commissioning ceilings (not nameplate overload budgets).
R.current_limit_A=[8875, sqrt(2)*1.1*6.25e6/(sqrt(3)*690),9963.76811594203];
for j=1:3
 x=amps{j};t=ta{j};R.current_peak_sag_A(j)=max(x(t>=on&t<off));R.current_peak_clear_A(j)=max(x(t>=off));t=tt{j};u=dc{j};R.dc_range_V(j,:)=[min(u(t>=on)) max(u(t>=on))];
end
R.current_peak_ratio=max([R.current_peak_sag_A;R.current_peak_clear_A],[],1)./R.current_limit_A;R.checks.current=all(R.current_peak_ratio<=1);
R.checks.dc=all(abs(R.dc_range_V-1500)<=R.thresholds.dc_excursion_V,'all');
R.checks.postclear_voltage=R.post_clear_peak_pu<=R.thresholds.post_clear_peak_pu;
for j=1:2
 t=tt{j+1};x=pl{j};R.PLL_fault_Hz(j,:)=[min(x(t>=on&t<off)), max(x(t>=on&t<off))];R.PLL_tail_Hz(j,:)=[min(x(t>=finish-.1)),max(x(t>=finish-.1))];
end
R.PLL_note='Frequency recovery is a proxy, not proof of no phase slip during sag; see local phase/angle traces where available.';
% Fixed-grid trailing one-cycle averages, then joint 5-cycle valid dwell.
% Use previous-sample hold from native channels on a 0.1 ms reporting grid.
t=(off-.02:1e-4:finish-1e-4)';nc=200;nd=1000;y=cycle(tg,pu,t,nc);ready=abs(y-1)<=.05;
for j=1:3
 sP=cycle(tt{j},pq{j}(:,1)/1e6,t,nc);base=R.mean_P_MW(1,j);
 ready=ready & abs(sP-base)<=max(.05,.10*abs(base)) & abs(cycle(tt{j},dc{j},t,nc)-1500)<=75;
 if j==2
  sQ=cycle(tt{j},pq{j}(:,2)/1e6,t,nc);ready=ready & sQ>0 & abs(sP./hypot(sP,sQ)-.9)<=.02;
 end
 if j>1,ready=ready & abs(cycle(tt{j},pl{j-1},t,nc)-50)<=.10;end
end
ready(t<off+.02)=false;j=find(movsum(double(ready),[nd-1 0])>=nd,1);
R.recovery_from_clear_s=[];if ~isempty(j),R.recovery_from_clear_s=t(j)-off;end % confirmation time (end of dwell)
R.checks.recovered=~isempty(j)&&all(ready(end-nd+1:end));
R.checks.prefault_PF=abs(R.PV_PF(1)-.9)<.02 && R.mean_Q_Mvar(1,2)>0;
R.pass=all(structfun(@(x)logical(x),R.checks));
end
function [t,x]=matTS(a)
t=a.Time(:);if a.IsTimeFirst,x=reshape(a.Data,numel(t),[]);else,x=reshape(a.Data,[],numel(t)).';end
end
function y=avg(t,x,w)
ix=t>=w(1)&t<w(2);assert(nnz(ix)>1);y=trapz(t(ix),x(ix))/(max(t(ix))-min(t(ix)));
end
function v=cycle(tx,y,t,N)
[tx,ia]=unique(tx,'last');v=movmean(interp1(tx,y(ia),t,'previous',NaN),[N-1 0]);
end
