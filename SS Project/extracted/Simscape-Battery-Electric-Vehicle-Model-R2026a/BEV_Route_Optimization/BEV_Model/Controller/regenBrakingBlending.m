function [T_regen_Nm, F_friction_N, regenFraction] = regenBrakingBlending(F_brake_total_N, v_mps, soc_normalized, vehicle, modeConfig)
% REGENBRAKINGBLENDING Blends motor regenerative braking with mechanical friction brakes
%
% Limits applied:
%   1. Speed taper: Below 5 km/h, regen smoothly tapers to 0 to prevent harsh jerk
%   2. SOC protection taper: Above 90% SOC, regen is throttled to prevent cell overvoltage
%   3. Motor torque and power capability limits
%   4. Mode aggressiveness factor
%
% Inputs:
%   F_brake_total_N - Total desired deceleration retarding force (N, positive magnitude)
%   v_mps           - Vehicle speed (m/s)
%   soc_normalized  - Battery State of Charge [0.0, 1.0]
%   vehicle         - Vehicle parameters struct
%   modeConfig      - Driving mode configuration struct
%
% Outputs:
%   T_regen_Nm      - Commanded motor regenerative torque (N*m, negative or zero)
%   F_friction_N    - Required mechanical friction brake force (N, positive)
%   regenFraction   - Fraction of total braking force captured by regen [0, 1]

    if F_brake_total_N <= 0 || v_mps < 0.1
        T_regen_Nm = 0;
        F_friction_N = 0;
        regenFraction = 0;
        return;
    end

    r_w = vehicle.WheelRadius_m;
    N_g = vehicle.GearRatio;
    eta_dt = vehicle.DrivetrainEfficiency;

    % 1. Low speed cutoff taper (5 km/h = 1.389 m/s)
    f_speed = min(1.0, max(0.0, (v_mps - 0.5) / 1.0));

    % 2. High SOC protection taper
    % Above 90% SOC, linearly ramp down to 0 at 98% SOC
    if soc_normalized >= 0.98
        f_soc = 0.0;
    elseif soc_normalized > 0.90
        f_soc = (0.98 - soc_normalized) / (0.98 - 0.90);
    else
        f_soc = 1.0;
    end

    % 3. Mode factor
    f_mode = modeConfig.RegenAggressiveness;

    % Net derating factor
    derating = f_speed * f_soc * f_mode;

    % 4. Required negative torque at motor shaft to produce F_brake_total
    % F_brake = (-T_regen * N_g * eta_dt) / r_w
    T_regen_demanded = -(F_brake_total_N * r_w) / (N_g * eta_dt);

    % 5. Motor speed-dependent regen torque envelope
    omega_motor_rpm = (v_mps / r_w) * N_g * (60 / (2 * pi));
    [~, T_max_regen_envelope] = motorTorqueLimit(omega_motor_rpm, vehicle);

    % Apply derating to allowable motor regen torque
    T_regen_allowable = T_max_regen_envelope * derating;

    % Commanded regen torque (clamped to envelope)
    T_regen_Nm = max(T_regen_allowable, T_regen_demanded);

    % Actual tractive force produced by motor regeneration
    F_regen_actual = (-T_regen_Nm * N_g * eta_dt) / r_w;

    % Remaining retarding force handled by mechanical friction brakes
    F_friction_N = max(0, F_brake_total_N - F_regen_actual);

    regenFraction = F_regen_actual / max(1, F_brake_total_N);
end
