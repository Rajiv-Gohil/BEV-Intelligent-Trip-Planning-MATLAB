function processedRoute = processRoute(rawRoute, segmentLength_m, smoothSpan_pts)
% PROCESSROUTE Processes road data into uniform segments with smoothed elevation and grade
%
% Inputs:
%   rawRoute        - Struct with Distance_km, Elevation_m, SpeedLimit_kmh, etc.
%   segmentLength_m - Spatial discretization step in meters (default: 200 m)
%   smoothSpan_pts  - Window size for elevation smoothing (default: 7 points)
%
% Output:
%   processedRoute  - Cleaned, segmented struct with:
%                     - Distance_km, Elevation_m, Grade_pct, Grade_rad
%                     - SpeedLimit_kmh, TrafficSpeed_kmh
%                     - ElevationGain_m, ElevationLoss_m
%                     - SegmentsTable (MATLAB Table of road segments)

    if nargin < 2 || isempty(segmentLength_m)
        segmentLength_m = 200;
    end
    if nargin < 3 || isempty(smoothSpan_pts)
        smoothSpan_pts = 7;
    end

    % 1. Validate and clean input
    [isValid, route, issues] = validateRouteData(rawRoute);
    if ~isValid
        error('Route validation failed: %s', strjoin(issues, '; '));
    end

    totalDist_km = route.Distance_km(end);
    ds_km = segmentLength_m / 1000;
    s_vec = (0:ds_km:totalDist_km)';
    if s_vec(end) < totalDist_km
        s_vec = [s_vec; totalDist_km];
    end
    numSegments = numel(s_vec);

    % 2. Interpolate elevation, speed limit, traffic speed, and coordinates
    raw_s = route.Distance_km;
    elev_interp = interp1(raw_s, route.Elevation_m, s_vec, 'pchip');
    spd_limit = interp1(raw_s, route.SpeedLimit_kmh, s_vec, 'nearest');
    traf_spd = interp1(raw_s, route.TrafficSpeed_kmh, s_vec, 'linear');
    lat = interp1(raw_s, route.Latitude, s_vec, 'linear');
    lon = interp1(raw_s, route.Longitude, s_vec, 'linear');

    % 3. Filter/Smooth noisy elevation data (Moving Average Filter)
    span = max(3, min(smoothSpan_pts, floor(numSegments / 4)));
    if mod(span, 2) == 0, span = span + 1; end
    elev_smoothed = smoothdata(elev_interp, 'movmean', span);

    % 4. Compute Road Grade from Delta Elevation / Delta Distance
    delta_s_m = [diff(s_vec) * 1000; ds_km * 1000]; % meters
    delta_elev_m = [diff(elev_smoothed); 0];         % meters

    grade_pct = (delta_elev_m ./ max(delta_s_m, 1)) * 100;
    % Clip grade to realistic road vehicle design limits (-15% to +15%)
    grade_pct = max(-15.0, min(15.0, grade_pct));
    grade_rad = atan(grade_pct / 100);

    % 5. Elevation gain / loss calculations
    dElev = diff(elev_smoothed);
    elevGain_m = sum(dElev(dElev > 0));
    elevLoss_m = sum(abs(dElev(dElev < 0)));

    % 6. Build Segments Table
    segTable = table(...
        s_vec, elev_smoothed, grade_pct, spd_limit, traf_spd, lat, lon, ...
        'VariableNames', {'Distance_km', 'Elevation_m', 'Grade_pct', ...
                          'SpeedLimit_kmh', 'TrafficSpeed_kmh', 'Latitude', 'Longitude'});

    % 7. Package output structure
    processedRoute = route;
    processedRoute.Distance_km = s_vec;
    processedRoute.Elevation_m = elev_smoothed;
    processedRoute.RawElevation_m = elev_interp;
    processedRoute.Grade_pct = grade_pct;
    processedRoute.Grade_rad = grade_rad;
    processedRoute.SpeedLimit_kmh = spd_limit;
    processedRoute.TrafficSpeed_kmh = traf_spd;
    processedRoute.Latitude = lat;
    processedRoute.Longitude = lon;
    processedRoute.ElevationGain_m = elevGain_m;
    processedRoute.ElevationLoss_m = elevLoss_m;
    processedRoute.TotalDistance_km = totalDist_km;
    processedRoute.SegmentsTable = segTable;
    processedRoute.ValidationIssues = issues;
end
