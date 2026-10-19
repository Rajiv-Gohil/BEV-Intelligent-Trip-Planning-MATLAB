function [eff, P_elec_W, P_loss_W] = motorEfficiencyMap(torque_Nm, omega_rpm, vehicle)
% MOTOREFFICIENCYMAP Calculates 2D motor and inverter operating efficiency
%
% Models physical loss mechanisms:
%   1. Copper / I^2*R losses: proportional to Torque^2
%   2. Iron / eddy current / hysteresis losses: proportional to Speed
%   3. Friction & windage aerodynamic losses: proportional to Speed^3
%   4. Fixed parasitic inverter electronics losses: constant term
%
% Inputs:
%   torque_Nm  - Motor shaft torque (N*m, positive = motoring, negative = regen)
%   omega_rpm  - Motor angular velocity (RPM)
%   vehicle    - Vehicle specifications struct
%
% Outputs:
%   eff        - Efficiency value in [0.70, 0.97]
%   P_elec_W   - Electrical power exchanged with battery (W, positive = discharge, negative = charge)
%   P_loss_W   - Total thermal dissipation loss (W)

    omega_rads = abs(omega_rpm) * (2 * pi / 60);
    P_mech_W = torque_Nm * omega_rads;

    if abs(P_mech_W) < 1.0
        % Motor is idling or stationary
        eff = vehicle.MotorEfficiency;
        P_loss_W = 20.0; % Idling inverter standby loss
        P_elec_W = P_loss_W;
        return;
    end

    % Loss coefficients calibrated to peak efficiency of PMSM EV traction motors
    % Peak motor efficiency: eta_peak ~ 0.94 - 0.96
    T_norm = abs(torque_Nm) / max(1, vehicle.MotorPeakTorque_Nm);
    w_norm = omega_rpm / max(1, vehicle.MotorMaxSpeed_rpm);

    % Loss model
    P_cu = 0.035 * (vehicle.MotorPeakPower_kW * 1000) * (T_norm^2);
    P_fe = 0.020 * (vehicle.MotorPeakPower_kW * 1000) * w_norm;
    P_windage = 0.010 * (vehicle.MotorPeakPower_kW * 1000) * (w_norm^3);
    P_fixed = 50.0;

    P_loss_W = P_cu + P_fe + P_windage + P_fixed;

    if P_mech_W > 0
        % Motoring mode: Electrical power drawn from battery
        P_elec_W = P_mech_W + P_loss_W;
        eff = max(0.70, min(0.97, P_mech_W / P_elec_W));
    else
        % Generating / Regenerative mode: Electrical power delivered to battery
        P_gen_raw = abs(P_mech_W) - P_loss_W;
        if P_gen_raw > 0
            P_elec_W = -P_gen_raw; % Negative sign represents energy flowing into battery
            eff = max(0.70, min(0.97, P_gen_raw / abs(P_mech_W)));
        else
            % Mechanical braking energy lower than internal losses
            P_elec_W = 0;
            eff = 0.70;
        end
    end
end
