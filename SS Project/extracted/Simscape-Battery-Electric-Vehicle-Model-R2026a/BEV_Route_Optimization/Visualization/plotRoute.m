function h = plotRoute(ax, processedRoute)
% PLOTROUTE Plots 2D geographic route trajectory with waypoints and charging stations
%
% Usage:
%   plotRoute([], processedRoute)   % Opens in current/new figure
%   plotRoute(app.UIAxes, processedRoute) % Renders inside App Designer tab

    if nargin < 1 || isempty(ax)
        fig = figure('Name', 'Route Map Profile', 'Color', 'w');
        ax = axes(fig);
    end

    cla(ax);
    hold(ax, 'on');

    lon = processedRoute.Longitude;
    lat = processedRoute.Latitude;

    % Route trajectory line
    plot(ax, lon, lat, 'b-', 'LineWidth', 2.5, 'DisplayName', 'Route Path');

    % Origin marker
    plot(ax, lon(1), lat(1), 'go', 'MarkerSize', 10, 'MarkerFaceColor', 'g', 'DisplayName', 'Origin');

    % Destination marker
    plot(ax, lon(end), lat(end), 'rs', 'MarkerSize', 10, 'MarkerFaceColor', 'r', 'DisplayName', 'Destination');

    % Charging stations
    if isfield(processedRoute, 'ChargingStations') && ~isempty(processedRoute.ChargingStations)
        st = processedRoute.ChargingStations;
        for i = 1:numel(st)
            % Interpolate station coordinates
            st_lon = interp1(processedRoute.Distance_km, lon, st(i).Distance_km, 'linear', 'extrap');
            st_lat = interp1(processedRoute.Distance_km, lat, st(i).Distance_km, 'linear', 'extrap');
            plot(ax, st_lon, st_lat, 'd', 'MarkerSize', 8, 'MarkerFaceColor', [1 0.5 0], ...
                'MarkerEdgeColor', 'k', 'DisplayName', sprintf('Charger: %s', st(i).Name));
        end
    end

    title(ax, sprintf('Route: %s', processedRoute.RouteName), 'FontWeight', 'bold');
    xlabel(ax, 'Longitude (deg E)');
    ylabel(ax, 'Latitude (deg N)');
    grid(ax, 'on');
    legend(ax, 'Location', 'best');
    hold(ax, 'off');

    h = ax;
end
