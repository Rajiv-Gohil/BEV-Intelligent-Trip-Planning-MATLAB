function outData = export_route_to_simulink(app)
% EXPORT_ROUTE_TO_SIMULINK Formats real-time map route into a Simulink Drive Cycle
%
% Usage:
%   data = export_route_to_simulink();        % Runs default Mumbai-Pune route
%   data = export_route_to_simulink(app);     % Uses active route from open app
%
% This generates:
%   1. 'simulink_drive_cycle' (timeseries object in base workspace)
%   2. 'drive_cycle_matrix'   ([time_sec, speed_mps] for Drive Cycle Source block)
%   3. 'route_drive_cycle.mat' (MAT-file ready for Simulink Drive Cycle block)
%   4. Visual summary plots (MATLAB geoplot + Drive Cycle profile)

    % Ensure paths are set
    projDir = fullfile(fileparts(mfilename('fullpath')), 'SS Project', 'extracted', ...
        'Simscape-Battery-Electric-Vehicle-Model-R2026a', 'BEV_Route_Optimization');
    addpath(projDir);

    % If no app provided, instantiate headless and plan default route
    shouldDelete = false;
    if nargin < 1 || isempty(app)
        app = EVRoute_App();
        app.plan('Mumbai, Maharashtra', 'Pune, Maharashtra');
        shouldDelete = true;
    end

    if isempty(app.Trip)
        error('No trip data found. Please plan a route first.');
    end

    % Extract selected route
    sel = app.Sel;
    if isempty(sel) || sel < 1, sel = 1; end
    r = app.Trip{sel};

    % Time and speed profiles
    % r.prof columns: [midKm, v_kmh, inst_kwh100, pow_kw, time_min]
    tSec   = r.prof(:, 5) * 60;              % time in seconds
    vKmh   = r.prof(:, 2);                   % speed in km/h
    vMps   = vKmh / 3.6;                     % speed in m/s (standard Simulink SI unit)

    % Distance and Elevation
    distKm = r.elevProf(:, 1);
    elevM  = r.elevProf(:, 2);

    % Simulink standard Timeseries and Matrix for Drive Cycle Source block
    tsCycle = timeseries(vMps, tSec, 'Name', 'Vehicle_Speed_Ref');
    tsCycle.DataInfo.Units = 'm/s';
    matCycle = [tSec, vMps];

    % Assign to MATLAB base workspace so Simulink blocks can immediately use it
    assignin('base', 'simulink_drive_cycle', tsCycle);
    assignin('base', 'drive_cycle_matrix', matCycle);
    assignin('base', 'drive_cycle_time_sec', tSec);
    assignin('base', 'drive_cycle_speed_mps', vMps);
    assignin('base', 'drive_cycle_speed_kmh', vKmh);

    % Save MAT file for the Simulink Drive Cycle Source block "From MAT-file" option
    matFile = fullfile(fileparts(mfilename('fullpath')), 'route_drive_cycle.mat');
    save(matFile, 'tsCycle', 'matCycle', 'tSec', 'vMps', 'vKmh');

    % Return summary struct
    outData = struct(...
        'timeSec', tSec, ...
        'speedKmh', vKmh, ...
        'speedMps', vMps, ...
        'drive_cycle_matrix', matCycle, ...
        'matCycle', matCycle, ...
        'distKm', r.distKm, ...
        'energyKwh', r.energy, ...
        'driveMin', r.driveMin, ...
        'timeseries', tsCycle, ...
        'matFile', matFile);

    fprintf('=======================================================\n');
    fprintf(' SIMULINK DRIVE CYCLE EXPORT SUCCESSFUL\n');
    fprintf('=======================================================\n');
    fprintf(' Route: %.1f km | Travel Time: %.1f min | Energy: %.1f kWh\n', r.distKm, r.driveMin, r.energy);
    fprintf(' Created variables in Base Workspace:\n');
    fprintf('   - simulink_drive_cycle : timeseries [m/s vs s]\n');
    fprintf('   - drive_cycle_matrix   : [time, speed] matrix (%d points)\n', numel(tSec));
    fprintf(' Saved MAT file for Drive Cycle Source block:\n');
    fprintf('   - %s\n', matFile);
    fprintf('=======================================================\n');

    % Create visual verification plot
    fig = figure('Name', 'Real-Time Route & Simulink Drive Cycle', ...
                 'Color', 'w', 'Position', [100 100 1100 650]);
    
    % Subplot 1: Geographic route
    subplot(2, 2, 1);
    try
        geoplot(r.path(:,1), r.path(:,2), 'b-', 'LineWidth', 2.5);
        geobasemap('topographic');
        title('1. Geographic Route (Mapping / Geoplot)', 'FontWeight', 'bold');
    catch
        plot(r.path(:,2), r.path(:,1), 'b-', 'LineWidth', 2);
        grid on; xlabel('Longitude'); ylabel('Latitude');
        title('1. Geographic Route Polyline', 'FontWeight', 'bold');
    end

    % Subplot 2: Simulink Drive Cycle (Speed vs Time)
    subplot(2, 2, 2);
    plot(tSec, vKmh, 'Color', [0.12 0.37 0.95], 'LineWidth', 1.8);
    grid on; xlabel('Time [s]'); ylabel('Target Speed [km/h]');
    title('2. Drive Cycle for Simulink Drive Cycle Source Block', 'FontWeight', 'bold');

    % Subplot 3: Elevation Profile
    subplot(2, 2, 3);
    area(distKm, elevM, 'FaceColor', [0.85 0.92 0.90], 'EdgeColor', [0.05 0.62 0.49], 'LineWidth', 1.5);
    grid on; xlabel('Distance [km]'); ylabel('Elevation [m]');
    title('3. Route Elevation Profile (Google Maps API)', 'FontWeight', 'bold');

    % Subplot 4: Battery SOC Depletion
    subplot(2, 2, 4);
    if isfield(r, 'curve') && ~isempty(r.curve)
        plot(r.curve(:,1), r.curve(:,2), 'r-', 'LineWidth', 2);
        ylim([0 100]);
        grid on; xlabel('Distance [km]'); ylabel('State of Charge (SOC) [%]');
        title('4. Predicted Battery SOC Depletion & Charging Stops', 'FontWeight', 'bold');
    end

    if shouldDelete
        delete(app);
    end
end
