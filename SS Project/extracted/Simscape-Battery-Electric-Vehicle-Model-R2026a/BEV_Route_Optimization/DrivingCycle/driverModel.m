function [torqueDemand_Nm, frictionBrake_N, driverState] = driverModel(vRef_mps, vAct_mps, grade_rad, vehicle, modeConfig, dt, prevState)
% DRIVERMODEL Closed-loop longitudinal driver controller with grade feedforward
%
% Inputs:
%   vRef_mps        - Target vehicle speed (m/s)
%   vAct_mps        - Current vehicle speed (m/s)
%   grade_rad       - Current road slope (radians)
%   vehicle         - Vehicle parameters struct from vehicleDatabase
%   modeConfig      - Mode configuration struct (Eco/Normal/Performance)
%   dt              - Simulation timestep (seconds)
%   prevState       - Struct containing integrator state from previous step
%
% Outputs:
%   torqueDemand_Nm - Commanded motor torque (N*m, positive for motoring, negative for regen)
%   frictionBrake_N - Mechanical friction braking force (N)
%   driverState     - Updated driver state structure

    if nargin < 7 || isempty(prevState)
        prevState = struct('integralError', 0, 'prevAcc', 0);
    end

    % 1. Speed tracking error
    speedError = vRef_mps - vAct_mps;

    % 2. PI controller with anti-windup
    Kp = 1500 * modeConfig.ThrottleResponseGain;
    Ki = 80;

    intErr = prevState.integralError + speedError * dt;
    % Clamp integrator
    intErr = max(-100, min(100, intErr));

    % 3. Grade feedforward force
    g = 9.81;
    F_grade_ff = vehicle.VehicleMass_kg * g * sin(grade_rad);

    % 4. Total desired tractive/braking force
    F_desired = Kp * speedError + Ki * intErr + F_grade_ff;

    % Acceleration limitation based on driving mode
    a_desired = F_desired / vehicle.VehicleMass_kg;
    a_clamped = max(-modeConfig.MaxDeceleration_mps2, min(modeConfig.MaxAcceleration_mps2, a_desired));
    F_cmd = a_clamped * vehicle.VehicleMass_kg;

    % 5. Convert tractive force to motor shaft torque via reducer
    % F = (T_motor * N_gear * eta) / r_wheel  =>  T_motor = F * r_wheel / (N_gear * eta)
    r_wheel = vehicle.WheelRadius_m;
    N_gear = vehicle.GearRatio;
    eta_dt = vehicle.DrivetrainEfficiency;

    % 6. Torque and braking allocation
    if F_cmd >= 0
        % Motoring
        T_req = (F_cmd * r_wheel) / (N_gear * eta_dt);
        % Limit to motor peak torque
        torqueDemand_Nm = min(vehicle.MotorPeakTorque_Nm, T_req);
        frictionBrake_N = 0;
    else
        % Braking: Blend regenerative braking and friction braking
        % Desired negative torque at motor
        T_regen_req = (F_cmd * r_wheel * eta_dt) / N_gear;

        % Max regen torque allowed by motor
        T_regen_max = -vehicle.MotorPeakTorque_Nm * modeConfig.RegenAggressiveness;

        if T_regen_req >= T_regen_max
            % Entire braking demand can be handled by motor regeneration
            torqueDemand_Nm = T_regen_req;
            frictionBrake_N = 0;
        else
            % Motor hits regen limit, excess braking absorbed by friction brakes
            torqueDemand_Nm = T_regen_max;
            F_regen_actual = (torqueDemand_Nm * N_gear / eta_dt) / r_wheel;
            frictionBrake_N = abs(F_cmd - F_regen_actual);
        end
    end

    driverState = struct('integralError', intErr, 'prevAcc', a_clamped);
end
