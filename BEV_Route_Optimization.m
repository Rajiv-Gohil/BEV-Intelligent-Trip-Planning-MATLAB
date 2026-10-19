function app = BEV_Route_Optimization()
% BEV_ROUTE_OPTIMIZATION Main entry point for the BEV Route Optimization Platform
%
% Usage:
%   BEV_Route_Optimization
%   app = BEV_Route_Optimization;

    projDir = fullfile(fileparts(mfilename('fullpath')), 'SS Project', 'extracted', ...
        'Simscape-Battery-Electric-Vehicle-Model-R2026a', 'BEV_Route_Optimization');
    
    if ~isfolder(projDir)
        error('Project directory not found at: %s', projDir);
    end
    
    addpath(projDir);
    cd(projDir);
    initBEVPlatform();
    
    app = EVRoute_App();
end
