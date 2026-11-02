function R=validate_pv_resource_v2(implementation)
%VALIDATE_PV_RESOURCE_V2 Run the selected PV acceptance path.
if nargin<1,implementation='dynamic';end
switch lower(char(implementation))
    case 'dynamic',R=validate_pv_dynamic_physical();
    case 'legacy',R=validate_pv_resource_v2_legacy();
    otherwise,error('PV:UnknownImplementation','Use dynamic or legacy.');
end
end
