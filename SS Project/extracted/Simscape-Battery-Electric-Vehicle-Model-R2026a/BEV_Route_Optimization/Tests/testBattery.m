function results = testBattery()
% TESTBATTERY Unit test for battery OCV-Rint lookup, equivalent circuit, and protection limits

    fprintf('Running testBattery...\n');
    db = vehicleDatabase();
    veh = db.List(2); % Tata Nexon EV LR

    % Test 1: OCV increases monotonically with SOC
    voc_low = batteryOCV_LUT(0.1, veh);
    voc_mid = batteryOCV_LUT(0.5, veh);
    voc_high = batteryOCV_LUT(0.9, veh);
    assert(voc_low < voc_mid && voc_mid < voc_high, 'OCV must increase with increasing SOC.');

    % Test 2: Rint temperature sensitivity
    r_cold = batteryRint_LUT(0.5, 5, veh);
    r_warm = batteryRint_LUT(0.5, 30, veh);
    assert(r_cold > r_warm, 'Internal resistance must be higher at cold temperatures.');

    % Test 3: Discharging voltage drop
    [v_dis, i_dis, soc_next_dis, ~, p_loss_dis] = batteryEquivalentCircuit(30000, 0.8, 1.0, veh, 25);
    assert(v_dis < batteryOCV_LUT(0.8, veh), 'Terminal voltage must drop below Voc during discharge.');
    assert(i_dis > 0, 'Discharge current must be positive.');
    assert(soc_next_dis < 0.8, 'SOC must decrease after discharge.');
    assert(p_loss_dis > 0, 'Internal resistance losses must be positive.');

    % Test 4: Regenerative charging voltage rise
    [v_chg, i_chg, soc_next_chg, ~, ~] = batteryEquivalentCircuit(-20000, 0.5, 1.0, veh, 25);
    assert(v_chg > batteryOCV_LUT(0.5, veh), 'Terminal voltage must rise above Voc during regenerative charge.');
    assert(i_chg < 0, 'Charging current must be negative.');
    assert(soc_next_chg > 0.5, 'SOC must increase after charging.');

    fprintf('✓ testBattery passed all checks.\n');
    results = true;
end
