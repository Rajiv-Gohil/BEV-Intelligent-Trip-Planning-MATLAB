function modeConfig = generateEcoCycle()
% GENERATEECOCYCLE Returns configuration settings for Eco driving mode
%
% Characteristics:
%   - Low, smooth acceleration limit (comfort and efficiency focused)
%   - Conservative highway cruising speed limit
%   - Maximized regenerative braking bias
%   - Energy-saving HVAC and auxiliary load setting

    modeConfig = struct();
    modeConfig.ModeName = 'ECO';
    modeConfig.MaxAcceleration_mps2 = 1.1;     % Smooth, energy-efficient acceleration
    modeConfig.MaxDeceleration_mps2 = 1.5;     % Moderate deceleration for maximum regen capture
    modeConfig.CruisingSpeedFactor = 0.88;     % Cruise at 88% of speed limit
    modeConfig.MaxCruisingSpeed_kmh = 90.0;    % Capped at 90 km/h to drastically cut aerodynamic drag
    modeConfig.RegenAggressiveness = 1.0;      % 100% regen capture priority
    modeConfig.AuxLoadFactor = 0.75;           % Eco HVAC mode (25% reduction in auxiliary power)
    modeConfig.ThrottleResponseGain = 0.8;     % Gentler throttle response
end
