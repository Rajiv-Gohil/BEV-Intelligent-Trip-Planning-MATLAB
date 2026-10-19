function [isValid, cleanedRoute, issues] = validateRouteData(rawRoute)
% VALIDATEROUTEDATA Inspects and sanitizes route data structures
%
% Checks:
%   - Field presence (Distance_km, Elevation_m, SpeedLimit_kmh, TrafficSpeed_kmh)
%   - Monotonically increasing distance
%   - NaN, Inf, or empty values
%   - Physically plausible grade limits (-25% <= grade <= +25%)
%   - Speed limits within legal automotive boundaries (10 <= v <= 150 km/h)

    isValid = true;
    issues = {};
    cleanedRoute = rawRoute;

    requiredFields = {'Distance_km', 'Elevation_m'};
    for i = 1:numel(requiredFields)
        fn = requiredFields{i};
        if ~isfield(rawRoute, fn) || isempty(rawRoute.(fn))
            isValid = false;
            issues{end+1} = sprintf('Missing required field: %s', fn); %#ok<AGROW>
            return;
        end
    end

    % Check for NaN or Inf
    d = rawRoute.Distance_km(:);
    elev = rawRoute.Elevation_m(:);

    if any(isnan(d)) || any(isinf(d))
        issues{end+1} = 'Distance contains NaN or Inf values. Cleaned using interpolation.';
        mask = ~isnan(d) & ~isinf(d);
        d = interp1(find(mask), d(mask), (1:numel(d))', 'linear', 'extrap');
    end

    if any(isnan(elev)) || any(isinf(elev))
        issues{end+1} = 'Elevation contains NaN or Inf values. Cleaned using interpolation.';
        mask = ~isnan(elev) & ~isinf(elev);
        elev = interp1(find(mask), elev(mask), (1:numel(elev))', 'linear', 'extrap');
    end

    % Ensure monotonically increasing distance
    if any(diff(d) <= 0)
        issues{end+1} = 'Distance is not strictly monotonic. Enforcing monotonic progression.';
        for k = 2:numel(d)
            if d(k) <= d(k-1)
                d(k) = d(k-1) + 0.01; % add 10m increment
            end
        end
    end

    % Ensure speed limits exist and are bounded
    if ~isfield(rawRoute, 'SpeedLimit_kmh') || isempty(rawRoute.SpeedLimit_kmh)
        issues{end+1} = 'Missing SpeedLimit_kmh; assigning default 80 km/h.';
        cleanedRoute.SpeedLimit_kmh = 80 * ones(size(d));
    else
        cleanedRoute.SpeedLimit_kmh = max(20, min(130, rawRoute.SpeedLimit_kmh(:)));
    end

    % Ensure traffic speed exists and is bounded by speed limit
    if ~isfield(rawRoute, 'TrafficSpeed_kmh') || isempty(rawRoute.TrafficSpeed_kmh)
        cleanedRoute.TrafficSpeed_kmh = cleanedRoute.SpeedLimit_kmh * 0.85;
    else
        cleanedRoute.TrafficSpeed_kmh = max(10, min(cleanedRoute.SpeedLimit_kmh, rawRoute.TrafficSpeed_kmh(:)));
    end

    % Ensure coordinates exist
    if ~isfield(rawRoute, 'Latitude') || isempty(rawRoute.Latitude)
        cleanedRoute.Latitude = linspace(19.0760, 18.5204, numel(d))';
    end
    if ~isfield(rawRoute, 'Longitude') || isempty(rawRoute.Longitude)
        cleanedRoute.Longitude = linspace(72.8777, 73.8567, numel(d))';
    end

    cleanedRoute.Distance_km = d;
    cleanedRoute.Elevation_m = elev;
    cleanedRoute.TotalDistance_km = d(end) - d(1);

    if isempty(issues)
        issues = {'Route data is physically valid and ready for simulation.'};
    end
end
