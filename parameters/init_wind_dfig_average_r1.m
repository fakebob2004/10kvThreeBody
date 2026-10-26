%INIT_WIND_DFIG_AVERAGE_R1 Parameters for the average-converter DFIG model.

DFIG=struct();
DFIG.Base.Sn=5e6;
DFIG.Base.f=50;
DFIG.Base.ws=2*pi*DFIG.Base.f;
DFIG.Base.Vll=690;
DFIG.Base.VphasePeak=DFIG.Base.Vll*sqrt(2/3);
DFIG.Base.Iline=DFIG.Base.Sn/(sqrt(3)*DFIG.Base.Vll);
DFIG.Base.Z=DFIG.Base.Vll^2/DFIG.Base.Sn;
DFIG.Base.L=DFIG.Base.Z/DFIG.Base.ws;

% Wind turbine and geared drive train.
DFIG.Wind.rho=1.225;
DFIG.Wind.radius=70;
DFIG.Wind.area=pi*DFIG.Wind.radius^2;
DFIG.Wind.CpMax=0.48;
DFIG.Wind.lambdaOpt=8.1;
DFIG.Wind.lambdaWidth=3.0;
DFIG.Wind.v0=9.0;
DFIG.Wind.vStep=1.0;
DFIG.Wind.stepTime=0.35;
DFIG.Wind.etaGear=0.985;

% A two-pole-pair wound-rotor machine is geared to 0.96 pu speed at 9 m/s.
DFIG.Machine.p=2;
DFIG.Machine.wSyncMech=DFIG.Base.ws/DFIG.Machine.p;
omegaTurb0=DFIG.Wind.lambdaOpt*DFIG.Wind.v0/DFIG.Wind.radius;
DFIG.Drive.gearRatio=0.96*DFIG.Machine.wSyncMech/omegaTurb0;
DFIG.Drive.H=4.0;
DFIG.Drive.J=2*DFIG.Drive.H*DFIG.Base.Sn/DFIG.Machine.wSyncMech^2;
DFIG.Drive.B=0.002*DFIG.Base.Sn/DFIG.Machine.wSyncMech^2;
DFIG.Drive.omega0=0.96*DFIG.Machine.wSyncMech;
DFIG.Drive.omegaMin=0.70*DFIG.Machine.wSyncMech;

% Standard per-unit wound-rotor induction-machine data, converted to SI.
DFIG.Machine.Rs=0.007*DFIG.Base.Z;
DFIG.Machine.Rr=0.005*DFIG.Base.Z;
DFIG.Machine.Lls=0.10*DFIG.Base.L;
DFIG.Machine.Llr=0.10*DFIG.Base.L;
DFIG.Machine.Lm=3.00*DFIG.Base.L;
DFIG.Machine.Ls=DFIG.Machine.Lls+DFIG.Machine.Lm;
DFIG.Machine.Lr=DFIG.Machine.Llr+DFIG.Machine.Lm;
den=DFIG.Machine.Ls*DFIG.Machine.Lr-DFIG.Machine.Lm^2;
axisMap=[DFIG.Machine.Lr -DFIG.Machine.Lm; ...
        -DFIG.Machine.Lm DFIG.Machine.Ls]/den;
DFIG.Machine.CurrentFromFlux=[axisMap(1,1) 0 axisMap(1,2) 0; ...
    0 axisMap(1,1) 0 axisMap(1,2); ...
    axisMap(2,1) 0 axisMap(2,2) 0; ...
    0 axisMap(2,1) 0 axisMap(2,2)];

% Consistent initial flux/current operating point at the 9 m/s optimum.
DFIG.Initial.psiDs=DFIG.Base.VphasePeak/DFIG.Base.ws;
DFIG.Initial.psiQs=0;
DFIG.Initial.idr=DFIG.Initial.psiDs/DFIG.Machine.Lm;
Pwind0=0.5*DFIG.Wind.rho*DFIG.Wind.area*DFIG.Wind.v0^3* ...
    DFIG.Wind.CpMax*DFIG.Wind.etaGear;
DFIG.Initial.Pwind=Pwind0;
DFIG.Initial.Tm=Pwind0/DFIG.Drive.omega0;
DFIG.Initial.Te=-DFIG.Initial.Tm;
torqueGain=1.5*DFIG.Machine.p*DFIG.Initial.psiDs* ...
    DFIG.Machine.Lm/DFIG.Machine.Ls;
DFIG.Initial.iqr=-DFIG.Initial.Te/torqueGain;
DFIG.Initial.ids=0;
DFIG.Initial.iqs=-DFIG.Machine.Lm/DFIG.Machine.Ls*DFIG.Initial.iqr;
DFIG.Initial.psiDr=DFIG.Machine.Lm*DFIG.Initial.ids+ ...
    DFIG.Machine.Lr*DFIG.Initial.idr;
DFIG.Initial.psiQr=DFIG.Machine.Ls*DFIG.Initial.iqs+ ...
    DFIG.Machine.Lm*DFIG.Initial.iqr;
DFIG.Initial.flux=[DFIG.Initial.psiDs DFIG.Initial.psiQs ...
    DFIG.Initial.psiDr DFIG.Initial.psiQr];

% Rotor-side converter: stator-flux-oriented current control.
DFIG.RSC.Sn=0.35*DFIG.Base.Sn;
DFIG.RSC.Imax=1.25*hypot(DFIG.Initial.idr,DFIG.Initial.iqr);
DFIG.RSC.bandwidth=80;
DFIG.RSC.Lsigma=DFIG.Machine.Lr-DFIG.Machine.Lm^2/DFIG.Machine.Ls;
DFIG.RSC.Kp=2*pi*DFIG.RSC.bandwidth*DFIG.RSC.Lsigma;
DFIG.RSC.Ki=2*pi*DFIG.RSC.bandwidth*DFIG.Machine.Rr;
DFIG.RSC.Vmax=400;
DFIG.RSC.idrRef=DFIG.Initial.idr;
DFIG.RSC.torqueToIqr=1/torqueGain;

% Shared DC link and grid-side average converter.
DFIG.DC.Vnom=1200;
DFIG.DC.C=0.08;
DFIG.DC.lossW=0.002*DFIG.RSC.Sn;
DFIG.DC.Vfloor=0.65*DFIG.DC.Vnom;
DFIG.GSC.Sn=DFIG.RSC.Sn;
DFIG.GSC.Imax=1.20*DFIG.GSC.Sn/(sqrt(3)*DFIG.Base.Vll);
DFIG.GSC.R=0.01*(DFIG.Base.Vll^2/DFIG.GSC.Sn);
DFIG.GSC.L=0.12*(DFIG.Base.Vll^2/DFIG.GSC.Sn)/DFIG.Base.ws;
DFIG.GSC.bandwidth=150;
DFIG.GSC.Kp=2*pi*DFIG.GSC.bandwidth*DFIG.GSC.L;
DFIG.GSC.Ki=2*pi*DFIG.GSC.bandwidth*DFIG.GSC.R;
DFIG.GSC.VdcKp=1.0;
DFIG.GSC.VdcKi=20;
DFIG.GSC.Vmax=0.95*DFIG.DC.Vnom/sqrt(3);

slip0=DFIG.Base.ws-DFIG.Machine.p*DFIG.Drive.omega0;
DFIG.Initial.vdr=DFIG.Machine.Rr*DFIG.Initial.idr- ...
    slip0*DFIG.Initial.psiQr;
DFIG.Initial.vqr=DFIG.Machine.Rr*DFIG.Initial.iqr+ ...
    slip0*DFIG.Initial.psiDr;
DFIG.Initial.Protor=1.5*(DFIG.Initial.vdr*DFIG.Initial.idr+ ...
    DFIG.Initial.vqr*DFIG.Initial.iqr);
DFIG.Initial.igqGSC=-(DFIG.Initial.Protor+DFIG.DC.lossW)/ ...
    (1.5*DFIG.Base.VphasePeak);

DFIG.Grid.Vdq=[0 DFIG.Base.VphasePeak];
DFIG.Simulation.StopTime=0.60;
DFIG.Simulation.MaxStep=1e-4;

assignin('base','DFIG',DFIG);
fprintf(['DFIG average R1 parameters: 5 MW, 690 V stator, 35%% rotor converter, ' ...
    '1200 V DC, geared 2-pole-pair wound-rotor machine.\n']);
