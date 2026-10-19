function [T_max_motoring, T_max_regen] = motorTorqueLimit(omega_rpm, vehicle)
% MOTORTORQUELIMIT Calculates speed-dependent peak motor torque envelope
%
% Defines two distinct operating regimes:
%   1. Constant Torque Region: omega <= omega_base
%      T_max = T_peak
%   2. Constant Power / Field Weakening Region: omega > omega_base
%      T_max = P_peak / omega
%
% Inputs:
%   omega_rpm      - Motor rotational speed in RPM
%   vehicle        - Vehicle parameter structure

    omega_rads = abs(omega_rpm) * (2 * pi / 60);

    P_peak_W = vehicle.MotorPeakPower_kW * 1000;
    T_peak_Nm = vehicle.MotorPeakTorque_Nm;

    % Motoring torque envelope
    if omega_rads < 1.0
        T_max_motoring = T_peak_Nm;
    else
        T_pwr_limit = P_peak_W / omega_rads;
        T_max_motoring = min(T_peak_Nm, T_pwr_limit);
    end

    % Regenerative braking torque envelope
    P_regen_max_W = vehicle.MaxRegenPower_kW * 1000;
    if omega_rads < 1.0
        T_max_regen = -T_peak_Nm;
    else
        T_pwr_regen_limit = -P_regen_max_W / omega_rads;
        T_max_regen = max(-T_peak_Nm, T_pwr_regen_limit);
    end
end
