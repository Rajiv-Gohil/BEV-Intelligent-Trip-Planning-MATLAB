function routeData = fetchGoogleRouteData(origin, destination, apiKey)
    % FETCHGOOGLEROUTEDATA Acquires real-time route and elevation data from Google Maps API
    % 
    % Inputs:
    %   origin      - String (e.g., 'Kalyan, Maharashtra')
    %   destination - String (e.g., 'Nashik, Maharashtra')
    %   apiKey      - String (Your active Google Maps API Key)
    %
    % Outputs:
    %   routeData   - Struct containing Distance (km), Elevation (m), Grade (%), Lat/Lon, and Time
    
    % URL Encode inputs
    originStr = urlencode(origin);
    destStr = urlencode(destination);
    
    % =====================================================================
    % STEP 1: QUERY GOOGLE DIRECTIONS API
    % =====================================================================
    directionsUrl = sprintf(['https://maps.googleapis.com/maps/api/directions/json?' ...
        'origin=%s&destination=%s&alternatives=true&departure_time=now&key=%s'], ...
        originStr, destStr, apiKey);
    
    try
        dirResponse = webread(directionsUrl);
    catch ME
        error('Failed to connect to Google Directions API. Check your internet connection or API key. Details: %s', ME.message);
    end
    
    % Validate status
    if ~strcmp(dirResponse.status, 'OK')
        if isfield(dirResponse, 'error_message')
            error('Google Directions API Error [%s]: %s', dirResponse.status, dirResponse.error_message);
        else
            error('Google Directions API Error: %s', dirResponse.status);
        end
    end
    
    % Select primary route (Route 1)
    primaryRoute = dirResponse.routes(1);
    leg = primaryRoute.legs(1);
    encodedPolyline = primaryRoute.overview_polyline.points;
    
    totalDist_m = leg.distance.value; 
    
    if isfield(leg, 'duration_in_traffic')
        totalTime_sec = leg.duration_in_traffic.value;
    else
        totalTime_sec = leg.duration.value;
    end
    
    % Parse route alternatives summary for the multi-route comparison engine
    numRoutes = length(dirResponse.routes);
    routeSummary = cell(numRoutes, 4);
    for r = 1:numRoutes
        rLeg = dirResponse.routes(r).legs(1);
        rDist = rLeg.distance.value / 1000;
        rTime_min = round(rLeg.duration.value / 60);
        
        if r == 1
            rName = sprintf('Route %d: %s (Recommended)', r, dirResponse.routes(r).summary);
        else
            rName = sprintf('Route %d: %s', r, dirResponse.routes(r).summary);
        end
        
        routeSummary{r, 1} = rName;
        routeSummary{r, 2} = rDist;
        routeSummary{r, 3} = sprintf('%dh %02dm', floor(rTime_min/60), rem(rTime_min, 60));
        routeSummary{r, 4} = rLeg.duration.value;
    end
    
    % =====================================================================
    % STEP 2: QUERY GOOGLE ELEVATION API
    % =====================================================================
    samples = 200; % Spatial sample resolution along the path
    elevationUrl = sprintf('https://maps.googleapis.com/maps/api/elevation/json?path=enc:%s&samples=%d&key=%s', ...
        urlencode(encodedPolyline), samples, apiKey);
    
    try
        elevResponse = webread(elevationUrl);
    catch ME
        error('Failed to connect to Google Elevation API. Details: %s', ME.message);
    end
    
    if ~strcmp(elevResponse.status, 'OK')
        if isfield(elevResponse, 'error_message')
            error('Google Elevation API Error [%s]: %s', elevResponse.status, elevResponse.error_message);
        else
            error('Google Elevation API Error: %s', elevResponse.status);
        end
    end
    
    % =====================================================================
    % STEP 3: DATA EXTRACTION & TOPOGRAPHIC GRADE COMPUTATION
    % =====================================================================
    lat = zeros(samples, 1);
    lon = zeros(samples, 1);
    elev_m = zeros(samples, 1);
    
    for i = 1:samples
        lat(i) = elevResponse.results(i).location.lat;
        lon(i) = elevResponse.results(i).location.lng;
        elev_m(i) = elevResponse.results(i).elevation;
    end
    
    dist_km = linspace(0, totalDist_m / 1000, samples)';
    
    % Road grade percentage calculation (% = delta_z / delta_x * 100)
    delta_elev = [0; diff(elev_m)];
    delta_dist_m = [1; diff(dist_km) * 1000];
    grade_pct = (delta_elev ./ delta_dist_m) * 100;
    
    % Clamp extreme noisy points to physical civil engineering bounds ([-15%, +15%])
    grade_pct = max(min(grade_pct, 15), -15);
    
    % =====================================================================
    % STEP 4: PACKAGE OUTPUT STRUCT
    % =====================================================================
    routeData = struct();
    routeData.Origin = leg.start_address;
    routeData.Destination = leg.end_address;
    routeData.TotalDistance_km = totalDist_m / 1000;
    routeData.EstimatedTime_sec = totalTime_sec;
    routeData.Distance = dist_km;
    routeData.Elevation = elev_m;
    routeData.Grade = grade_pct;
    routeData.Lat = lat;
    routeData.Lon = lon;
    routeData.AlternativesTable = routeSummary;
    
    disp('✅ Successfully fetched and processed live Google Maps API Route Data!');
end