function results = testRouteProcessing()
% TESTROUTEPROCESSING Unit test for route segmentation, elevation smoothing, and grade computation

    fprintf('Running testRouteProcessing...\n');
    routes = generateOfflineCorridors(false);
    pRoute = processRoute(routes.Mumbai_Pune_Expressway, 200, 7);

    % Test 1: Segments table existence and length
    assert(istable(pRoute.SegmentsTable), 'SegmentsTable must be a valid MATLAB Table.');
    assert(height(pRoute.SegmentsTable) > 500, 'SegmentsTable must have fine spatial resolution.');

    % Test 2: Monotonic distance progression
    assert(all(diff(pRoute.Distance_km) > 0), 'Processed distance must be strictly monotonic.');

    % Test 3: Grade limits within highway civil engineering bounds
    assert(all(pRoute.Grade_pct >= -15.0 & pRoute.Grade_pct <= 15.0), ...
        'Grade must be bounded within [-15%, +15%].');

    % Test 4: Elevation gain and loss
    assert(pRoute.ElevationGain_m > 400, 'Expressway route must register significant elevation gain over Khandala Ghat.');

    fprintf('✓ testRouteProcessing passed all checks.\n');
    results = true;
end
