function costMetrics = calculateCost(netEnergy_kWh, distance_km, vehicle, electricityTariff_INR_per_kWh)
% CALCULATECOST Computes grid energy charging requirements and total trip cost in INR
%
% Equations:
%   Grid Energy (kWh) = Net Battery Energy / Charging Efficiency
%   Trip Cost (INR)   = Grid Energy * Tariff (INR/kWh)
%   Cost per km (INR) = Trip Cost / Trip Distance
%
% Inputs:
%   netEnergy_kWh                 - Net battery energy consumed during trip
%   distance_km                   - Total distance traveled (km)
%   vehicle                       - Vehicle parameter structure
%   electricityTariff_INR_per_kWh - Cost of electricity (default: 8.50 INR/kWh home, 21.00 commercial DC)

    if nargin < 4 || isempty(electricityTariff_INR_per_kWh)
        electricityTariff_INR_per_kWh = 8.50; % Standard Indian residential EV tariff rate
    end

    eta_charge = vehicle.ChargingEfficiency;
    gridEnergy_kWh = max(0, netEnergy_kWh) / max(0.5, eta_charge);
    tripCost_INR = gridEnergy_kWh * electricityTariff_INR_per_kWh;
    cost_per_km_INR = tripCost_INR / max(0.1, distance_km);

    % Compare with equivalent petrol vehicle cost (assuming 15 km/l @ 105 INR/l = 7.00 INR/km)
    petrolCostPerKm_INR = 7.00;
    petrolTripCost_INR = distance_km * petrolCostPerKm_INR;
    savings_INR = petrolTripCost_INR - tripCost_INR;

    costMetrics = struct();
    costMetrics.NetBatteryEnergy_kWh = netEnergy_kWh;
    costMetrics.GridEnergy_kWh = gridEnergy_kWh;
    costMetrics.Tariff_INR_per_kWh = electricityTariff_INR_per_kWh;
    costMetrics.TripCost_INR = tripCost_INR;
    costMetrics.CostPerKm_INR = cost_per_km_INR;
    costMetrics.EquivalentPetrolCost_INR = petrolTripCost_INR;
    costMetrics.SavingsVsPetrol_INR = savings_INR;
end
