function results = testEnergyCalculation()
% TESTENERGYCALCULATION Unit test for energy conservation, sign conventions, and accounting

    fprintf('Running testEnergyCalculation...\n');
    routes = generateOfflineCorridors(false);
    pRoute = processRoute(routes.Mumbai_Pune_Expressway);
    veh = vehicleDatabase('get', 'TATA_NEXON_EV_LR');
    dCycle = generateDrivingCycle(pRoute, veh, 'NORMAL');

    simRes = runBEVSimulation(veh, dCycle, 90.0, 'Analytical');

    % Test 1: Net energy = Gross - Regen
    eNet = simRes.Energy.NetEnergy_kWh;
    eGross = simRes.Energy.GrossDischarge_kWh;
    eRegen = simRes.Energy.RegenRecovered_kWh;
    assert(abs(eNet - (eGross - eRegen)) < 1e-4, 'Net energy must strictly equal Gross minus Regen.');

    % Test 2: Final SOC consistency
    assert(simRes.SOC.FinalSOC_pct < simRes.SOC.InitialSOC_pct, 'Final SOC must be less than Initial SOC for long trip.');
    assert(simRes.SOC.FinalSOC_pct > 0, 'Final SOC must remain non-negative.');

    % Test 3: kWh/100km plausibility (typical passenger BEV: 11 - 25 kWh/100km)
    kwh100 = simRes.Energy.kWh_per_100km;
    assert(kwh100 >= 10 && kwh100 <= 30, sprintf('Efficiency %.1f kWh/100km outside realistic range.', kwh100));

    % Test 4: Cost calculation
    cost = simRes.Cost.TripCost_INR;
    assert(cost > 50 && cost < 1500, sprintf('Trip cost %.1f INR outside expected bounds.', cost));

    fprintf('✓ testEnergyCalculation passed all checks.\n');
    results = true;
end
