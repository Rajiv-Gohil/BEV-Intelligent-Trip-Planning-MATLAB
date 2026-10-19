function h = plotPowertrainResults(ax, simResults)
% PLOTPOWERTRAINRESULTS Visualizes motor torque, electrical power, and battery dynamics
%
% Usage:
%   plotPowertrainResults([], simResults)
%   plotPowertrainResults(app.UIAxes, simResults)

    if nargin < 1 || isempty(ax)
        fig = figure('Name', 'Powertrain Electrical & Mechanical Results', 'Color', 'w');
        ax = axes(fig);
    end

    cla(ax);
    hold(ax, 'on');

    t_min = simResults.Time_s / 60;

    % Plot Motor Power and Battery Power on the provided axes
    plot(ax, t_min, simResults.BatteryPower_kW, 'b-', 'LineWidth', 1.6, 'DisplayName', 'Battery Power (kW)');
    plot(ax, t_min, simResults.MotorPower_kW, 'm--', 'LineWidth', 1.4, 'DisplayName', 'Motor Shaft Power (kW)');
    yline(ax, 0, 'k:');

    title(ax, sprintf('Powertrain Power (Peak Motor: %.1f kW | Peak Regen: %.1f kW)', ...
        simResults.Summary.PeakMotorPower_kW, simResults.Summary.PeakRegenPower_kW), 'FontWeight', 'bold');
    xlabel(ax, 'Time (minutes)');
    ylabel(ax, 'Power (kW)');
    grid(ax, 'on');
    legend(ax, 'Location', 'best');
    hold(ax, 'off');

    h = ax;
end
