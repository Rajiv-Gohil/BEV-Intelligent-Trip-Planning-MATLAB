function app = run_app()
% RUN_APP Direct launcher for the EV Route Optimization Platform
%
% Usage:
%   run_app
%   app = run_app;

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
