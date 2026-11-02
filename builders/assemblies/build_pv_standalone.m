function modelFile=build_pv_standalone(implementation)
%BUILD_PV_STANDALONE Generate physical PV by default; legacy is opt-in.
% build_pv_standalone('dynamic') uses a real DC network and an average VSC.
% build_pv_standalone('legacy') preserves the accepted system-level GFL path.
if nargin<1,implementation='dynamic';end
switch lower(char(implementation))
    case 'dynamic',modelFile=build_pv_dynamic_standalone();
    case 'legacy',modelFile=build_pv_legacy_standalone();
    otherwise,error('PV:UnknownImplementation','Use dynamic or legacy.');
end
end
