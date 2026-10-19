function modeConfig = generateNormalCycle()
% GENERATENORMALCYCLE Returns configuration settings for Normal driving mode
%
% Characteristics:
%   - Balanced acceleration and deceleration
%   - Standard cruising speeds following legal speed limits and traffic flow
%   - Standard regenerative braking blending
%   - Nominal HVAC and auxiliary comfort

    modeConfig = struct();
    modeConfig.ModeName = 'NORMAL';
    modeConfig.MaxAcceleration_mps2 = 1.9;     % Balanced real-world acceleration
    modeConfig.MaxDeceleration_mps2 = 2.4;     % Standard service braking
    modeConfig.CruisingSpeedFactor = 1.00;     % Follow traffic speed up to speed limit
    modeConfig.MaxCruisingSpeed_kmh = 110.0;   % Standard Indian highway ceiling
    modeConfig.RegenAggressiveness = 0.85;     % Balanced regen
    modeConfig.AuxLoadFactor = 1.00;           % Standard nominal HVAC
    modeConfig.ThrottleResponseGain = 1.0;     % Linear throttle response
end
