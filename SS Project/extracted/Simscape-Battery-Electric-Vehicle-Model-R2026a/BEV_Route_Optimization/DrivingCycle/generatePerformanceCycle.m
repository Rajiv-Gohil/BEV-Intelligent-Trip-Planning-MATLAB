function modeConfig = generatePerformanceCycle()
% GENERATEPERFORMANCECYCLE Returns configuration settings for Performance/Sport driving mode
%
% Characteristics:
%   - Sharp, responsive throttle and high acceleration limit
%   - Cruising at highest permissible traffic flow
%   - Dynamic braking with blended high regen
%   - Enhanced cabin cooling / maximum accessory comfort

    modeConfig = struct();
    modeConfig.ModeName = 'PERFORMANCE';
    modeConfig.MaxAcceleration_mps2 = 3.2;     % Brisk, spirited acceleration
    modeConfig.MaxDeceleration_mps2 = 3.5;     % Firm, aggressive braking
    modeConfig.CruisingSpeedFactor = 1.08;     % Upper traffic band
    modeConfig.MaxCruisingSpeed_kmh = 130.0;   % Higher highway cruising
    modeConfig.RegenAggressiveness = 0.70;     % Driver priority on friction-brake feel
    modeConfig.AuxLoadFactor = 1.25;           % Max HVAC comfort and cabin pre-cooling
    modeConfig.ThrottleResponseGain = 1.3;     % Aggressive throttle mapping
end
