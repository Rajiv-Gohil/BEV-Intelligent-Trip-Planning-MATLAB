function initBEVPlatform()
% INITBEVPLATFORM Initializes the BEV Route Optimization & Simulation Platform
%
% Tasks:
%   1. Configures the MATLAB Search Path for all project subdirectories
%   2. Generates and verifies vehicle database (.mat)
%   3. Generates offline highway corridors (.mat)
%   4. Displays welcome banner and quick launch instructions

    projRoot = fileparts(mfilename('fullpath'));
    fprintf('\n===================================================================\n');
    fprintf('   BEV ROUTE ENERGY SIMULATION & OPTIMIZATION PLATFORM (MATLAB)   \n');
    fprintf('===================================================================\n');
    fprintf('Configuring environment from: %s\n', projRoot);

    % 1. Add all folders to path
    addpath(genpath(projRoot));
    fprintf('✓ Added project subdirectories to MATLAB Search Path.\n');

    % 2. Check and generate vehicle database .mat
    matDBPath = fullfile(projRoot, 'VehicleDatabase', 'vehicleDatabase.mat');
    if ~isfile(matDBPath)
        fprintf('• Initializing vehicle database MAT file...\n');
        vehicleDatabase('save');
    else
        fprintf('✓ Vehicle database verified.\n');
    end

    % 3. Check and generate offline corridors
    corridorPath = fullfile(projRoot, 'Data', 'OfflineRoutes', 'Mumbai_Pune_Expressway.mat');
    if ~isfile(corridorPath)
        fprintf('• Generating offline Indian highway corridor datasets...\n');
        generateOfflineCorridors(true);
    else
        fprintf('✓ Offline corridor datasets verified.\n');
    end

    fprintf('\nInitialization complete! To launch the user application:\n');
    fprintf('   >> BEV_Route_Optimization\n');
    fprintf('   or open the App Designer file: BEV_Route_Optimization.mlapp\n');
    fprintf('===================================================================\n\n');
end
