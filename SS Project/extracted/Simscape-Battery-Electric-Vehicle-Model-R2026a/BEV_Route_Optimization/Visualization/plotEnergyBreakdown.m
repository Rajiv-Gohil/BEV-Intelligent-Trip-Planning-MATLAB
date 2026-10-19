function h = plotEnergyBreakdown(ax, simResults)
% PLOTENERGYBREAKDOWN Visualizes engineering loss decomposition and regenerative capture
%
% Usage:
%   plotEnergyBreakdown([], simResults)
%   plotEnergyBreakdown(app.UIAxes, simResults)

    if nargin < 1 || isempty(ax)
        fig = figure('Name', 'Energy Loss Breakdown', 'Color', 'w');
        ax = axes(fig);
    end

    cla(ax);

    bk = simResults.Energy.Breakdown;

    categories = {'Aero Drag', 'Rolling Res.', 'Elevation Climb', ...
                  'Kinetic Accel', 'Motor/Inverter', 'Drivetrain Loss', ...
                  'HVAC / Aux', 'Regen Recovered'};

    values = [bk.Aerodynamic_kWh, ...
              bk.RollingResistance_kWh, ...
              bk.Elevation_kWh, ...
              bk.Acceleration_kWh, ...
              bk.MotorInverterLoss_kWh, ...
              bk.DrivetrainLoss_kWh, ...
              bk.AuxiliaryHVAC_kWh, ...
              -bk.RegenRecovered_kWh]; % Negative to indicate recovery credit

    % Color coding: Blue for mechanical resistances, Orange for electrical, Green for regen
    colors = [0.2 0.5 0.8; ...  % Aero
              0.3 0.6 0.7; ...  % Rolling
              0.8 0.4 0.2; ...  % Elevation
              0.9 0.6 0.1; ...  % Accel
              0.7 0.3 0.6; ...  % Motor losses
              0.5 0.5 0.5; ...  % Drivetrain
              0.9 0.3 0.3; ...  % HVAC
              0.1 0.7 0.3];     % Regen recovered

    b = barh(ax, categorical(categories, categories), values, 'FaceColor', 'flat');
    b.CData = colors;

    title(ax, sprintf('Trip Energy Accounting (Net: %.2f kWh | %.1f kWh/100 km)', ...
        simResults.Energy.NetEnergy_kWh, simResults.Energy.kWh_per_100km), 'FontWeight', 'bold');
    xlabel(ax, 'Energy (kWh) [Negative = Recovered into Battery]');
    grid(ax, 'on');

    h = ax;
end
