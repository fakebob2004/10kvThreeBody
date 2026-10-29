function api_synced = sync_api_to_continuous_time(api, t)
%SYNC_API_TO_CONTINUOUS_TIME Synchronizes discrete API logs to continuous time grid t.

N = numel(t);
if size(api, 1) == N
    api_synced = api;
    return;
end

t_api = linspace(0, t(end), size(api, 1)).';
api_synced = interp1(t_api, api, t, 'previous', 'extrap');
end
