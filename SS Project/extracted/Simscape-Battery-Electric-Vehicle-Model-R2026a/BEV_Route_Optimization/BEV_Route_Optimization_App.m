classdef BEV_Route_Optimization_App < matlab.apps.AppBase

    % UI Component Properties
    properties (Access = public)
        UIFigure                 matlab.ui.Figure
        MainGrid                 matlab.ui.container.GridLayout
        SidebarPanel             matlab.ui.container.Panel
        SidebarGrid              matlab.ui.container.GridLayout
        LogoLabel                matlab.ui.control.Label
        NavDashBtn               matlab.ui.control.Button
        NavRouteBtn              matlab.ui.control.Button
        NavVehBtn                matlab.ui.control.Button
        NavSimBtn                matlab.ui.control.Button
        NavCompareBtn            matlab.ui.control.Button
        
        ContentCard              matlab.ui.container.Panel
        ContentGrid              matlab.ui.container.GridLayout
        TabGroup                 matlab.ui.container.TabGroup
        
        % Tab 1: Dashboard
        TabDashboard             matlab.ui.container.Tab
        DashGrid                 matlab.ui.container.GridLayout
        KPICard1                 matlab.ui.container.Panel
        KPIVal1                  matlab.ui.control.Label
        KPICard2                 matlab.ui.container.Panel
        KPIVal2                  matlab.ui.control.Label
        KPICard3                 matlab.ui.container.Panel
        KPIVal3                  matlab.ui.control.Label
        KPICard4                 matlab.ui.container.Panel
        KPIVal4                  matlab.ui.control.Label
        DashMapAxes              matlab.graphics.axis.GeographicAxes
        QuickSimBtn              matlab.ui.control.Button
        
        % Tab 2: Route Planning
        TabRoute                 matlab.ui.container.Tab
        RouteGrid                matlab.ui.container.GridLayout
        OriginEdit               matlab.ui.control.EditField
        DestEdit                 matlab.ui.control.EditField
        APIKeyEdit               matlab.ui.control.EditField
        FetchRouteBtn            matlab.ui.control.Button
        ElevationAxes            matlab.ui.control.UIAxes
        RouteOptionsTable        matlab.ui.control.Table
        
        % Tab 3: Vehicle Configuration
        TabVehicle               matlab.ui.container.Tab
        VehGrid                  matlab.ui.container.GridLayout
        VehModelDropDown         matlab.ui.control.DropDown
        DriveModeDropDown        matlab.ui.control.DropDown
        AmbientTempSpinner       matlab.ui.control.Spinner
        HVACSwitch               matlab.ui.control.Switch
        
        % Tab 4: Simulation
        TabSim                   matlab.ui.container.Tab
        SimGrid                  matlab.ui.container.GridLayout
        SOCAxes                  matlab.ui.control.UIAxes
        PowerAxes                matlab.ui.control.UIAxes
        LossAxes                 matlab.ui.control.UIAxes
        
        % Tab 5: Compare & Charging
        TabCompare               matlab.ui.container.Tab
        CompareGrid              matlab.ui.container.GridLayout
        CompareTable             matlab.ui.control.Table
        ChargingAxes             matlab.ui.control.UIAxes
    end

    properties (Access = private)
        CurrentRouteData
    end

    methods (Access = private)

        function selectTab(app, targetTab)
            app.TabGroup.SelectedTab = targetTab;
        end

        function createComponents(app)
            % Main Figure Setup 
            app.UIFigure = uifigure('Name', 'EVRoute - Intelligent BEV Route & Energy Platform', ...
                'Color', [0.05 0.07 0.12], 'Position', [100 100 1350 820]);

            app.MainGrid = uigridlayout(app.UIFigure, [1, 2]);
            app.MainGrid.ColumnWidth = {220, '1x'};
            app.MainGrid.RowHeight = {'1x'};
            app.MainGrid.BackgroundColor = [0.05 0.07 0.12];

            % Sidebar Navigation Panel
            app.SidebarPanel = uipanel(app.MainGrid, 'BackgroundColor', [0.08 0.11 0.18], 'BorderType', 'none');
            app.SidebarGrid = uigridlayout(app.SidebarPanel, [7, 1]);
            app.SidebarGrid.RowHeight = {60, 48, 48, 48, 48, 48, '1x'};
            app.SidebarGrid.Padding = [10 15 10 15];

            app.LogoLabel = uilabel(app.SidebarGrid, 'Text', '⚡ EVRoute', ...
                'FontSize', 22, 'FontWeight', 'bold', 'FontColor', [0.0 0.9 0.6]);

            app.NavDashBtn = uibutton(app.SidebarGrid, 'push', 'Text', '  📊  Dashboard', ...
                'BackgroundColor', [0.12 0.17 0.28], 'FontColor', [1 1 1], 'FontSize', 13);
            app.NavRouteBtn = uibutton(app.SidebarGrid, 'push', 'Text', '  🗺️  Route Planning', ...
                'BackgroundColor', [0.12 0.17 0.28], 'FontColor', [1 1 1], 'FontSize', 13);
            app.NavVehBtn = uibutton(app.SidebarGrid, 'push', 'Text', '  🚗  Vehicle Config', ...
                'BackgroundColor', [0.12 0.17 0.28], 'FontColor', [1 1 1], 'FontSize', 13);
            app.NavSimBtn = uibutton(app.SidebarGrid, 'push', 'Text', '  ⚡  Simulation', ...
                'BackgroundColor', [0.12 0.17 0.28], 'FontColor', [1 1 1], 'FontSize', 13);
            app.NavCompareBtn = uibutton(app.SidebarGrid, 'push', 'Text', '  📈  Compare & Charging', ...
                'BackgroundColor', [0.12 0.17 0.28], 'FontColor', [1 1 1], 'FontSize', 13);

            % Main Content Area
            app.ContentCard = uipanel(app.MainGrid, 'BackgroundColor', [0.05 0.07 0.12], 'BorderType', 'none');
            app.ContentGrid = uigridlayout(app.ContentCard, [1, 1]);
            app.ContentGrid.Padding = [5 5 5 5];

            app.TabGroup = uitabgroup(app.ContentGrid);
            
            % Setup Tabs
            app.setupDashboardTab();
            app.setupRouteTab();
            app.setupVehicleTab();
            app.setupSimTab();
            app.setupCompareTab();
            
            % Link Button Callbacks
            app.NavDashBtn.ButtonPushedFcn = @(~,~) app.selectTab(app.TabDashboard);
            app.NavRouteBtn.ButtonPushedFcn = @(~,~) app.selectTab(app.TabRoute);
            app.NavVehBtn.ButtonPushedFcn = @(~,~) app.selectTab(app.TabVehicle);
            app.NavSimBtn.ButtonPushedFcn = @(~,~) app.selectTab(app.TabSim);
            app.NavCompareBtn.ButtonPushedFcn = @(~,~) app.selectTab(app.TabCompare);

            % Automatically load data on startup
            app.loadFallbackKalyanNashikData();
        end

        function setupDashboardTab(app)
            app.TabDashboard = uitab(app.TabGroup, 'Title', 'Dashboard', 'BackgroundColor', [0.05 0.07 0.12]);
            app.DashGrid = uigridlayout(app.TabDashboard, [3, 4]);
            app.DashGrid.RowHeight = {100, '1x', 45};
            app.DashGrid.ColumnWidth = {'1x', '1x', '1x', '1x'};

            % Badges
            app.KPICard1 = uipanel(app.DashGrid, 'BackgroundColor', [0.10 0.14 0.24], 'BorderColor', [0.15 0.22 0.35]);
            uilabel(app.KPICard1, 'Text', 'FINAL BATTERY SOC', 'Position', [12 68 150 18], 'FontColor', [0.6 0.7 0.8], 'FontSize', 10);
            app.KPIVal1 = uilabel(app.KPICard1, 'Text', '-- %', 'Position', [12 18 180 42], 'FontColor', [0.0 0.9 0.6], 'FontSize', 28, 'FontWeight', 'bold');

            app.KPICard2 = uipanel(app.DashGrid, 'BackgroundColor', [0.10 0.14 0.24], 'BorderColor', [0.15 0.22 0.35]);
            uilabel(app.KPICard2, 'Text', 'REMAINING RANGE', 'Position', [12 68 150 18], 'FontColor', [0.6 0.7 0.8], 'FontSize', 10);
            app.KPIVal2 = uilabel(app.KPICard2, 'Text', '-- km', 'Position', [12 18 180 42], 'FontColor', [0.0 0.85 1.0], 'FontSize', 28, 'FontWeight', 'bold');

            app.KPICard3 = uipanel(app.DashGrid, 'BackgroundColor', [0.10 0.14 0.24], 'BorderColor', [0.15 0.22 0.35]);
            uilabel(app.KPICard3, 'Text', 'SPECIFIC ENERGY', 'Position', [12 68 180 18], 'FontColor', [0.6 0.7 0.8], 'FontSize', 10);
            app.KPIVal3 = uilabel(app.KPICard3, 'Text', '-- kWh/100km', 'Position', [12 18 210 42], 'FontColor', [1.0 0.75 0.0], 'FontSize', 22, 'FontWeight', 'bold');

            app.KPICard4 = uipanel(app.DashGrid, 'BackgroundColor', [0.10 0.14 0.24], 'BorderColor', [0.15 0.22 0.35]);
            uilabel(app.KPICard4, 'Text', 'ESTIMATED TRIP TIME', 'Position', [12 68 180 18], 'FontColor', [0.6 0.7 0.8], 'FontSize', 10);
            app.KPIVal4 = uilabel(app.KPICard4, 'Text', '-- h -- min', 'Position', [12 18 180 42], 'FontColor', [0.9 0.4 0.9], 'FontSize', 24, 'FontWeight', 'bold');

            % Fixed Map Rendering: Placed directly in Grid Layout so it stretches to fill the space
            app.DashMapAxes = geoaxes(app.DashGrid);
            app.DashMapAxes.Layout.Row = 2;
            app.DashMapAxes.Layout.Column = [1 4];

            app.QuickSimBtn = uibutton(app.DashGrid, 'push', 'Text', '🚀 Run Route Energy Simulation', ...
                'BackgroundColor', [0.0 0.75 0.5], 'FontColor', [1 1 1], 'FontSize', 15, 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) app.runSimulationCallback());
            app.QuickSimBtn.Layout.Row = 3;
            app.QuickSimBtn.Layout.Column = [1 4];
        end

        function setupRouteTab(app)
            app.TabRoute = uitab(app.TabGroup, 'Title', 'Route Planning', 'BackgroundColor', [0.05 0.07 0.12]);
            app.RouteGrid = uigridlayout(app.TabRoute, [3, 3]);
            app.RouteGrid.RowHeight = {160, '1x', '1x'};
            app.RouteGrid.ColumnWidth = {340, '1x', '1x'};

            inputPanel = uipanel(app.RouteGrid, 'Title', 'Google Maps API Engine', ...
                'BackgroundColor', [0.10 0.14 0.24], 'ForegroundColor', [0.9 0.9 0.9]);
            inputPanel.Layout.Row = 1;
            inputPanel.Layout.Column = 1;
            
            inputGrid = uigridlayout(inputPanel, [4, 2]);
            inputGrid.RowHeight = {25, 25, 25, 35};

            uilabel(inputGrid, 'Text', 'Origin:', 'FontColor', [0.8 0.8 0.8]);
            app.OriginEdit = uieditfield(inputGrid, 'text', 'Value', 'Kalyan, Maharashtra', 'BackgroundColor', [1 1 1]);

            uilabel(inputGrid, 'Text', 'Destination:', 'FontColor', [0.8 0.8 0.8]);
            app.DestEdit = uieditfield(inputGrid, 'text', 'Value', 'Nagpur, Maharashtra', 'BackgroundColor', [1 1 1]);

            uilabel(inputGrid, 'Text', 'Google API Key:', 'FontColor', [0.8 0.8 0.8]);
            
            % !!! PASTE YOUR API KEY HERE !!!
            app.APIKeyEdit = uieditfield(inputGrid, 'text', 'Value', 'AIzaSyCZiGTab7EWDF9Cq4OO6RVwIvuTiDvucYE', 'BackgroundColor', [1 1 1]);

            app.FetchRouteBtn = uibutton(inputGrid, 'push', 'Text', '🔍 Fetch Live Route & Elevation', ...
                'BackgroundColor', [0.0 0.55 0.9], 'FontColor', [1 1 1], 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) app.fetchRoutesCallback());
            app.FetchRouteBtn.Layout.Column = [1 2];

            tablePanel = uipanel(app.RouteGrid, 'Title', 'Route Alternatives', ...
                'BackgroundColor', [0.10 0.14 0.24], 'ForegroundColor', [0.9 0.9 0.9]);
            tablePanel.Layout.Row = 1;
            tablePanel.Layout.Column = [2 3];
            tableGrid = uigridlayout(tablePanel, [1, 1]);
            tableGrid.Padding = [0 0 0 0];
            app.RouteOptionsTable = uitable(tableGrid, 'BackgroundColor', [1 1 1]);

            elevPanel = uipanel(app.RouteGrid, 'BackgroundColor', [0.08 0.11 0.18], 'BorderType', 'none');
            elevPanel.Layout.Row = [2 3];
            elevPanel.Layout.Column = [1 3];
            elevGrid = uigridlayout(elevPanel, [1, 1]);
            elevGrid.Padding = [0 0 0 0];
            app.ElevationAxes = uiaxes(elevGrid, 'BackgroundColor', [0.08 0.11 0.18], 'XColor', [0.8 0.8 0.8], 'YColor', [0.8 0.8 0.8]);
            title(app.ElevationAxes, 'Topographic Elevation Profile (meters)', 'Color', [0.9 0.9 0.9]);
        end

        function setupVehicleTab(app)
            app.TabVehicle = uitab(app.TabGroup, 'Title', 'Vehicle Config', 'BackgroundColor', [0.05 0.07 0.12]);
            app.VehGrid = uigridlayout(app.TabVehicle, [4, 2]);
            app.VehGrid.RowHeight = {40, 40, 40, 40};
            app.VehGrid.ColumnWidth = {200, 300};
            
            uilabel(app.VehGrid, 'Text', 'Select BEV Model:', 'FontColor', [0.9 0.9 0.9], 'FontSize', 13);
            app.VehModelDropDown = uidropdown(app.VehGrid, 'Items', ...
                {'Tata Nexon EV LR (40.5 kWh)', 'MG Windsor EV (38 kWh)', 'Mahindra XEV 9e (79 kWh)', 'Tata Curvv EV (55 kWh)'}, ...
                'Value', 'Tata Nexon EV LR (40.5 kWh)', 'BackgroundColor', [1 1 1]);

            uilabel(app.VehGrid, 'Text', 'Driving Behavior Mode:', 'FontColor', [0.9 0.9 0.9], 'FontSize', 13);
            app.DriveModeDropDown = uidropdown(app.VehGrid, 'Items', {'Eco (Max Range)', 'Normal (Balanced)', 'Performance (Max Power)'}, ...
                'Value', 'Eco (Max Range)', 'BackgroundColor', [1 1 1]);

            uilabel(app.VehGrid, 'Text', 'Ambient Temperature (°C):', 'FontColor', [0.9 0.9 0.9], 'FontSize', 13);
            app.AmbientTempSpinner = uispinner(app.VehGrid, 'Limits', [-10 50], 'Value', 32, 'BackgroundColor', [1 1 1]);

            uilabel(app.VehGrid, 'Text', 'Cabin AC / Heating:', 'FontColor', [0.9 0.9 0.9], 'FontSize', 13);
            app.HVACSwitch = uiswitch(app.VehGrid, 'Items', {'Off', 'On'}, 'Value', 'On');
        end

        function setupSimTab(app)
            app.TabSim = uitab(app.TabGroup, 'Title', 'Simulation', 'BackgroundColor', [0.05 0.07 0.12]);
            app.SimGrid = uigridlayout(app.TabSim, [2, 2]);

            socPanel = uipanel(app.SimGrid, 'BackgroundColor', [0.08 0.11 0.18], 'BorderType', 'none');
            socGrid = uigridlayout(socPanel, [1, 1]); socGrid.Padding = [0 0 0 0];
            app.SOCAxes = uiaxes(socGrid, 'BackgroundColor', [0.08 0.11 0.18], 'XColor', [0.8 0.8 0.8], 'YColor', [0.8 0.8 0.8]);
            title(app.SOCAxes, 'Battery SOC (%) Trajectory', 'Color', [0.0 0.9 0.6]);

            powerPanel = uipanel(app.SimGrid, 'BackgroundColor', [0.08 0.11 0.18], 'BorderType', 'none');
            powerGrid = uigridlayout(powerPanel, [1, 1]); powerGrid.Padding = [0 0 0 0];
            app.PowerAxes = uiaxes(powerGrid, 'BackgroundColor', [0.08 0.11 0.18], 'XColor', [0.8 0.8 0.8], 'YColor', [0.8 0.8 0.8]);
            title(app.PowerAxes, 'Powertrain Power (kW) & Regen', 'Color', [0.0 0.85 1.0]);

            lossPanel = uipanel(app.SimGrid, 'BackgroundColor', [0.08 0.11 0.18], 'BorderType', 'none');
            lossPanel.Layout.Column = [1 2];
            lossGrid = uigridlayout(lossPanel, [1, 1]); lossGrid.Padding = [0 0 0 0];
            app.LossAxes = uiaxes(lossGrid, 'BackgroundColor', [0.08 0.11 0.18], 'XColor', [0.8 0.8 0.8], 'YColor', [0.8 0.8 0.8]);
            title(app.LossAxes, 'Energy Loss Decomposition (kWh)', 'Color', [1.0 0.75 0.0]);
        end

        function setupCompareTab(app)
            app.TabCompare = uitab(app.TabGroup, 'Title', 'Compare & Charging', 'BackgroundColor', [0.05 0.07 0.12]);
            app.CompareGrid = uigridlayout(app.TabCompare, [2, 1]);

            app.CompareTable = uitable(app.CompareGrid, 'BackgroundColor', [1 1 1]);
            
            chargingPanel = uipanel(app.CompareGrid, 'BackgroundColor', [0.08 0.11 0.18], 'BorderType', 'none');
            chargingGrid = uigridlayout(chargingPanel, [1, 1]); chargingGrid.Padding = [0 0 0 0];
            app.ChargingAxes = uiaxes(chargingGrid, 'BackgroundColor', [0.08 0.11 0.18], 'XColor', [0.8 0.8 0.8], 'YColor', [0.8 0.8 0.8]);
            title(app.ChargingAxes, 'Route Charging Stops', 'Color', [0.9 0.4 0.9]);
        end

        % =================================================================
        % CORE ENGINE LOGIC
        % =================================================================
        function loadFallbackKalyanNashikData(app)
            samples = 200;
            dist = linspace(0, 138, samples)';
            elev = 35 + 20*sin(dist/12) + 580./(1 + exp(-(dist-75)/7));
            lat = linspace(19.2437, 19.9975, samples)' + 0.015*sin(dist/15);
            lon = linspace(73.1355, 73.7898, samples)' + 0.015*cos(dist/15);

            delta_elev = [0; diff(elev)];
            delta_dist_m = [1; diff(dist) * 1000];
            grade = (delta_elev ./ delta_dist_m) * 100;

            app.CurrentRouteData = struct();
            app.CurrentRouteData.Origin = 'Kalyan, Maharashtra';
            app.CurrentRouteData.Destination = 'Nashik, Maharashtra';
            app.CurrentRouteData.TotalDistance_km = 138;
            app.CurrentRouteData.EstimatedTime_sec = 9600;
            app.CurrentRouteData.Distance = dist;
            app.CurrentRouteData.Elevation = elev;
            app.CurrentRouteData.Grade = grade;
            app.CurrentRouteData.Lat = lat;
            app.CurrentRouteData.Lon = lon;
            
            try geoplot(app.DashMapAxes, lat, lon, '-o', 'Color', [0.0 0.9 0.6], 'LineWidth', 2.5); catch; end
            
            plot(app.ElevationAxes, dist, elev, 'Color', [0.0 0.85 1.0], 'LineWidth', 2);
            fill(app.ElevationAxes, [dist; flip(dist)], [elev; zeros(size(elev))], [0.0 0.85 1.0], 'FaceAlpha', 0.2);
            xlabel(app.ElevationAxes, 'Distance (km)'); ylabel(app.ElevationAxes, 'Elevation (m)');
            
            app.RouteOptionsTable.Data = table({'Route 1: Offline Default'}, [138], {'2h 40m'}, [24.2], ...
                'VariableNames', {'Route Alternative', 'Distance (km)', 'Est Time', 'Est Energy (kWh)'});

            app.runSimulationCallback();
        end

        function fetchRoutesCallback(app)
            origin = app.OriginEdit.Value;
            dest = app.DestEdit.Value;
            apiKey = app.APIKeyEdit.Value;
            
            if isempty(apiKey) || contains(apiKey, 'AIzaSy...')
                uialert(app.UIFigure, 'Please enter a valid Google Maps API Key.', 'Missing API Key'); return;
            end
            
            app.FetchRouteBtn.Text = 'Fetching API Data...'; drawnow;
            try
                app.CurrentRouteData = fetchGoogleRouteData(origin, dest, apiKey);
                try geoplot(app.DashMapAxes, app.CurrentRouteData.Lat, app.CurrentRouteData.Lon, '-o', 'Color', [0.0 0.9 0.6], 'LineWidth', 2.5); catch; end
                
                plot(app.ElevationAxes, app.CurrentRouteData.Distance, app.CurrentRouteData.Elevation, 'Color', [0.0 0.85 1.0], 'LineWidth', 2);
                fill(app.ElevationAxes, [app.CurrentRouteData.Distance; flip(app.CurrentRouteData.Distance)], [app.CurrentRouteData.Elevation; zeros(size(app.CurrentRouteData.Elevation))], [0.0 0.85 1.0], 'FaceAlpha', 0.2);
                xlabel(app.ElevationAxes, 'Distance (km)'); ylabel(app.ElevationAxes, 'Elevation (m)');
                
                if isfield(app.CurrentRouteData, 'AlternativesTable')
                    app.RouteOptionsTable.Data = cell2table(app.CurrentRouteData.AlternativesTable(:, 1:3), 'VariableNames', {'Route Alternative', 'Distance (km)', 'Est Time'});
                end
                app.runSimulationCallback();
                uialert(app.UIFigure, sprintf('Successfully loaded route to %s!', dest), 'Route Loaded');
            catch ME
                uialert(app.UIFigure, ME.message, 'API Error');
            end
            app.FetchRouteBtn.Text = '🔍 Fetch Live Route & Elevation';
        end

        function runSimulationCallback(app)
            if isempty(app.CurrentRouteData); return; end
            route = app.CurrentRouteData;
            
            vehChoice = app.VehModelDropDown.Value;
            if contains(vehChoice, 'Nexon')
                m = 1450; Cd = 0.32; A = 2.4; cap_kWh = 40.5;
            else
                m = 1520; Cd = 0.29; A = 2.3; cap_kWh = 38.0;
            end
            
            modeChoice = app.DriveModeDropDown.Value;
            if contains(modeChoice, 'Eco'); v_avg_kmh = 65; regen_eff = 0.75;
            else; v_avg_kmh = 80; regen_eff = 0.65; end
            
            if strcmp(app.HVACSwitch.Value, 'On'); P_hvac = 1800; else; P_hvac = 300; end
            
            v_ms = (v_avg_kmh / 3.6) + 3*sin(route.Distance/8);
            F_aero = 0.5 * 1.225 * Cd * A .* (v_ms.^2);
            F_roll = 0.012 * m * 9.81;
            F_grade = m * 9.81 .* (route.Grade / 100);
            
            P_wheel = (F_aero + F_roll + F_grade) .* v_ms;
            P_batt = zeros(length(route.Distance), 1);
            for i = 1:length(route.Distance)
                if P_wheel(i) >= 0; P_batt(i) = (P_wheel(i) / 0.90) + P_hvac;
                else; P_batt(i) = (P_wheel(i) * regen_eff) + P_hvac; end
            end
            
            dt_s = [0; diff(route.Distance * 1000)] ./ v_ms; dt_s(1) = 1;
            energy_kWh = cumsum(P_batt .* dt_s) / (3.6e6);
            soc = 100 - (energy_kWh / cap_kWh) * 100;
            
            app.KPIVal1.Text = sprintf('%.1f %%', soc(end));
            app.KPIVal2.Text = sprintf('%.0f km', max(0, (soc(end)/100)*(cap_kWh/(energy_kWh(end)/route.TotalDistance_km))));
            app.KPIVal3.Text = sprintf('%.1f kWh/100km', (energy_kWh(end)/route.TotalDistance_km)*100);
            t_hr = sum(dt_s)/3600; app.KPIVal4.Text = sprintf('%dh %02dm', floor(t_hr), round(rem(t_hr*60, 60)));
            
            plot(app.SOCAxes, route.Distance, soc, 'Color', [0.0 0.9 0.6], 'LineWidth', 2.5);
            plot(app.PowerAxes, route.Distance, P_batt/1000, 'Color', [0.0 0.85 1.0], 'LineWidth', 1.8);
            
            bar(app.LossAxes, categorical({'Aero', 'Roll', 'Grade', 'HVAC'}), ...
                [sum(max(0, F_aero.*v_ms.*dt_s)), sum(max(0, F_roll.*v_ms.*dt_s)), sum(max(0, F_grade.*v_ms.*dt_s)), P_hvac*sum(dt_s)]/3.6e6, ...
                'FaceColor', [1.0 0.75 0.0]);

            % Update the Compare & Charging Tab Table
            app.CompareTable.Data = app.RouteOptionsTable.Data;

            % Plot the Charging Stops Profile
            plot(app.ChargingAxes, route.Distance, soc, 'Color', [0.0 0.9 0.6], 'LineWidth', 2);
            hold(app.ChargingAxes, 'on');
            if min(soc) < 20
                idx = find(soc < 20, 1);
                x_charge = route.Distance(idx);
                plot(app.ChargingAxes, x_charge, soc(idx), 'p', 'MarkerSize', 15, 'MarkerFaceColor', [1 0.2 0.2]);
                text(app.ChargingAxes, x_charge+2, soc(idx), ' ⚡ Fast Charger Req.', 'Color', [1 0.8 0]);
            end
            hold(app.ChargingAxes, 'off');
            xlabel(app.ChargingAxes, 'Distance (km)');
            ylabel(app.ChargingAxes, 'SOC (%)');
            grid(app.ChargingAxes, 'on');
                
            app.TabGroup.SelectedTab = app.TabDashboard;
        end
    end

    methods (Access = public)
        function app = BEV_Route_Optimization_App
            createComponents(app);
        end
        function delete(app)
            delete(app.UIFigure);
        end
    end
end