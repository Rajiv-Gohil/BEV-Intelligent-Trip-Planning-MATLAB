function modeResults = optimizeDrivingMode(processedRoute, vehicle, initialSOC_pct, tariff_INR)
% OPTIMIZEDRIVINGMODE Compares ECO, NORMAL, and PERFORMANCE modes on a given route
%
% Recommends the optimal driving mode that satisfies arrival safety reserve (>15% SOC)
% while balancing travel time and energy expenditure.
%
% Inputs:
%   processedRoute - Route struct from processRoute
%   vehicle        - Vehicle struct from vehicleDatabase
%   initialSOC_pct - Initial State of Charge in % (default: 90%)
%   tariff_INR     - Electricity tariff (default: 8.50)

    if nargin < 3 || isempty(initialSOC_pct)
        initialSOC_pct = 90.0;
    end
    if nargin < 4 || isempty(tariff_INR)
        tariff_INR = 8.50;
    end

    modes = {'ECO', 'NORMAL', 'PERFORMANCE'};
    nModes = numel(modes);
    sims = cell(nModes, 1);

    modeNames = strings(nModes, 1);
    energies_kWh = zeros(nModes, 1);
    durations_min = zeros(nModes, 1);
    efficiencies_kWh100 = zeros(nModes, 1);
    finalSOCs_pct = zeros(nModes, 1);
    costs_INR = zeros(nModes, 1);
    regenRecovered_kWh = zeros(nModes, 1);

    for m = 1:nModes
        modeName = modes{m};
        dCycle = generateDrivingCycle(processedRoute, vehicle, modeName);
        res = runBEVSimulation(vehicle, dCycle, initialSOC_pct, 'Analytical', tariff_INR);

        sims{m} = res;
        modeNames(m) = modeName;
        energies_kWh(m) = res.Energy.NetEnergy_kWh;
        durations_min(m) = res.Summary.TotalDuration_min;
        efficiencies_kWh100(m) = res.Energy.kWh_per_100km;
        finalSOCs_pct(m) = res.SOC.FinalSOC_pct;
        costs_INR(m) = res.Cost.TripCost_INR;
        regenRecovered_kWh(m) = res.Energy.RegenRecovered_kWh;
    end

    % Check reserve safety threshold (15%)
    reserveSafe = (finalSOCs_pct >= 15.0);

    % Decision Logic for Optimal Mode
    if ~any(reserveSafe)
        recommendedMode = 'ECO';
        recommendationReason = 'Warning: All modes breach the 15% reserve buffer. ECO mode is strongly recommended to minimize discharge rate until a charging stop.';
    elseif reserveSafe(2) && (finalSOCs_pct(2) >= 20.0)
        recommendedMode = 'NORMAL';
        recommendationReason = sprintf('NORMAL mode provides an optimal balance: saves %.1f min over ECO with safe %.1f%% destination SOC.', ...
            durations_min(1) - durations_min(2), finalSOCs_pct(2));
    elseif reserveSafe(1)
        recommendedMode = 'ECO';
        recommendationReason = sprintf('ECO mode is required: preserves %.1f%% final SOC whereas NORMAL leaves only %.1f%%.', ...
            finalSOCs_pct(1), finalSOCs_pct(2));
    else
        recommendedMode = 'NORMAL';
        recommendationReason = 'NORMAL mode selected as standard operating baseline.';
    end

    modeTable = table(...
        modeNames, durations_min, energies_kWh, efficiencies_kWh100, ...
        finalSOCs_pct, costs_INR, regenRecovered_kWh, reserveSafe, ...
        'VariableNames', {'DrivingMode', 'Duration_min', 'NetEnergy_kWh', ...
                          'kWh_per_100km', 'FinalSOC_pct', 'Cost_INR', ...
                          'RegenRecovered_kWh', 'ReserveSafe'});

    modeResults = struct();
    modeResults.RecommendedMode = recommendedMode;
    modeResults.RecommendationReason = recommendationReason;
    modeResults.ModeTable = modeTable;
    modeResults.Simulations = struct('ECO', sims{1}, 'NORMAL', sims{2}, 'PERFORMANCE', sims{3});
end
