function set_coordinator_sample_time(model, sampleTime)
%SET_COORDINATOR_SAMPLE_TIME Sets discrete sample time on the Coordinator
% MATLAB Function block across MATLAB R2023b - R2026a releases.

if nargin < 2, sampleTime = 0.005; end
if ischar(sampleTime)
    stStr = sampleTime;
    stNum = str2double(sampleTime);
else
    stNum = sampleTime;
    stStr = num2str(sampleTime);
end

apiSub = [model '/07 Resource API Layer'];
blk = [apiSub '/MATLAB Function Coordinator'];

try
    set_param(blk, 'SystemSampleTime', stStr);
catch
    % Fall back to Stateflow EMChart object API (R2023b requirement)
    try
        rt = sfroot;
        chart = find(rt, '-isa', 'Stateflow.EMChart', 'Path', blk);
        if ~isempty(chart)
            chart.ChartUpdate = 'DISCRETE';
            chart.SampleTime = stStr;
        end
    catch
    end
end
end
