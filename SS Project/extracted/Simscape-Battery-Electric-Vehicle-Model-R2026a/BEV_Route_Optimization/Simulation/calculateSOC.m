function socMetrics = calculateSOC(soc_trajectory_pct, vehicle, kWh_per_100km)
% CALCULATESOC Computes State-of-Charge metrics, remaining energy, and estimated range
%
% Inputs:
%   soc_trajectory_pct - Vector of SOC values throughout trip (%)
%   vehicle            - Vehicle parameter structure
%   kWh_per_100km      - Average energy consumption rate (kWh/100 km)
%
% Outputs:
%   socMetrics         - Struct containing:
%                        - InitialSOC_pct
%                        - FinalSOC_pct
%                        - SOCDrop_pct
%                        - RemainingEnergy_kWh
%                        - EstimatedRemainingRange_km
%                        - IsReserveViolated (logical, true if final SOC < 15%)

    initialSOC = soc_trajectory_pct(1);
    finalSOC = soc_trajectory_pct(end);
    socDrop = initialSOC - finalSOC;

    usableCapacity_kWh = vehicle.UsableCapacity_kWh;
    remainingEnergy_kWh = usableCapacity_kWh * (finalSOC / 100);

    % Predict remaining range based on the simulated real-world route efficiency
    if kWh_per_100km > 1.0
        remainingRange_km = (remainingEnergy_kWh / kWh_per_100km) * 100;
    else
        % Fallback to manufacturer claimed range if consumption rate is abnormally small
        remainingRange_km = vehicle.ClaimedRange_km * (finalSOC / 100);
    end

    % Check reserve safety threshold (15% reserve buffer)
    reserveThreshold_pct = 15.0;
    isReserveViolated = (finalSOC < reserveThreshold_pct);

    socMetrics = struct();
    socMetrics.InitialSOC_pct = initialSOC;
    socMetrics.FinalSOC_pct = finalSOC;
    socMetrics.SOCDrop_pct = socDrop;
    socMetrics.RemainingEnergy_kWh = max(0, remainingEnergy_kWh);
    socMetrics.EstimatedRemainingRange_km = max(0, remainingRange_km);
    socMetrics.ReserveThreshold_pct = reserveThreshold_pct;
    socMetrics.IsReserveViolated = isReserveViolated;
end
