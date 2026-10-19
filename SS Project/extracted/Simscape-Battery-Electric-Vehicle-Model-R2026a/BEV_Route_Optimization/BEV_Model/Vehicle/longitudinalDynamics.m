function [v_next, a_act, d_next] = longitudinalDynamics(v_curr, F_propulsion, F_resistance, F_frictionBrake, vehicle, dt, d_curr)
% LONGITUDINALDYNAMICS Forward vehicle longitudinal dynamics integration
%
% Incorporates rotational inertia equivalent mass:
%   m_eff = m + (J_wheels + J_motor * N_gear^2) / r_wheel^2
%   dv/dt = (F_propulsion - F_resistance - F_frictionBrake) / m_eff
%
% Inputs:
%   v_curr          - Current vehicle speed (m/s)
%   F_propulsion    - Net drive axle tractive force (N)
%   F_resistance    - Total road resistance force (N)
%   F_frictionBrake - Mechanical braking force (N, always >= 0)
%   vehicle         - Vehicle parameters struct
%   dt              - Integration timestep (seconds)
%   d_curr          - Current distance traveled (m)

    if nargin < 7
        d_curr = 0;
    end

    m = vehicle.VehicleMass_kg;
    r_w = vehicle.WheelRadius_m;
    N_g = vehicle.GearRatio;

    % Estimate rotating inertias (driveline + motor + 4 wheels)
    J_wheels = 4 * (0.5 * 15 * r_w^2);  % 4 wheels ~15 kg each
    J_motor = 0.05;                     % Motor rotor inertia (kg*m^2)
    m_rotational = (J_wheels + J_motor * (N_g^2)) / (r_w^2);
    m_eff = m + m_rotational;

    % Net longitudinal force acting on vehicle body
    F_net = F_propulsion - F_resistance - F_frictionBrake;

    % Prevent negative reverse motion when stationary and braking on flat ground
    if v_curr < 0.01 && F_net < 0 && F_resistance >= 0
        a_act = 0;
        v_next = 0;
    else
        a_act = F_net / m_eff;
        v_next = max(0, v_curr + a_act * dt);
    end

    d_next = d_curr + ((v_curr + v_next) / 2) * dt;
end
