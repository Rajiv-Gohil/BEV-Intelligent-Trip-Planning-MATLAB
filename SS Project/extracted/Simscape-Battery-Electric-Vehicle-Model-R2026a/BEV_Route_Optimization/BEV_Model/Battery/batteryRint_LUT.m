function Rint = batteryRint_LUT(soc_normalized, temp_C, vehicle)
% BATTERYRINT_LUT Computes internal equivalent series resistance Rint
%
% Depends on both State of Charge and Battery Operating Temperature:
%   - Resistance spikes sharply at SOC < 15% and SOC > 95%
%   - Resistance increases exponentially at temperatures below 10 C (Arrhenius behavior)
%
% Inputs:
%   soc_normalized - State of charge in [0.0, 1.0]
%   temp_C         - Battery temperature in Celsius (default: 25 C)
%   vehicle        - Vehicle parameter structure

    if nargin < 2 || isempty(temp_C)
        temp_C = 25.0;
    end

    soc = max(0.01, min(0.99, soc_normalized));

    % Base pack internal resistance scaled to pack capacity and nominal voltage
    % Typical pack Rint ~ 0.02 to 0.05 Ohms
    V_nom = vehicle.NominalVoltage_V;
    C_kWh = vehicle.BatteryCapacity_kWh;
    R_base = 0.0008 * (V_nom / C_kWh); % Ohms

    % SOC dependency factor (U-shaped bathtub curve)
    f_soc = 1.0 + 0.5 * (1 - soc)^3 + 0.3 * (soc^4);

    % Temperature dependency factor (Arrhenius exponential relation)
    % Cold temp increases electrolyte viscosity and charge transfer resistance
    if temp_C >= 25
        f_temp = exp(-0.015 * (temp_C - 25));
    else
        f_temp = exp(-0.040 * (temp_C - 25)); % Steeper resistance increase below 25 C
    end

    Rint = R_base * f_soc * f_temp;
    % Physical safety clamp: between 0.015 Ohm and 0.25 Ohm
    Rint = max(0.015, min(0.25, Rint));
end
