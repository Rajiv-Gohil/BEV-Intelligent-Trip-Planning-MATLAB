function h = plotElevation(ax, processedRoute)
% PLOTELEVATION Plots elevation and road grade profile against distance
%
% Usage:
%   plotElevation([], processedRoute)
%   plotElevation(app.UIAxes, processedRoute)

    if nargin < 1 || isempty(ax)
        fig = figure('Name', 'Elevation & Grade Profile', 'Color', 'w');
        ax = axes(fig);
    end

    cla(ax);
    hold(ax, 'on');

    d = processedRoute.Distance_km;
    elev = processedRoute.Elevation_m;

    % Area fill under elevation curve for aesthetic engineering visualization
    fill(ax, [d; flipud(d)], [elev; zeros(size(elev))], [0.85 0.92 1.0], ...
        'EdgeColor', 'none', 'DisplayName', 'Terrain');
    plot(ax, d, elev, 'Color', [0 0.447 0.741], 'LineWidth', 2.0, 'DisplayName', 'Elevation (m)');

    title(ax, sprintf('Elevation Profile (Gain: +%.0f m, Loss: -%.0f m)', ...
        processedRoute.ElevationGain_m, processedRoute.ElevationLoss_m), 'FontWeight', 'bold');
    xlabel(ax, 'Distance (km)');
    ylabel(ax, 'Elevation (m)');
    grid(ax, 'on');
    legend(ax, 'Location', 'best');
    hold(ax, 'off');

    h = ax;
end
