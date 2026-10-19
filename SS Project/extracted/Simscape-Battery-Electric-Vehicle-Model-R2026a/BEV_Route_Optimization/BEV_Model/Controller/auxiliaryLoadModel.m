function [P_aux_total_W, P_hvac_W, P_base_W, P_batt_mgmt_W] = auxiliaryLoadModel(ambientTemp_C, targetCabinTemp_C, hvacEnabled, vehicle, modeConfig, battTemp_C)
% AUXILIARYLOADMODEL Computes electrical power consumption of vehicle subsystems
%
% Subsystems modeled:
%   1. Base electronics: Infotainment, instrument cluster, lighting, sensors (300 - 600 W)
%   2. HVAC Heat Pump / AC Compressor: Proportional to |T_amb - T_target| with thermal COP
%   3. Battery Thermal Management System (BTMS): Chiller/heater activating if battery leaves 20-35 C
%
% Inputs:
%   ambientTemp_C     - Ambient air temperature (Celsius)
%   targetCabinTemp_C - Driver-desired cabin temperature (Celsius, default: 23 C)
%   hvacEnabled       - Logical flag indicating HVAC state (default: true)
%   vehicle           - Vehicle specs struct
%   modeConfig        - Driving mode configuration struct
%   battTemp_C        - Battery pack temperature (Celsius, default: 28 C)

    if nargin < 2 || isempty(targetCabinTemp_C)
        targetCabinTemp_C = 23.0;
    end
    if nargin < 3 || isempty(hvacEnabled)
        hvacEnabled = true;
    end
    if nargin < 5 || isempty(modeConfig)
        modeConfig = struct('AuxLoadFactor', 1.0);
    end
    if nargin < 6 || isempty(battTemp_C)
        battTemp_C = 28.0;
    end

    % 1. Base electrical load
    P_base_W = vehicle.AuxBaseLoad_W;

    % 2. HVAC Compressor and blower load
    if hvacEnabled
        deltaT = abs(ambientTemp_C - targetCabinTemp_C);
        % Thermal load approx 200W of heat/cooling required per deg C delta
        % Coefficient of Performance (COP): ~2.8 for AC cooling, ~2.2 for heating
        if ambientTemp_C >= targetCabinTemp_C
            cop = 2.8; % Cooling
        else
            cop = 2.2; % Heating
        end
        P_thermal_req = deltaT * 220.0; % Watts thermal
        P_blower = 80.0;                % Cabin blower fan
        P_hvac_W = (P_thermal_req / cop + P_blower) * modeConfig.AuxLoadFactor;
        % Clamp HVAC compressor between 100W and 3500W
        P_hvac_W = max(100, min(3500, P_hvac_W));
    else
        P_hvac_W = 60.0; % Passive ventilation fan only
    end

    % 3. Battery Thermal Management System (Active Chilling/Warming)
    if battTemp_C > 38.0
        % Active cooling chiller required
        P_batt_mgmt_W = 800.0 * min(2.0, (battTemp_C - 38.0) / 5.0);
    elseif battTemp_C < 15.0
        % PTC battery heater required
        P_batt_mgmt_W = 1200.0 * min(2.0, (15.0 - battTemp_C) / 10.0);
    else
        P_batt_mgmt_W = 40.0; % Passive coolant circulation pump
    end

    P_aux_total_W = P_base_W + P_hvac_W + P_batt_mgmt_W;
end
