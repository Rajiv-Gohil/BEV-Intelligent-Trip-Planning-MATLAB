function elevation_m = getElevation(lat, lon, apiKey, fallbackElev)
% GETELEVATION Retrieves or computes elevation data along geographic coordinates
%
% Inputs:
%   lat          - Array of latitude points (degrees)
%   lon          - Array of longitude points (degrees)
%   apiKey       - Optional Google Elevation API key
%   fallbackElev - Optional existing or synthetic elevation profile
%
% Output:
%   elevation_m  - Array of elevation points in meters

    if nargin < 3
        apiKey = '';
    end
    if nargin < 4
        fallbackElev = [];
    end

    numPts = numel(lat);

    % Use existing fallback if valid and non-zero
    if ~isempty(fallbackElev) && any(fallbackElev > 0)
        elevation_m = fallbackElev(:);
        return;
    end

    % Attempt Live Elevation API call if key provided
    if ~isempty(apiKey)
        try
            elevation_m = queryGoogleElevation(lat, lon, apiKey);
            if ~isempty(elevation_m)
                return;
            end
        catch ME
            warning('Google Elevation API failed: %s. Using synthetic topographic interpolation.', ME.message);
        end
    end

    % Synthetic Indian Topography Reduced-Order Model
    % Based on Western Ghats / Deccan Plateau topographical gradient
    dist_ratio = linspace(0, 1, numPts)';
    % Sigmoidal elevation change mimicking coastal plain to plateau climb
    elevation_m = 15 + 580 ./ (1 + exp(-12 * (dist_ratio - 0.5)));
end

function elev = queryGoogleElevation(lat, lon, apiKey)
    elev = [];
    numPts = numel(lat);
    % Sample up to 100 points to stay within query limits
    sampleIdx = round(linspace(1, numPts, min(100, numPts)));
    pathStr = sprintf('%.5f,%.5f|', [lat(sampleIdx), lon(sampleIdx)]');
    pathStr(end) = ''; % remove trailing pipe

    url = sprintf('https://maps.googleapis.com/maps/api/elevation/json?path=%s&samples=%d&key=%s', ...
        pathStr, numPts, apiKey);
    resp = webread(url, weboptions('Timeout', 10));

    if strcmp(resp.status, 'OK')
        elev = [resp.results.elevation]';
    end
end
