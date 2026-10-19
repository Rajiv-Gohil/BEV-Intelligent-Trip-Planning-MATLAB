function app = BEV_Route_Optimization()
% BEV_ROUTE_OPTIMIZATION Main entry point for the BEV Route Optimization Platform
%
% Usage:
%   BEV_Route_Optimization        % Launches the interactive App Designer application
%   app = BEV_Route_Optimization  % Returns handle to the App Designer object

    % 1. Run platform initialization
    projRoot = fileparts(mfilename('fullpath'));
    addpath(projRoot);
    initBEVPlatform();

    % 2. Launch the interactive Google Maps BEV platform interface
    app = EVRoute_App();
end
