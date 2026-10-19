function trafficSpeed_kmh = getTraffic(speedLimit_kmh, congestionLevel, roadTypes)
% GETTRAFFIC Computes realistic traffic speed vector based on road types and congestion
%
% Inputs:
%   speedLimit_kmh  - Vector of legal speed limits (km/h)
%   congestionLevel - 'Low' (Free Flow), 'Moderate', 'Heavy', 'Severe'
%   roadTypes       - Cell array or string array of road classification
%
% Output:
%   trafficSpeed_kmh - Realistic traffic flow speed (km/h)

    if nargin < 2 || isempty(congestionLevel)
        congestionLevel = 'Moderate';
    end

    n = numel(speedLimit_kmh);
    if nargin < 3 || isempty(roadTypes)
        roadTypes = repmat({'Highway'}, n, 1);
    end

    % Base congestion factors
    switch lower(string(congestionLevel))
        case {'low', 'freeflow'}
            factor = 0.95;
            variance = 0.03;
        case 'moderate'
            factor = 0.80;
            variance = 0.08;
        case 'heavy'
            factor = 0.55;
            variance = 0.12;
        case 'severe'
            factor = 0.35;
            variance = 0.15;
        otherwise
            factor = 0.80;
            variance = 0.05;
    end

    % Random slight variation along route for realism (seeded for reproducibility)
    rng(42);
    noise = 1 + variance * randn(n, 1);

    trafficSpeed_kmh = speedLimit_kmh .* factor .* noise;

    % Urban / Ghat specific constraints
    for i = 1:n
        rType = lower(string(roadTypes{min(i, numel(roadTypes))}));
        if contains(rType, 'urban') || contains(rType, 'city')
            trafficSpeed_kmh(i) = min(trafficSpeed_kmh(i), 45);
        elseif contains(rType, 'ghat') || contains(rType, 'incline')
            trafficSpeed_kmh(i) = min(trafficSpeed_kmh(i), 55);
        end
    end

    % Ensure within physical bounds: at least 10 km/h and <= speed limit
    trafficSpeed_kmh = max(10, min(speedLimit_kmh, trafficSpeed_kmh));
end
