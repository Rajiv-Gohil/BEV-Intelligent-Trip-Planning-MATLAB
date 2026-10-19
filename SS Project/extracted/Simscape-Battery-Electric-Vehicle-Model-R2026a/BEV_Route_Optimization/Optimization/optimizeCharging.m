function chargingPlan = optimizeCharging(processedRoute, vehicle, simResults, reserveThreshold_pct, targetChargeSOC_pct)
% OPTIMIZECHARGING Identifies charging needs and plans optimal fast charging stops
%
% Evaluates:
%   1. Whether charging is required (Final SOC < reserveThreshold_pct)
%   2. Reachable candidate charging stations along the route corridor
%   3. Arrival SOC at each station
%   4. Charging duration to target SOC (incorporating battery fast charge acceptance)
%   5. Charging session cost based on station tariff
%   6. Selection of optimal charging station
%
% Inputs:
%   processedRoute       - Route struct from processRoute
%   vehicle              - Vehicle struct from vehicleDatabase
%   simResults           - Simulation results struct from runBEVSimulation
%   reserveThreshold_pct - Safety reserve buffer (default: 15%)
%   targetChargeSOC_pct  - Target charge percentage (default: 80% to avoid taper)

    if nargin < 4 || isempty(reserveThreshold_pct)
        reserveThreshold_pct = 15.0;
    end
    if nargin < 5 || isempty(targetChargeSOC_pct)
        targetChargeSOC_pct = 80.0;
    end

    finalSOC = simResults.SOC.FinalSOC_pct;
    isChargingRequired = (finalSOC < reserveThreshold_pct);

    chargingPlan = struct();
    chargingPlan.IsChargingRequired = isChargingRequired;
    chargingPlan.ReserveThreshold_pct = reserveThreshold_pct;
    chargingPlan.TargetChargeSOC_pct = targetChargeSOC_pct;
    chargingPlan.FinalSOC_WithoutCharging_pct = finalSOC;

    % Check if corridor has charging stations defined
    if ~isfield(processedRoute, 'ChargingStations') || isempty(processedRoute.ChargingStations)
        chargingPlan.Status = 'No charging stations registered on this corridor.';
        chargingPlan.StationTable = table();
        chargingPlan.OptimalStation = [];
        return;
    end

    stations = processedRoute.ChargingStations;
    numStations = numel(stations);

    stNames = strings(numStations, 1);
    stDist = zeros(numStations, 1);
    stPower = zeros(numStations, 1);
    stArrivalSOC = zeros(numStations, 1);
    stChargeTime_min = zeros(numStations, 1);
    stEnergyAdded_kWh = zeros(numStations, 1);
    stCost_INR = zeros(numStations, 1);
    stReachable = false(numStations, 1);

    % Distance and SOC trajectories from simulation
    dist_sim = simResults.Distance_km;
    soc_sim = simResults.SOC_pct;
    usableCap_kWh = vehicle.UsableCapacity_kWh;
    maxVehCharge_kW = vehicle.MaxChargingPower_kW;

    for i = 1:numStations
        st = stations(i);
        stNames(i) = string(st.Name);
        stDist(i) = st.Distance_km;
        stPower(i) = st.Power_kW;

        % Interpolate arrival SOC at station distance
        arrSOC = interp1(dist_sim, soc_sim, st.Distance_km, 'linear', 'extrap');
        stArrivalSOC(i) = arrSOC;

        % Reachable if arrival SOC >= 5%
        if arrSOC >= 5.0
            stReachable(i) = true;

            % Energy required to charge from arrSOC up to targetChargeSOC_pct
            deltaSOC = max(0, targetChargeSOC_pct - arrSOC);
            eAdded = usableCap_kWh * (deltaSOC / 100);
            stEnergyAdded_kWh(i) = eAdded;

            % Effective charging power: bottlenecked by station or vehicle DC charger limit
            effPower_kW = min(st.Power_kW, maxVehCharge_kW);

            % Charging time (minutes) factoring in 90% DC charging efficiency
            % Above 70% SOC, fast charge tapers by 30% average
            taperFactor = 0.85;
            stChargeTime_min(i) = (eAdded / (effPower_kW * 0.90 * taperFactor)) * 60;

            % Cost in INR
            rate = 21.0; % default commercial DC fast rate INR/kWh
            if isfield(st, 'Cost_per_kWh')
                rate = st.Cost_per_kWh;
            end
            stCost_INR(i) = (eAdded / 0.90) * rate;
        else
            stReachable(i) = false;
            stChargeTime_min(i) = NaN;
            stEnergyAdded_kWh(i) = NaN;
            stCost_INR(i) = NaN;
        end
    end

    stTable = table(...
        stNames, stDist, stPower, stArrivalSOC, stReachable, ...
        stEnergyAdded_kWh, stChargeTime_min, stCost_INR, ...
        'VariableNames', {'StationName', 'Distance_km', 'ChargerPower_kW', ...
                          'ArrivalSOC_pct', 'Reachable', 'EnergyAdded_kWh', ...
                          'ChargeTime_min', 'SessionCost_INR'});

    chargingPlan.StationTable = stTable;

    % Optimal Station Selection: Reachable station closest to corridor midpoint with max power
    reachableIdx = find(stReachable);
    if isempty(reachableIdx)
        chargingPlan.Status = 'Warning: Vehicle cannot reach any charging station on route! Higher starting SOC needed.';
        chargingPlan.OptimalStation = [];
    else
        % Score reachable stations: balance arrival SOC (must not be dangerously low) and charger speed
        scores = zeros(size(reachableIdx));
        for k = 1:numel(reachableIdx)
            idx = reachableIdx(k);
            % Prefer arrival SOC between 15% and 30%, and higher charger power
            socPenalty = abs(stArrivalSOC(idx) - 20.0);
            powerBonus = stPower(idx) / 10.0;
            scores(k) = powerBonus - socPenalty * 0.5;
        end
        [~, bestK] = max(scores);
        bestIdx = reachableIdx(bestK);

        optimalStation = struct();
        optimalStation.Name = stNames(bestIdx);
        optimalStation.Distance_km = stDist(bestIdx);
        optimalStation.ChargerPower_kW = stPower(bestIdx);
        optimalStation.ArrivalSOC_pct = stArrivalSOC(bestIdx);
        optimalStation.TargetSOC_pct = targetChargeSOC_pct;
        optimalStation.EnergyAdded_kWh = stEnergyAdded_kWh(bestIdx);
        optimalStation.ChargeTime_min = stChargeTime_min(bestIdx);
        optimalStation.EstimatedCost_INR = stCost_INR(bestIdx);

        chargingPlan.OptimalStation = optimalStation;
        if isChargingRequired
            chargingPlan.Status = sprintf('Charging REQUIRED: Recommended stop at %s (km %.1f). Arrival SOC: %.1f%%. Fast charge %.1f kWh in %.1f min (Cost: ₹%.1f).', ...
                optimalStation.Name, optimalStation.Distance_km, optimalStation.ArrivalSOC_pct, ...
                optimalStation.EnergyAdded_kWh, optimalStation.ChargeTime_min, optimalStation.EstimatedCost_INR);
        else
            chargingPlan.Status = sprintf('Charging OPTIONAL: Trip can complete with safe %.1f%% destination SOC. Optional top-up available at %s.', ...
                finalSOC, optimalStation.Name);
        end
    end
end
