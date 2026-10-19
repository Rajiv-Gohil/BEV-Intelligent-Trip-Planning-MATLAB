function Voc = batteryOCV_LUT(soc_normalized, vehicle)
% BATTERYOCV_LUT Computes open-circuit voltage Voc as a function of SOC
%
% Implements a validated Lithium-ion (NMC/LFP) pack OCV curve:
%   - Sharp rise at very low SOC (0% - 10%)
%   - Flat plateau across mid-range (20% - 80%)
%   - Exponential increase approaching full charge (90% - 100%)
%
% Inputs:
%   soc_normalized - State of charge in [0.0, 1.0]
%   vehicle        - Vehicle parameter structure

    soc = max(0.0, min(1.0, soc_normalized));
    V_nom = vehicle.NominalVoltage_V;

    % Normalized open-circuit voltage curve relative to nominal pack voltage
    % Calibrated to standard automotive traction battery chemistry
    soc_pts = [0.00, 0.05, 0.10, 0.20, 0.40, 0.60, 0.80, 0.90, 0.95, 1.00];
    voc_factor = [0.84, 0.92, 0.95, 0.98, 1.00, 1.02, 1.05, 1.09, 1.12, 1.15];

    factor = interp1(soc_pts, voc_factor, soc, 'pchip');
    Voc = V_nom * factor;
end
