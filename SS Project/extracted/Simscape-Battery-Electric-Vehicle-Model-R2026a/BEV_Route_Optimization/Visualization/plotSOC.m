function h = plotSOC(ax, simResults)
% PLOTSOC Plots battery state-of-charge trajectory with safety reserve threshold
%
% Usage:
%   plotSOC([], simResults)
%   plotSOC(app.UIAxes, simResults)

    if nargin < 1 || isempty(ax)
        fig = figure('Name', 'Battery SOC Trajectory', 'Color', 'w');
        ax = axes(fig);
    end

    cla(ax);
    hold(ax, 'on');

    d = simResults.Distance_km;
    soc = simResults.SOC_pct;

    % Plot SOC curve
    plot(ax, d, soc, 'LineWidth', 2.2, 'Color', [0 0.6 0.2], 'DisplayName', 'Battery SOC (%)');

    % Plot 15% safety reserve threshold
    yline(ax, 15.0, 'r--', 'LineWidth', 1.5, 'DisplayName', '15% Safety Reserve');

    % Highlight final destination SOC
    plot(ax, d(end), soc(end), 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r', ...
        'DisplayName', sprintf('Final SOC: %.1f%%', soc(end)));

    title(ax, sprintf('Battery SOC: %.1f%% -> %.1f%% (Drop: %.1f%% | Est. Range: %.0f km)', ...
        soc(1), soc(end), soc(1) - soc(end), simResults.SOC.EstimatedRemainingRange_km), 'FontWeight', 'bold');
    xlabel(ax, 'Distance (km)');
    ylabel(ax, 'Battery SOC (%)');
    ylim(ax, [0, 105]);
    grid(ax, 'on');
    legend(ax, 'Location', 'best');
    hold(ax, 'off');

    h = ax;
end
