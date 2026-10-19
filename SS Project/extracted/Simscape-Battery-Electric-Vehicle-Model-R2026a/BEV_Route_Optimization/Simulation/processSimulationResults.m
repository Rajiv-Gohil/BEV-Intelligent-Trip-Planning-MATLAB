function results = processSimulationResults(rawSim, vehicle, drivingCycle, tariff_INR)
% PROCESSSIMULATIONRESULTS Packages raw simulation time-series into engineering metrics and timetables
%
% Inputs:
%   rawSim       - Struct with Time_s, VehicleSpeed_mps, Torque_Nm, BatteryPower_W, etc.
%   vehicle      - Vehicle parameter structure
%   drivingCycle - Driving cycle input structure
%   tariff_INR   - Electricity tariff in INR/kWh (default: 8.50)

    if nargin < 4 || isempty(tariff_INR)
        tariff_INR = 8.50;
    end

    % 1. Extract and align signals
    T = rawSim.Time_s(:);
    v_act_mps = rawSim.VehicleSpeed_mps(:);
    v_ref_mps = drivingCycle.SpeedRef_mps(:);
    if numel(v_ref_mps) ~= numel(T)
        v_ref_mps = interp1(drivingCycle.Time_s, drivingCycle.SpeedRef_mps, T, 'linear', 'extrap');
    end

    totalDist_km = rawSim.Distance_km(end);
    totalDuration_s = T(end);
    totalDuration_min = totalDuration_s / 60;

    % 2. Calculate Powertrain Peaks & Extremes
    peakMotorPower_kW = max(rawSim.MotorPower_W) / 1000;
    peakRegenPower_kW = abs(min(rawSim.MotorPower_W)) / 1000;
    peakMotorTorque_Nm = max(rawSim.Torque_Nm);
    peakRegenTorque_Nm = abs(min(rawSim.Torque_Nm));
    peakBatteryCurrent_A = max(rawSim.BatteryCurrent_A);
    minBatteryVoltage_V = min(rawSim.BatteryVoltage_V);

    % Speed tracking quality: RMS tracking error
    speedError_kmh = (v_ref_mps - v_act_mps) * 3.6;
    rmsSpeedError_kmh = sqrt(mean(speedError_kmh.^2));

    % 3. Energy, SOC, and Cost Metrics
    energyMetrics = calculateEnergy(rawSim, vehicle);
    socMetrics = calculateSOC(rawSim.SOC_pct, vehicle, energyMetrics.kWh_per_100km);
    costMetrics = calculateCost(energyMetrics.NetEnergy_kWh, totalDist_km, vehicle, tariff_INR);

    % 4. Create MATLAB Timetable for standard time-series data analysis
    timeSeconds = seconds(T);
    timeTableSignals = timetable(timeSeconds, ...
        v_ref_mps * 3.6, v_act_mps * 3.6, rawSim.Distance_km, rawSim.Elevation_m, ...
        rawSim.Grade_pct, rawSim.Torque_Nm, rawSim.MotorPower_W / 1000, ...
        rawSim.BatteryPower_W / 1000, rawSim.BatteryVoltage_V, rawSim.BatteryCurrent_A, ...
        rawSim.SOC_pct, rawSim.AuxPower_W, ...
        'VariableNames', {'SpeedRef_kmh', 'SpeedAct_kmh', 'Distance_km', 'Elevation_m', ...
                          'Grade_pct', 'MotorTorque_Nm', 'MotorPower_kW', ...
                          'BatteryPower_kW', 'BatteryVoltage_V', 'BatteryCurrent_A', ...
                          'BatterySOC_pct', 'AuxiliaryPower_W'});

    % 5. Compile Master Results Struct
    results = struct();
    results.Time_s = T;
    results.Distance_km = rawSim.Distance_km;
    results.SpeedRef_kmh = v_ref_mps * 3.6;
    results.SpeedAct_kmh = v_act_mps * 3.6;
    results.Elevation_m = rawSim.Elevation_m;
    results.Grade_pct = rawSim.Grade_pct;
    results.MotorTorque_Nm = rawSim.Torque_Nm;
    results.MotorPower_kW = rawSim.MotorPower_W / 1000;
    results.BatteryPower_kW = rawSim.BatteryPower_W / 1000;
    results.BatteryVoltage_V = rawSim.BatteryVoltage_V;
    results.BatteryCurrent_A = rawSim.BatteryCurrent_A;
    results.SOC_pct = rawSim.SOC_pct;
    results.AuxPower_W = rawSim.AuxPower_W;
    results.MotorLoss_W = rawSim.MotorLoss_W;

    % Summary metrics
    results.Summary = struct();
    results.Summary.TotalDistance_km = totalDist_km;
    results.Summary.TotalDuration_min = totalDuration_min;
    results.Summary.AverageSpeed_kmh = (totalDist_km / (totalDuration_min / 60));
    results.Summary.RmsSpeedTrackingError_kmh = rmsSpeedError_kmh;
    results.Summary.PeakMotorPower_kW = peakMotorPower_kW;
    results.Summary.PeakRegenPower_kW = peakRegenPower_kW;
    results.Summary.PeakMotorTorque_Nm = peakMotorTorque_Nm;
    results.Summary.PeakBatteryCurrent_A = peakBatteryCurrent_A;
    results.Summary.MinBatteryVoltage_V = minBatteryVoltage_V;

    results.Energy = energyMetrics;
    results.SOC = socMetrics;
    results.Cost = costMetrics;
    results.TimeTable = timeTableSignals;
    results.Vehicle = vehicle;
    results.DrivingMode = drivingCycle.DrivingMode;
end
