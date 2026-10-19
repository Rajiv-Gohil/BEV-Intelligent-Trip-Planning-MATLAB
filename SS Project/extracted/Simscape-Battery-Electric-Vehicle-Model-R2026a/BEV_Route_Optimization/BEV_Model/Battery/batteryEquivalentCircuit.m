function [V_term, I_batt, soc_next, P_actual_W, P_loss_W] = batteryEquivalentCircuit(P_req_W, soc_curr, dt, vehicle, temp_C)
% BATTERYEQUIVALENTCIRCUIT Solves equivalent circuit model for terminal voltage, current, and SOC
%
% Solves:
%   P_req = V_term * I = (Voc - I * Rint) * I = Voc * I - Rint * I^2
%   => Rint * I^2 - Voc * I + P_req = 0
%   => I = (Voc - sqrt(Voc^2 - 4 * Rint * P_req)) / (2 * Rint)
%
% Sign Convention:
%   P_req > 0 : Discharging (current flows out of battery, I > 0, SOC decreases)
%   P_req < 0 : Charging / Regeneration (current flows into battery, I < 0, SOC increases)
%
% Inputs:
%   P_req_W  - Required electrical power from battery (W)
%   soc_curr - Current State of Charge (normalized, 0.0 to 1.0)
%   dt       - Timestep in seconds
%   vehicle  - Vehicle parameter structure
%   temp_C   - Battery temperature in Celsius (default: 30 C)

    if nargin < 5 || isempty(temp_C)
        temp_C = 30.0;
    end

    % 1. Look up Open-Circuit Voltage and Internal Resistance
    Voc = batteryOCV_LUT(soc_curr, vehicle);
    Rint = batteryRint_LUT(soc_curr, temp_C, vehicle);

    % 2. Theoretical maximum discharge power limit (P_max = Voc^2 / (4 * Rint))
    P_max_theoretical = (Voc^2) / (4 * Rint);
    % Enforce manufacturer pack discharge/charge power limits
    P_discharge_max = min(vehicle.MotorPeakPower_kW * 1.15 * 1000, P_max_theoretical * 0.85);
    P_charge_max = vehicle.MaxRegenPower_kW * 1000;

    % Clamp requested power to safe operating envelope
    P_clamped = max(-P_charge_max, min(P_discharge_max, P_req_W));

    % 3. Discriminant check for quadratic formula
    discriminant = Voc^2 - 4 * Rint * P_clamped;
    if discriminant < 0
        discriminant = 0;
        P_clamped = (Voc^2) / (4 * Rint);
    end

    % 4. Solve for current
    I_batt = (Voc - sqrt(discriminant)) / (2 * Rint);

    % Current safety bounds: Max discharge 3.5C, Max charge 2.0C
    Q_nom_Ah = (vehicle.BatteryCapacity_kWh * 1000) / vehicle.NominalVoltage_V;
    I_max_discharge = 3.5 * Q_nom_Ah;
    I_max_charge = -2.0 * Q_nom_Ah;

    I_batt = max(I_max_charge, min(I_max_discharge, I_batt));

    % 5. Terminal voltage and actual electrical power
    V_term = Voc - I_batt * Rint;
    P_actual_W = V_term * I_batt;
    P_loss_W = (I_batt^2) * Rint;

    % 6. Coulomb Counting for next SOC
    % Q_transferred = I * dt (A*s)
    delta_soc = (I_batt * dt) / (Q_nom_Ah * 3600);
    soc_next = max(0.0, min(1.0, soc_curr - delta_soc));
end
