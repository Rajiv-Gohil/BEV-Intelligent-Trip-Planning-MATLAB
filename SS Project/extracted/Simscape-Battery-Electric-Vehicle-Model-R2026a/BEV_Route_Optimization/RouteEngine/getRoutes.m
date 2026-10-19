function routes = getRoutes(origin, destination, apiKey, offlineMode)
% GETROUTES Retrieves route information via Google Routes API or offline datasets
%
% Inputs:
%   origin       - Origin string (e.g. 'Mumbai' or 'Mumbai, Maharashtra')
%   destination  - Destination string (e.g. 'Pune' or 'Pune, Maharashtra')
%   apiKey       - Optional Google Maps API key string (leave '' for offline)
%   offlineMode  - Optional logical flag (default true if apiKey is empty)
%
% Outputs:
%   routes       - Cell array of route structures (supporting route alternatives)

    if nargin < 3
        apiKey = '';
    end
    if nargin < 4
        offlineMode = isempty(apiKey);
    end

    originStr = lower(string(origin));
    destStr = lower(string(destination));

    % Attempt Live API call if requested and key provided
    if ~offlineMode && ~isempty(apiKey)
        try
            routes = queryGoogleRoutesAPI(origin, destination, apiKey);
            if ~isempty(routes)
                return;
            end
        catch ME
            warning('Google Routes API query failed: %s. Falling back to offline dataset.', ME.message);
        end
    end

    % Offline Route Retrieval Engine
    routes = retrieveOfflineRoutes(originStr, destStr);
end

%% Helper: Query Google Routes API via MATLAB HTTP
function routeList = queryGoogleRoutesAPI(origin, destination, apiKey)
    routeList = {};
    baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';
    url = sprintf('%s?origin=%s&destination=%s&alternatives=true&key=%s', ...
        baseUrl, urlencode(origin), urlencode(destination), apiKey);

    options = weboptions('Timeout', 10);
    response = webread(url, options);

    if ~isfield(response, 'status') || ~strcmp(response.status, 'OK')
        error('API Error: %s', response.status);
    end

    numRoutes = numel(response.routes);
    for r = 1:numRoutes
        routeData = parseGoogleRoute(response.routes(r), origin, destination);
        routeList{end+1} = routeData; %#ok<AGROW>
    end
end

%% Helper: Parse Google Route JSON into standardized structure
function s = parseGoogleRoute(gRoute, origin, destination)
    leg = gRoute.legs(1);
    totalDist_km = leg.distance.value / 1000;
    totalDur_min = leg.duration.value / 60;

    % Extract polyline coordinates
    points = decodePolyline(gRoute.overview_polyline.points);
    numPts = size(points, 1);
    d_km = linspace(0, totalDist_km, numPts)';

    s = struct();
    s.RouteName = sprintf('%s to %s (Route %s)', origin, destination, gRoute.summary);
    s.Origin = origin;
    s.Destination = destination;
    s.TotalDistance_km = totalDist_km;
    s.EstimatedDuration_min = totalDur_min;
    s.Distance_km = d_km;
    s.Latitude = points(:, 1);
    s.Longitude = points(:, 2);
    s.Elevation_m = zeros(numPts, 1); % To be populated by getElevation
    s.SpeedLimit_kmh = 80 * ones(numPts, 1);
    s.TrafficSpeed_kmh = 65 * ones(numPts, 1);
    s.ChargingStations = [];
    s.StopEvents_Distance_km = [];
end

%% Helper: Polyline decoder for Google Maps polylines
function points = decodePolyline(encoded)
    len = length(encoded);
    index = 1;
    lat = 0;
    lng = 0;
    points = [];

    while index <= len
        result = 0; shift = 0;
        while true
            b = double(encoded(index)) - 63;
            index = index + 1;
            result = bitor(result, bitshift(bitand(b, 31), shift));
            shift = shift + 5;
            if b < 32, break; end
        end
        if bitand(result, 1)
            dlat = bitcmp(bitshift(result, -1), 'int32');
        else
            dlat = bitshift(result, -1);
        end
        lat = lat + dlat;

        result = 0; shift = 0;
        while true
            b = double(encoded(index)) - 63;
            index = index + 1;
            result = bitor(result, bitshift(bitand(b, 31), shift));
            shift = shift + 5;
            if b < 32, break; end
        end
        if bitand(result, 1)
            dlng = bitcmp(bitshift(result, -1), 'int32');
        else
            dlng = bitshift(result, -1);
        end
        lng = lng + dlng;

        points = [points; lat * 1e-5, lng * 1e-5]; %#ok<AGROW>
    end
end

%% Helper: Offline corridor matcher
function routes = retrieveOfflineRoutes(originStr, destStr)
    offlineData = generateOfflineCorridors(false);
    routes = {};

    % Match Mumbai -> Pune (Provides 2 alternative routes for comparison!)
    if (contains(originStr, 'mumbai') && contains(destStr, 'pune')) || ...
       (contains(originStr, 'pune') && contains(destStr, 'mumbai'))
        routes{1} = offlineData.Mumbai_Pune_Expressway;
        routes{2} = offlineData.Mumbai_Pune_OldNH48;
        return;
    end

    % Match Delhi -> Agra
    if (contains(originStr, 'delhi') && contains(destStr, 'agra')) || ...
       (contains(originStr, 'agra') && contains(destStr, 'delhi'))
        routes{1} = offlineData.Delhi_Agra_YamunaExpressway;
        return;
    end

    % Match Bengaluru -> Mysuru
    if (contains(originStr, 'bengaluru') || contains(originStr, 'bangalore')) && ...
       (contains(destStr, 'mysuru') || contains(destStr, 'mysore'))
        routes{1} = offlineData.Bengaluru_Mysuru_Expressway;
        return;
    end

    % Match Chennai -> Puducherry
    if (contains(originStr, 'chennai') && contains(destStr, 'puducherry')) || ...
       (contains(originStr, 'puducherry') && contains(destStr, 'chennai'))
        routes{1} = offlineData.Chennai_Puducherry_ECR;
        return;
    end

    % Match Urban Mumbai
    if contains(originStr, 'andheri') || contains(destStr, 'colaba') || ...
       contains(originStr, 'mumbai urban') || contains(destStr, 'mumbai urban')
        routes{1} = offlineData.Mumbai_Urban_CoastalRoad;
        return;
    end

    % Default fallback: Mumbai to Pune Expressway + Old NH48 alternatives
    routes{1} = offlineData.Mumbai_Pune_Expressway;
    routes{2} = offlineData.Mumbai_Pune_OldNH48;
end
