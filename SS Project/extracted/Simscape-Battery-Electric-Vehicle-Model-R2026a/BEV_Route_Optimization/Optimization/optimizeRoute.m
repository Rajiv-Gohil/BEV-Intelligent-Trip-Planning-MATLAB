function optResults = optimizeRoute(candidateRoutes, vehicle, drivingMode, initialSOC_pct, weights, objectivePreset)
% OPTIMIZEROUTE Evaluates and optimizes route selection using weighted multi-objective criteria
%
% Cost Function:
%   J = w_E * (E / E_base) + w_T * (T / T_base) + w_C * (C / C_base) + w_SOC * (1 - FinalSOC)
%
% Inputs:
%   candidateRoutes - Cell array of candidate route structures
%   vehicle         - Vehicle parameters struct
%   drivingMode     - 'ECO', 'NORMAL', or 'PERFORMANCE' (default: 'NORMAL')
%   initialSOC_pct  - Initial battery SOC in % (default: 90%)
%   weights         - Struct with fields w_Energy, w_Time, w_Cost, w_SOC (or empty for preset)
%   objectivePreset - 'Balanced', 'MinEnergy', 'MinTime', 'MinCost', 'MaxSOC'

    if nargin < 3 || isempty(drivingMode)
        drivingMode = 'NORMAL';
    end
    if nargin < 4 || isempty(initialSOC_pct)
        initialSOC_pct = 90.0;
    end
    if nargin < 6 || isempty(objectivePreset)
        objectivePreset = 'Balanced';
    end

    % Set weights based on preset if not explicitly provided
    if nargin < 5 || isempty(weights) || ~isstruct(weights)
        switch lower(string(objectivePreset))
            case 'minenergy'
                weights = struct('w_Energy', 0.65, 'w_Time', 0.15, 'w_Cost', 0.10, 'w_SOC', 0.10);
            case 'mintime'
                weights = struct('w_Energy', 0.10, 'w_Time', 0.70, 'w_Cost', 0.10, 'w_SOC', 0.10);
            case 'mincost'
                weights = struct('w_Energy', 0.20, 'w_Time', 0.10, 'w_Cost', 0.60, 'w_SOC', 0.10);
            case 'maxsoc'
                weights = struct('w_Energy', 0.20, 'w_Time', 0.10, 'w_Cost', 0.10, 'w_SOC', 0.60);
            otherwise % 'Balanced'
                weights = struct('w_Energy', 0.35, 'w_Time', 0.25, 'w_Cost', 0.20, 'w_SOC', 0.20);
        end
    end

    % Normalize weights so they sum to 1.0
    wSum = weights.w_Energy + weights.w_Time + weights.w_Cost + weights.w_SOC;
    w_E = weights.w_Energy / wSum;
    w_T = weights.w_Time / wSum;
    w_C = weights.w_Cost / wSum;
    w_S = weights.w_SOC / wSum;

    numRoutes = numel(candidateRoutes);
    simOutputs = cell(numRoutes, 1);

    routeNames = strings(numRoutes, 1);
    distances_km = zeros(numRoutes, 1);
    times_min = zeros(numRoutes, 1);
    energies_kWh = zeros(numRoutes, 1);
    efficiencies_kWh100 = zeros(numRoutes, 1);
    costs_INR = zeros(numRoutes, 1);
    finalSOCs_pct = zeros(numRoutes, 1);
    regenRecoveries_kWh = zeros(numRoutes, 1);
    elevGains_m = zeros(numRoutes, 1);

    % Simulate all candidate routes
    for i = 1:numRoutes
        pRoute = processRoute(candidateRoutes{i});
        dCycle = generateDrivingCycle(pRoute, vehicle, drivingMode);
        res = runBEVSimulation(vehicle, dCycle, initialSOC_pct, 'Analytical');

        simOutputs{i} = res;
        routeNames(i) = string(pRoute.RouteName);
        distances_km(i) = res.Summary.TotalDistance_km;
        times_min(i) = res.Summary.TotalDuration_min;
        energies_kWh(i) = res.Energy.NetEnergy_kWh;
        efficiencies_kWh100(i) = res.Energy.kWh_per_100km;
        costs_INR(i) = res.Cost.TripCost_INR;
        finalSOCs_pct(i) = res.SOC.FinalSOC_pct;
        regenRecoveries_kWh(i) = res.Energy.RegenRecovered_kWh;
        elevGains_m(i) = pRoute.ElevationGain_m;
    end

    % Normalization baselines (min of each metric across candidates)
    E_base = max(1.0, min(energies_kWh));
    T_base = max(1.0, min(times_min));
    C_base = max(1.0, min(costs_INR));

    % Compute cost metric J for each route
    J_scores = zeros(numRoutes, 1);
    for i = 1:numRoutes
        J_scores(i) = w_E * (energies_kWh(i) / E_base) + ...
                      w_T * (times_min(i) / T_base) + ...
                      w_C * (costs_INR(i) / C_base) + ...
                      w_S * (1 - (finalSOCs_pct(i) / 100));
    end

    % Rank routes
    [sortedScores, rankIdx] = sort(J_scores, 'ascend');
    optimalRouteIndex = rankIdx(1);

    % Create comparison table
    comparisonTable = table(...
        routeNames(rankIdx), rankIdx, sortedScores, distances_km(rankIdx), ...
        times_min(rankIdx), energies_kWh(rankIdx), efficiencies_kWh100(rankIdx), ...
        costs_INR(rankIdx), finalSOCs_pct(rankIdx), elevGains_m(rankIdx), ...
        'VariableNames', {'Route', 'OriginalIndex', 'CostScore_J', 'Distance_km', ...
                          'Duration_min', 'NetEnergy_kWh', 'kWh_per_100km', ...
                          'Cost_INR', 'FinalSOC_pct', 'ElevationGain_m'});

    % Compile optimization result
    optResults = struct();
    optResults.OptimalRouteIndex = optimalRouteIndex;
    optResults.OptimalRouteName = routeNames(optimalRouteIndex);
    optResults.OptimalSimulation = simOutputs{optimalRouteIndex};
    optResults.ObjectivePreset = objectivePreset;
    optResults.WeightsUsed = struct('w_Energy', w_E, 'w_Time', w_T, 'w_Cost', w_C, 'w_SOC', w_S);
    optResults.ComparisonTable = comparisonTable;
    optResults.AllSimulations = simOutputs;
end
