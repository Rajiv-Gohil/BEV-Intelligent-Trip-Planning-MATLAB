function energyMetrics = calculateEnergy(simResults, vehicle)
% CALCULATEENERGY Computes comprehensive energy accounting, loss breakdown, and engineering insights
%
% Calculates:
%   - Net battery energy consumed (kWh)
%   - Gross traction energy (kWh)
%   - Regenerative energy recovered (kWh)
%   - Electrical efficiency (kWh/100 km)
%   - Energy breakdown components:
%       * Aerodynamic drag loss
%       * Rolling resistance loss
%       * Elevation / potential energy change
%       * Kinetic acceleration energy
%       * Motor & Inverter dissipation
%       * Reducer drivetrain loss
%       * Auxiliary & HVAC energy
%   - Qualitative & quantitative "Energy Insights" explainability statements

    T = simResults.Time_s(:);
    v = simResults.VehicleSpeed_mps(:);
    a = simResults.Acceleration_mps2(:);
    theta = simResults.Grade_rad(:);
    P_batt = simResults.BatteryPower_W(:);
    P_regen = simResults.RegenPower_W(:);
    P_aux = simResults.AuxPower_W(:);
    P_motor_loss = simResults.MotorLoss_W(:);

    dt = mean(diff(T));
    totalDist_km = simResults.Distance_km(end);

    % 1. Battery Net, Motoring, and Regen Energy
    % Positive battery power = discharging; Negative = charging
    P_dis = max(0, P_batt);
    P_chg = max(0, -P_batt);

    E_gross_dis_kWh = trapz(T, P_dis) / 3.6e6;
    E_regen_rec_kWh = trapz(T, P_chg) / 3.6e6;
    E_net_kWh = E_gross_dis_kWh - E_regen_rec_kWh;

    % kWh/100 km
    kWh_per_100km = (E_net_kWh / max(totalDist_km, 0.01)) * 100;
    km_per_kWh = max(totalDist_km, 0.01) / max(E_net_kWh, 0.001);

    % 2. Component Mechanical Energy Integrals
    rho = 1.20;
    g = 9.81;
    m = vehicle.VehicleMass_kg;
    Cd = vehicle.DragCoeff_Cd;
    A = vehicle.FrontalArea_m2;
    Crr = vehicle.RollingResistance_Crr;

    % Aerodynamic loss: P_aero = 0.5 * rho * Cd * A * v^3
    P_aero = 0.5 * rho * Cd * A * (v.^3);
    E_aero_kWh = trapz(T, P_aero) / 3.6e6;

    % Rolling resistance loss: P_roll = Crr * m * g * cos(theta) * v
    P_roll = Crr * m * g * cos(theta) .* v;
    E_roll_kWh = trapz(T, P_roll) / 3.6e6;

    % Elevation potential energy change: P_grade = m * g * sin(theta) * v
    P_grade = m * g * sin(theta) .* v;
    E_grade_kWh = trapz(T, P_grade) / 3.6e6;

    % Inertial kinetic acceleration power (motoring phases only)
    P_accel = max(0, m * a .* v);
    E_accel_kWh = trapz(T, P_accel) / 3.6e6;

    % Motor & Inverter electrical losses
    E_motor_loss_kWh = trapz(T, P_motor_loss) / 3.6e6;

    % Drivetrain gearbox mechanical losses (1 - eta_dt)
    eta_dt = vehicle.DrivetrainEfficiency;
    E_drivetrain_loss_kWh = (1 - eta_dt) * (E_aero_kWh + E_roll_kWh + max(0, E_grade_kWh) + E_accel_kWh);

    % Auxiliary & HVAC electrical consumption
    E_aux_kWh = trapz(T, P_aux) / 3.6e6;

    % Total braking kinetic energy available vs captured
    P_braking_avail = max(0, -m * a .* v);
    E_braking_avail_kWh = trapz(T, P_braking_avail) / 3.6e6;
    if E_braking_avail_kWh > 0.01
        regenCaptureRatio_pct = (E_regen_rec_kWh / E_braking_avail_kWh) * 100;
    else
        regenCaptureRatio_pct = 0;
    end

    % 3. Generate Engineering Explainability Insights
    insights = {};
    totalExpenditure = E_aero_kWh + E_roll_kWh + max(0, E_grade_kWh) + E_motor_loss_kWh + E_aux_kWh;

    pct_aero = (E_aero_kWh / totalExpenditure) * 100;
    pct_roll = (E_roll_kWh / totalExpenditure) * 100;
    pct_grade = (max(0, E_grade_kWh) / totalExpenditure) * 100;
    pct_aux = (E_aux_kWh / totalExpenditure) * 100;
    pct_regen = (E_regen_rec_kWh / max(0.01, E_gross_dis_kWh)) * 100;

    insights{end+1} = sprintf('• Total net energy consumed: %.2f kWh over %.1f km (%.1f kWh/100 km, %.2f km/kWh).', ...
        E_net_kWh, totalDist_km, kWh_per_100km, km_per_kWh);

    if pct_grade > 8
        insights{end+1} = sprintf('• Road elevation climb added %.1f%% (%.2f kWh) to total propulsion demand due to hill/ghat ascent.', ...
            pct_grade, max(0, E_grade_kWh));
    else
        insights{end+1} = sprintf('• Route elevation is relatively flat; potential energy accounted for only %.1f%% of total energy.', pct_grade);
    end

    if pct_aero > 35
        insights{end+1} = sprintf('• High-speed highway cruising caused aerodynamic drag to be the dominant consumer (%.1f%% / %.2f kWh).', ...
            pct_aero, E_aero_kWh);
    else
        insights{end+1} = sprintf('• Aerodynamic drag contributed %.1f%% (%.2f kWh), mitigated by moderate urban/suburban speeds.', ...
            pct_aero, E_aero_kWh);
    end

    insights{end+1} = sprintf('• Rolling resistance dissipated %.1f%% (%.2f kWh) through tire deformation.', pct_roll, E_roll_kWh);
    insights{end+1} = sprintf('• Regenerative braking recovered %.2f kWh (%.1f%% of gross discharge energy replenished).', ...
        E_regen_rec_kWh, pct_regen);
    insights{end+1} = sprintf('• Cabin HVAC & auxiliary electrical loads drew %.2f kWh (%.1f%% of total energy).', ...
        E_aux_kWh, pct_aux);

    % Package into struct
    energyMetrics = struct();
    energyMetrics.NetEnergy_kWh = E_net_kWh;
    energyMetrics.GrossDischarge_kWh = E_gross_dis_kWh;
    energyMetrics.RegenRecovered_kWh = E_regen_rec_kWh;
    energyMetrics.kWh_per_100km = kWh_per_100km;
    energyMetrics.km_per_kWh = km_per_kWh;
    energyMetrics.RegenCaptureEfficiency_pct = regenCaptureRatio_pct;

    % Breakdown
    energyMetrics.Breakdown.Aerodynamic_kWh = E_aero_kWh;
    energyMetrics.Breakdown.RollingResistance_kWh = E_roll_kWh;
    energyMetrics.Breakdown.Elevation_kWh = max(0, E_grade_kWh);
    energyMetrics.Breakdown.Acceleration_kWh = E_accel_kWh;
    energyMetrics.Breakdown.MotorInverterLoss_kWh = E_motor_loss_kWh;
    energyMetrics.Breakdown.DrivetrainLoss_kWh = E_drivetrain_loss_kWh;
    energyMetrics.Breakdown.AuxiliaryHVAC_kWh = E_aux_kWh;
    energyMetrics.Breakdown.RegenRecovered_kWh = E_regen_rec_kWh;

    energyMetrics.Insights = insights;
end
