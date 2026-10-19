function results = testVehicleModel()
% TESTVEHICLEMODEL Unit test for vehicle resistance forces and longitudinal dynamics

    fprintf('Running testVehicleModel...\n');
    db = vehicleDatabase();
    veh = db.List(1); % MG Windsor EV

    % Test 1: Zero speed gives zero aero drag
    [F_tot_0, F_roll_0, F_aero_0, F_grade_0] = resistanceForces(0, 0, veh);
    assert(F_aero_0 == 0, 'Aerodynamic drag at v=0 must be zero.');
    assert(F_grade_0 == 0, 'Grade resistance at theta=0 must be zero.');
    assert(F_roll_0 >= 0, 'Rolling resistance must be non-negative.');

    % Test 2: Highway speed aerodynamic drag scale with v^2
    [~, ~, F_aero_10, ~] = resistanceForces(10, 0, veh);
    [~, ~, F_aero_20, ~] = resistanceForces(20, 0, veh);
    ratio = F_aero_20 / F_aero_10;
    assert(abs(ratio - 4.0) < 0.05, 'Aerodynamic drag must scale quadratically with speed.');

    % Test 3: Uphill grade force vs Downhill grade force
    [~, ~, ~, F_grade_up] = resistanceForces(15, deg2rad(5), veh);
    [~, ~, ~, F_grade_down] = resistanceForces(15, deg2rad(-5), veh);
    assert(F_grade_up > 0, 'Uphill grade force must be positive.');
    assert(F_grade_down < 0, 'Downhill grade force must be negative.');
    assert(abs(F_grade_up + F_grade_down) < 1e-5, 'Grade forces must be symmetric.');

    % Test 4: Acceleration dynamics
    [v_next, a_act, ~] = longitudinalDynamics(0, 3000, 200, 0, veh, 0.1, 0);
    assert(v_next > 0, 'Positive net propulsion force must accelerate vehicle forward.');
    assert(a_act > 0, 'Acceleration must be positive.');

    fprintf('✓ testVehicleModel passed all checks.\n');
    results = true;
end
