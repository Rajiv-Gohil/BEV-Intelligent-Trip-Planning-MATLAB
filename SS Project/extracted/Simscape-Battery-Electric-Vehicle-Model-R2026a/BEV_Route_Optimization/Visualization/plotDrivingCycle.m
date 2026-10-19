function h = plotDrivingCycle(ax, simResults)
% PLOTDRIVINGCYCLE Plots reference vs actual vehicle speed tracking
%
% Usage:
%   plotDrivingCycle([], simResults)
%   plotDrivingCycle(app.UIAxes, simResults)

    if nargin < 1 || isempty(ax)
        fig = figure('Name', 'Speed Tracking Performance', 'Color', 'w');
        ax = axes(fig);
    end

    cla(ax);
    hold(ax, 'on');

    t_min = simResults.Time_s / 60;

    plot(ax, t_min, simResults.SpeedRef_kmh, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Reference Speed');
    plot(ax, t_min, simResults.SpeedAct_kmh, 'b-', 'LineWidth', 1.8, 'DisplayName', 'Actual Speed');

    title(ax, sprintf('Speed Tracking (%s Mode, RMS Error: %.2f km/h)', ...
        simResults.DrivingMode, simResults.Summary.RmsSpeedTrackingError_kmh), 'FontWeight', 'bold');
    xlabel(ax, 'Time (minutes)');
    ylabel(ax, 'Speed (km/h)');
    grid(ax, 'on');
    legend(ax, 'Location', 'best');
    hold(ax, 'off');

    h = ax;
end
