function results = testDrivingCycle()
% TESTDRIVINGCYCLE Unit test for driving cycle generation across ECO, NORMAL, and PERFORMANCE modes

    fprintf('Running testDrivingCycle...\n');
    routes = generateOfflineCorridors(false);
    pRoute = processRoute(routes.Mumbai_Urban_CoastalRoad);
    veh = vehicleDatabase('get', 'TATA_PUNCH_EV');

    % Test 1: Cycle generation for all 3 modes
    dEco = generateDrivingCycle(pRoute, veh, 'ECO');
    dNorm = generateDrivingCycle(pRoute, veh, 'NORMAL');
    dPerf = generateDrivingCycle(pRoute, veh, 'PERFORMANCE');

    assert(dEco.TotalDuration_s > dNorm.TotalDuration_s, 'Eco cycle duration must be longer than Normal.');
    assert(dNorm.TotalDuration_s >= dPerf.TotalDuration_s, 'Normal cycle duration must be >= Performance.');

    % Test 2: Mode speed cap enforcement
    assert(max(dEco.SpeedRef_kmh) <= dEco.ModeConfig.MaxCruisingSpeed_kmh + 1.0, ...
        'Eco speed must not exceed mode max cruising speed.');

    % Test 3: Stop events incorporate zero-speed dwell
    assert(any(dEco.SpeedRef_kmh == 0), 'Driving cycle must include stop dwell events.');

    % Test 4: Auxiliary load in Eco is less than Performance
    assert(mean(dEco.AuxLoad_W) < mean(dPerf.AuxLoad_W), 'Eco HVAC/auxiliary load must be lower than Performance.');

    fprintf('✓ testDrivingCycle passed all checks.\n');
    results = true;
end
