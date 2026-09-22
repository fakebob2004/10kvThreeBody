function commandOut=stage2_coordinator_algorithm(status,commandIn,coordinatorEnable,config)
%#codegen
% External, code-generation-compatible Stage-2 coordinator safety shell.
% Rows are [BESS; PV; Wind]. Columns follow S2_API field maps.
% config = [AUTONOMOUS COORDINATED BLOCKED SOCmin SOCmax P_W(1:3) S_VA(1:3)].
coordinatedMode=config(2);blockedMode=config(3);
socMin=config(4);socMax=config(5);
pRating=config(6:8);sRating=config(9:11);
commandOut=commandIn;
for r=1:3
    P=commandIn(r,1);Q=commandIn(r,2);en=commandIn(r,3);mode=commandIn(r,4);
    health=status(r,8);kI=max(0,min(1,status(r,7)));
    if health<.5 || en<.5 || mode==blockedMode
        commandOut(r,:)=[0 0 0 mode];continue
    end
    if coordinatorEnable>.5 && mode==coordinatedMode
        if r==1
            soc=status(r,9);
            if soc<=socMin,P=min(P,0);end
            if soc>=socMax,P=max(P,0);end
            P=max(-pRating(r),min(pRating(r),P));
        else
            Pav=max(0,status(r,5));
            P=max(0,min(min(Pav,pRating(r)),P));
        end
        S=sRating(r)*max(.1,kI);
        Qmax=sqrt(max(0,S*S-P*P));Q=max(-Qmax,min(Qmax,Q));
    end
    commandOut(r,:)=[P Q 1 mode];
end
end
