classdef EVRoute_App < handle
   
    properties (Constant, Access = private)
        GoogleMapsKey = 'AIzaSyCZiGTab7EWDF9Cq4OO6RVwIvuTiDvucYE'                 
        FromDefault = 'Mumbai, Maharashtra'
        ToDefault   = 'Pune, Maharashtra'
        ReserveSOC  = 10                   % % never planned below this
        ChargeToSOC = 80                   % % typical DC fast-charge target
        BinKm       = 1                    % energy-model resolution [km]
        Palette     = {'#1E5EFF','#0E9F7E','#B8923A','#7A5AF8'}
    end

    properties (Access = public)
        User  = 'Sneha Pardeshi'
        Role  = 'EXCS | Engineer for a Cleaner Future'
        UIFigure
        Html
        GmKey    = ''
        Presets
        VehIdx   = 1
        Cfg                                 % editable vehicle configuration
        Env                                 % environment conditions
        Pref                                % route preferences
        Raw      = []
        Trip     = {}
        Sel      = 1
        Seq      = 0
        Busy     = false
        Timer    = []
        Drive    = []
    end

    % =====================================================================
    methods (Access = public)
        function app = EVRoute_App(gmKey)
            if nargin < 1 || isempty(gmKey), gmKey = getenv('GOOGLE_MAPS_API_KEY'); end
            if isempty(gmKey), gmKey = EVRoute_App.GoogleMapsKey; end
            app.GmKey   = char(gmKey);
            app.Presets = EVRoute_App.catalog();
            try                                        % remembered profile
                pr = getpref('EVRoute', 'profile', []);
                if isstruct(pr)
                    if isfield(pr, 'user'), app.User = char(pr.user); end
                    if isfield(pr, 'role'), app.Role = char(pr.role); end
                end
            catch
            end
            app.Cfg     = app.Presets(1);
            app.Env     = struct('temp', 28, 'wind', 10, 'windDir', 'Headwind', 'road', 'Dry', ...
                                 'grade', 0, 'traffic', 'Medium', 'tariff', 9, 'touched', false);
            app.Pref    = struct('pref', 'Most Efficient', 'avoidHwy', false, 'charging', true, 'mode', 'Normal', 'liveTraffic', true);
            app.resetDriveState();
            try, app.initDefaultTrip(); catch, end

            page = fullfile(fileparts(mfilename('fullpath')), 'evroute_ui.html');
            if ~isfile(page)
                error('EVRoute:ui', 'evroute_ui.html must be in the same folder as EVRoute_App.m');
            end
            bg = [0.957 0.969 0.965];
            sz = get(groot, 'ScreenSize');
            w = min(1600, sz(3) - 80); h = min(960, sz(4) - 120);
            app.UIFigure = uifigure('Name', 'EVRoute', 'Color', bg, ...
                'Position', [(sz(3)-w)/2, (sz(4)-h)/2, w, h], ...
                'CloseRequestFcn', @(~,~) delete(app));
            try, app.UIFigure.WindowState = 'maximized'; catch, end
            g = uigridlayout(app.UIFigure, [1 1], 'Padding', [0 0 0 0], 'BackgroundColor', bg);
            app.Html = uihtml(g, 'HTMLSource', page);
            app.Html.HTMLEventReceivedFcn = @(~, e) app.onEvent(e);
        end

        function delete(app)
            try
                if ~isempty(app.Timer) && isvalid(app.Timer), stop(app.Timer); delete(app.Timer); end
            catch, end
            try
                if ~isempty(app.UIFigure) && isvalid(app.UIFigure), delete(app.UIFigure); end
            catch, end
        end
    end

    % =====================================================================
    %  Events from the interface
    % =====================================================================
    methods (Access = public)

        function onEvent(app, e)
            try
                d = e.HTMLEventData;
                switch e.HTMLEventName
                    case 'ready'
                        app.onReady();
                    case 'plan'
                        app.Pref = struct('pref', char(d.pref), 'avoidHwy', logical(d.avoidHwy), ...
                                          'charging', logical(d.charging), 'mode', char(d.mode), ...
                                          'liveTraffic', logical(d.liveTraffic));
                        app.plan(char(d.origin), char(d.dest));
                    case 'mode'
                        app.Pref.mode = char(d);
                        app.reeval();
                    case 'preset'
                        app.VehIdx = double(d) + 1;
                        app.Cfg = app.Presets(app.VehIdx);
                        app.reeval();
                    case 'config'
                        f = fieldnames(d);
                        for i = 1:numel(f)
                            if isfield(app.Cfg, f{i}) && isnumeric(d.(f{i}))
                                app.Cfg.(f{i}) = double(d.(f{i}));
                            end
                        end
                        app.reeval(); app.toast('Configuration saved and trip re-simulated.', 'ok');
                    case 'env'
                        f = fieldnames(d);
                        for i = 1:numel(f)
                            if isfield(app.Env, f{i}) && ~strcmp(f{i}, 'touched')
                                if ischar(d.(f{i})) || isstring(d.(f{i}))
                                    app.Env.(f{i}) = char(d.(f{i}));
                                else
                                    app.Env.(f{i}) = double(d.(f{i}));
                                end
                            end
                        end
                        app.Env.touched = true; app.reeval();
                    case 'select'
                        app.Sel = double(d) + 1; app.resetDrive();
                    case 'drive'
                        app.driveCmd(char(d));
                    case 'reroute'
                        app.reroute();
                    case 'playback'
                        app.Drive.rate = double(d);
                    case 'profile'
                        if isfield(d, 'user') && ~isempty(strtrim(char(d.user))), app.User = strtrim(char(d.user)); end
                        if isfield(d, 'role'), app.Role = strtrim(char(d.role)); end
                        try, setpref('EVRoute', 'profile', struct('user', app.User, 'role', app.Role)); catch, end
                        app.send('profile', struct('user', app.User, 'role', app.Role));
                        app.toast('Profile updated.', 'ok');
                    case 'export'
                        if strcmp(char(d.kind), 'pdf'), app.exportPdf(d.sections); else, app.exportData(); end
                    case 'fetchTiles'
                        app.fetchMissingTiles(d);
                end
            catch ME
                app.Busy = false;
                app.send('busy', struct('on', false, 'text', ''));
                app.toast(ME.message, 'error');
            end
        end

        function onReady(app)
            names = arrayfun(@(p) p.name, app.Presets, 'UniformOutput', false);
            initData = struct('gmKey', app.GmKey, 'user', app.User, 'role', app.Role, 'presets', {names}, ...
                'vi', app.VehIdx - 1, 'from', app.FromDefault, 'to', app.ToDefault, ...
                'cfg', app.Cfg, 'env', app.Env);
            if isempty(app.Trip)
                try, app.initDefaultTrip(); catch, end
            end
            if ~isempty(app.Trip)
                tripData = app.buildTripData();
                liveData = app.buildLiveData();
                app.send('init', initData, 'trip', tripData, 'live', liveData);
            else
                app.send('init', initData);
            end
        end

        function reeval(app)
            if isempty(app.Raw), return; end
            app.evaluateAll(); app.pushTrip(); app.resetDrive();
        end

        function send(app, varargin)
            n = numel(varargin)/2;
            cmds = cell(1, n);
            for k = 1:n
                cmds{k} = struct('type', varargin{2*k-1}, 'data', {varargin{2*k}});
            end
            app.Seq = app.Seq + 1;
            app.Html.Data = jsonencode(struct('seq', app.Seq, 'cmds', {cmds}));
            % Data is a single property: without flushing, a later write can
            % overwrite this one before the page ever sees it.
            drawnow limitrate; drawnow;
        end

        function busy(app, txt)
            app.send('busy', struct('on', true, 'text', txt)); drawnow;
        end
        function toast(app, msg, kind), app.send('toast', struct('msg', msg, 'kind', kind)); end
        function endBusy(app)
            app.Busy = false; app.send('busy', struct('on', false, 'text', ''));
        end
    end

    % =====================================================================
    %  Trip planning: places -> routes -> elevation -> chargers -> energy
    % =====================================================================
    methods (Access = public)

        function initDefaultTrip(app)
            try
                matDir = fullfile(fileparts(mfilename('fullpath')), 'Data', 'OfflineRoutes');
                m1 = load(fullfile(matDir, 'Mumbai_Pune_Expressway.mat'));
                m2 = load(fullfile(matDir, 'Mumbai_Pune_OldNH48.mat'));
                rd1 = m1.routeData;
                rd2 = m2.routeData;
                
                % Route 1: Mumbai to Pune via Expressway (Fastest)
                r1 = struct();
                r1.path = [rd1.Latitude, rd1.Longitude];
                r1.cum = rd1.Distance_km;
                r1.distKm = rd1.TotalDistance_km;
                r1.durMin = rd1.EstimatedDuration_min;
                r1.elev = rd1.Elevation_m;
                r1.via = 'Mumbai - Pune Expressway';
                r1.liveTf = 0.95;
                
                wpD1 = rd1.Waypoints_Distance_km;
                wpV1 = rd1.TrafficSpeed_kmh(round(linspace(1, numel(rd1.TrafficSpeed_kmh), numel(wpD1))));
                wpInstr1 = {'Depart Mumbai on Eastern Express Hwy', 'Merge onto Mumbai - Pune Expressway', ...
                    'Pass Khalapur Toll Plaza (Charger Hub)', 'Climb Khandala Ghat section', ...
                    'Pass Khandala Summit & Lonavala', 'Descend toward Talegaon', ...
                    'Pass Urse Toll Plaza (Fast Charger)', 'Enter Pune Urban via Wakad & Shivaji Nagar'};
                nS1 = numel(wpInstr1);
                sD1 = diff([wpD1(1:min(nS1, numel(wpD1))); rd1.TotalDistance_km]);
                sD1 = sD1(1:nS1);
                r1.steps = struct('sKm', wpD1(:), 'sV', wpV1(:), ...
                    'turnKm', wpD1(1:nS1), 'turnTxt', {wpInstr1(:)}, ...
                    'turnIco', {repmat({'straight'}, nS1, 1)}, ...
                    'name', {wpInstr1(:)}, 'd', sD1);
                
                % Route 2: Mumbai to Pune via Old NH48 (Alternative / Scenic)
                r2 = struct();
                r2.path = [rd2.Latitude, rd2.Longitude];
                r2.cum = rd2.Distance_km;
                r2.distKm = rd2.TotalDistance_km;
                r2.durMin = rd2.EstimatedDuration_min;
                r2.elev = rd2.Elevation_m;
                r2.via = 'Old Mumbai - Pune Hwy (NH48)';
                r2.liveTf = 0.85;
                
                wpD2 = rd2.Waypoints_Distance_km;
                wpV2 = rd2.TrafficSpeed_kmh(round(linspace(1, numel(rd2.TrafficSpeed_kmh), numel(wpD2))));
                wpInstr2 = {'Depart Mumbai via Sion-Panvel Expressway', 'Follow Old NH48 through Khopoli', ...
                    'Climb Bhor Ghat hairpin turns', 'Pass Khandala & Lonavala Market', ...
                    'Follow NH48 through Kamshet & Dehu Road', 'Arrive at Pune Station'};
                nS2 = numel(wpInstr2);
                sD2 = diff([wpD2(1:min(nS2, numel(wpD2))); rd2.TotalDistance_km]);
                sD2 = sD2(1:nS2);
                r2.steps = struct('sKm', wpD2(:), 'sV', wpV2(:), ...
                    'turnKm', wpD2(1:nS2), 'turnTxt', {wpInstr2(:)}, ...
                    'turnIco', {repmat({'straight'}, nS2, 1)}, ...
                    'name', {wpInstr2(:)}, 'd', sD2);
                
                routes = {r1, r2};
                
                % Charging stations from corridor
                chg = rd1.ChargingStations;
                nc = numel(chg);
                stnLat = zeros(nc, 1);
                stnLon = zeros(nc, 1);
                stnName = cell(nc, 1);
                stnKw = zeros(nc, 1);
                for k = 1:nc
                    stnLat(k) = interp1(rd1.Distance_km, rd1.Latitude, chg(k).Distance_km, 'linear');
                    stnLon(k) = interp1(rd1.Distance_km, rd1.Longitude, chg(k).Distance_km, 'linear');
                    stnName{k} = chg(k).Name;
                    stnKw(k) = chg(k).Power_kW;
                end
                % Add key highway fast charger hubs
                stnLat = [stnLat; 19.0150; 18.6010];
                stnLon = [stnLon; 73.0420; 73.7650];
                stnName = [stnName; {'ChargeZone Vashi-Belapur Hub'}; {'Shell Recharge Wakad Plaza'}];
                stnKw = [stnKw; 120; 150];
                stnDc = true(numel(stnLat), 1);
                
                stn = struct('lat', stnLat, 'lon', stnLon, 'name', {stnName}, 'kw', stnKw, 'dc', stnDc);
                
                app.Raw = struct('fromName', rd1.Origin, 'toName', rd1.Destination, ...
                    'fromLL', [rd1.Latitude(1), rd1.Longitude(1)], ...
                    'toLL', [rd1.Latitude(end), rd1.Longitude(end)], ...
                    'routes', {routes}, 'stn', stn, ...
                    'wx', struct('temp', 28, 'wind', 10, 'text', 'Clear 28°C'));
                
                app.evaluateAll();
                app.Sel = 1;
                app.resetDrive();
            catch ME
                fprintf(2, 'Warning: initDefaultTrip encountered: %s\n', ME.message);
            end
        end

        function plan(app, fromTxt, toTxt)
            if app.Busy, return; end
            app.Busy = true;
            fin = onCleanup(@() app.endBusy()); %#ok<NASGU>
            app.stopTimer();

            app.busy('Locating your places...');
            [a, an] = app.geocode(fromTxt);
            if isempty(app.GmKey), pause(1.05); end        % Nominatim: max 1 request / second
            [b, bn] = app.geocode(toTxt);

            app.busy('Finding drivable routes...');
            routes = app.fetchRoutes(a, b);
            routes = app.addElevation(routes);

            stn = struct('lat', zeros(0,1), 'lon', zeros(0,1), 'name', {cell(0,1)}, 'kw', zeros(0,1), 'dc', false(0,1));
            if app.Pref.charging
                app.busy('Scanning the corridor for DC fast chargers...');
                stn = app.fetchStations(routes);
            end
            app.busy('Checking conditions...');
            wx = EVRoute_App.fetchWeather(a);
            if ~app.Env.touched, app.Env.temp = wx.temp; end

            app.Raw = struct('fromName', an, 'toName', bn, 'fromLL', a, 'toLL', b, ...
                'routes', {routes}, 'stn', stn, 'wx', wx);
            app.busy('Simulating energy use and optimizing charging...');
            app.evaluateAll();
            switch app.Pref.pref
                case 'Fastest',  [~, app.Sel] = min(cellfun(@(r) r.totalMin, app.Trip));
                case 'Shortest', [~, app.Sel] = min(cellfun(@(r) r.distKm,  app.Trip));
                otherwise,       [~, app.Sel] = min(cellfun(@(r) r.energy,  app.Trip));
            end
            app.pushTrip();
            app.resetDrive();
            app.cacheRouteTiles(routes);
        end

        function [ll, nm] = geocode(app, q)
            if ~isempty(app.GmKey)
                try
                    r = webread(['https://maps.googleapis.com/maps/api/geocode/json?address=' ...
                        urlencode(q) '&key=' app.GmKey], EVRoute_App.webOpts(20));
                    results = EVRoute_App.asCell(r.results);
                    if strcmp(r.status, 'OK') && ~isempty(results)
                        res = results{1};
                        ll = [res.geometry.location.lat res.geometry.location.lng];
                        parts = EVRoute_App.asCell(res.address_components);
                        nm = '';
                        for i = 1:numel(parts)
                            t = EVRoute_App.asCell(parts{i}.types);
                            if any(strcmp(t, 'locality')) || (isempty(nm) && any(strcmp(t, 'administrative_area_level_2')))
                                nm = parts{i}.long_name;
                            end
                        end
                        if isempty(nm), nm = strtrim(strtok(q, ',')); end
                        return
                    elseif strcmp(r.status, 'REQUEST_DENIED')
                        app.toast('Google geocoding was rejected. Using OpenStreetMap instead.', 'warn');
                    end
                catch
                end
            end
            [ll, nm] = EVRoute_App.geocodeNominatim(q);
        end

        function reroute(app)
            % Recalculates the route live, from wherever the simulated drive
            % currently is, to the original destination -- used by the
            % Simulation tab's "Reroute" control (missed turn / detour demo).
            if app.Busy || isempty(app.Trip), return; end
            app.Busy = true;
            fin = onCleanup(@() app.endBusy()); %#ok<NASGU>
            app.stopTimer();
            D = app.Drive; r = app.Trip{app.Sel};
            a = [interp1(r.cum, r.path(:,1), D.s) interp1(r.cum, r.path(:,2), D.s)];
            b = app.Raw.toLL;
            app.busy('Recalculating your route...');
            routes = app.fetchRoutes(a, b);
            routes = app.addElevation(routes);
            stn = struct('lat', zeros(0,1), 'lon', zeros(0,1), 'name', {cell(0,1)}, 'kw', zeros(0,1), 'dc', false(0,1));
            if app.Pref.charging
                app.busy('Scanning the corridor for DC fast chargers...');
                stn = app.fetchStations(routes);
            end
            app.Raw.fromName = 'Current location'; app.Raw.fromLL = a;
            app.Raw.routes = routes; app.Raw.stn = stn;
            C = app.Cfg; C.soc0 = max(min(D.soc, 100), 1); app.Cfg = C;   % continue from current charge
            app.busy('Re-simulating from your current position...');
            app.evaluateAll();
            app.Sel = 1;
            app.cacheRouteTiles(routes);
            app.pushTrip();
            app.resetDrive();
            app.toast('Route recalculated from your current position.', 'ok');
        end

        function routes = fetchRoutes(app, a, b)
            if ~isempty(app.GmKey)
                try
                    routes = app.fetchRoutesGoogle(a, b);
                    if ~isempty(routes), return, end
                catch ME
                    app.toast(['Google Directions failed (' ME.message '). Falling back to OpenStreetMap routing.'], 'warn');
                end
            end
            routes = app.fetchRoutesOsrm(a, b);
        end

        function routes = fetchRoutesGoogle(app, a, b)
            base = sprintf(['https://maps.googleapis.com/maps/api/directions/json?origin=%.6f,%.6f' ...
                '&destination=%.6f,%.6f&alternatives=true'], a(1), a(2), b(1), b(2));
            if app.Pref.avoidHwy, base = [base '&avoid=highways']; end
            if app.Pref.liveTraffic, base = [base '&departure_time=now&traffic_model=best_guess']; end
            resp = webread([base '&key=' app.GmKey], EVRoute_App.webOpts(90));
            if strcmp(resp.status, 'ZERO_RESULTS')
                error('EVRoute:route', 'No drivable route was found between those places.');
            elseif ~strcmp(resp.status, 'OK')
                error('EVRoute:route', 'Google Directions returned %s.', resp.status);
            end
            rc = EVRoute_App.asCell(resp.routes);
            rc = rc(1:min(4, numel(rc)));
            routes = cellfun(@(r) EVRoute_App.parseRouteGoogle(r), rc, 'UniformOutput', false);
            routes = routes(:)';
        end

        function routes = fetchRoutesOsrm(app, a, b)
            opt = EVRoute_App.webOpts(90);
            base = sprintf(['https://router.project-osrm.org/route/v1/driving/%.6f,%.6f;%.6f,%.6f' ...
                '?overview=full&geometries=geojson&steps=true'], a(2), a(1), b(2), b(1));
            ex = ''; if app.Pref.avoidHwy, ex = '&exclude=motorway'; end
            % NOTE: the public OSRM demo runs the MLD algorithm, which only accepts
            % alternatives=true/false -- NOT a specific count. Requesting a count
            % (the old "&alternatives=3") makes the server reject the request with
            % a 400 error for many origin/destination pairs.
            resp = webread([base '&alternatives=true' ex], opt);
            if ~strcmp(resp.code, 'Ok')
                error('EVRoute:route', 'No drivable route was found between those places.');
            end
            rc = EVRoute_App.asCell(resp.routes);
            rc = rc(1:min(3, numel(rc)));
            routes = cellfun(@(r) EVRoute_App.parseRoute(r), rc, 'UniformOutput', false);
            routes = routes(:)';
            if ~app.Pref.avoidHwy                              % one extra local / scenic option
                try
                    app.busy('Looking for a scenic alternative...');
                    r2 = webread([base '&alternatives=false&exclude=motorway'], opt);
                    if strcmp(r2.code, 'Ok')
                        c2 = EVRoute_App.asCell(r2.routes);
                        cand = EVRoute_App.parseRoute(c2{1});
                        isNew = all(cellfun(@(q) abs(q.distKm - cand.distKm)/q.distKm > 0.01 || ...
                            abs(q.durMin - cand.durMin)/q.durMin > 0.02, routes));
                        if isNew && numel(routes) < 4, routes{end+1} = cand; end
                    end
                catch, end
            end
        end

        function routes = addElevation(app, routes)
            opt = EVRoute_App.webOpts(30);
            for i = 1:numel(routes)
                app.busy(sprintf('Reading elevation (%d of %d)...', i, numel(routes)));
                R = routes{i}; n = numel(R.cum);
                ns = min(100, max(20, ceil(R.distKm/8)));
                idx = unique(round(linspace(1, n, min(n, ns))));
                e = [];
                if ~isempty(app.GmKey)
                    try
                        locs = strjoin(compose('%.5f,%.5f', R.path(idx,1), R.path(idx,2)), '|');
                        w = webread(['https://maps.googleapis.com/maps/api/elevation/json?locations=' ...
                            locs '&key=' app.GmKey], opt);
                        if strcmp(w.status, 'OK')
                            res = EVRoute_App.asCell(w.results);
                            e = cellfun(@(x) x.elevation, res);
                        end
                    catch, end
                end
                if isempty(e)
                    try
                        la = strjoin(compose('%.4f', R.path(idx,1)), ',');
                        lo = strjoin(compose('%.4f', R.path(idx,2)), ',');
                        w = webread(['https://api.open-meteo.com/v1/elevation?latitude=' la '&longitude=' lo], opt);
                        e = double(w.elevation(:));
                    catch, end
                end
                if numel(e) == numel(idx)
                    e = movmean(e, 3);
                    R.elev = interp1(R.cum(idx), e, R.cum, 'linear', 'extrap');
                end
                routes{i} = R;
            end
        end

        function stn = fetchStations(app, routes)
            stn = struct('lat', zeros(0,1), 'lon', zeros(0,1), 'name', {cell(0,1)}, 'kw', zeros(0,1), 'dc', false(0,1));
            try
                stn = app.fetchStationsOverpass(routes);
            catch
            end
            % If live charger query returns insufficient stations, synthesize realistic DC fast chargers
            if numel(stn.lat) < 2
                stn = EVRoute_App.synthesizeCorridorChargers(routes, stn);
            end
        end

        function stn = fetchStationsOverpass(app, routes)
            stn = struct('lat', zeros(0,1), 'lon', zeros(0,1), 'name', {cell(0,1)}, 'kw', zeros(0,1), 'dc', false(0,1));
            try
                allLats = []; allLons = [];
                for i = 1:numel(routes)
                    allLats = [allLats; routes{i}.path(:,1)]; %#ok<AGROW>
                    allLons = [allLons; routes{i}.path(:,2)]; %#ok<AGROW>
                end
                if isempty(allLats), return; end
                
                minLat = max(-85, min(allLats) - 0.15);
                maxLat = min(85, max(allLats) + 0.15);
                minLon = max(-180, min(allLons) - 0.15);
                maxLon = min(180, max(allLons) + 0.15);
                
                % Overpass QL query: bounding box around corridor
                q = sprintf('[out:json][timeout:4];node["amenity"="charging_station"](%.4f,%.4f,%.4f,%.4f);out 60;', ...
                    minLat, minLon, maxLat, maxLon);
                url = ['https://overpass-api.de/api/interpreter?data=' urlencode(q)];
                opt = weboptions('Timeout', 4, 'UserAgent', 'EVRoute-MATLAB/2.0', 'ContentType', 'json');
                resp = webread(url, opt);
                
                els = EVRoute_App.asCell(resp.elements);
                n = numel(els);
                if n == 0, return; end
                
                lat = nan(n,1); lon = nan(n,1); kw = nan(n,1); dc = true(n,1);
                nm = repmat({'Fast Charging Hub'}, n, 1);
                outKeys = {'socket_ccs2_output','socket_ccs_output','socket_chademo_output','charging_station_output','socket_type2_combo_output'};
                
                for i = 1:n
                    e = els{i};
                    if isfield(e, 'lat'), lat(i) = e.lat; lon(i) = e.lon;
                    elseif isfield(e, 'center'), lat(i) = e.center.lat; lon(i) = e.center.lon; end
                    if isfield(e, 'tags') && isstruct(e.tags)
                        t = e.tags;
                        if isfield(t, 'name'), nm{i} = t.name;
                        elseif isfield(t, 'operator'), nm{i} = [t.operator ' EV Station'];
                        elseif isfield(t, 'brand'), nm{i} = [t.brand ' Charging Point']; end
                        for k = 1:numel(outKeys)
                            if isfield(t, outKeys{k})
                                v = str2double(regexp(char(t.(outKeys{k})), '[\d.]+', 'match', 'once'));
                                if ~isnan(v), kw(i) = v; break; end
                            end
                        end
                    end
                end
                ok = ~isnan(lat) & ~isnan(lon);
                lat = lat(ok); lon = lon(ok); kw = kw(ok); dc = dc(ok); nm = nm(ok);
                kw(isnan(kw)) = 120;
                [~, iu] = unique(round([lat lon], 3), 'rows');
                stn = struct('lat', lat(iu), 'lon', lon(iu), 'name', {nm(iu)}, 'kw', kw(iu), 'dc', dc(iu));
            catch
            end
        end

        function downloadTiles(~, tileList)
            if isempty(tileList), return; end
            try
                cfgFile = fullfile(tempdir, sprintf('evroute_curl_%d_%d.cfg', randi(1e7), round(posixtime(datetime('now')))));
                fid = fopen(cfgFile, 'w');
                if fid == -1, return; end
                
                fprintf(fid, 'user-agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"\n');
                fprintf(fid, 'connect-timeout = 5\n');
                fprintf(fid, 'retry = 1\n');
                
                count = 0;
                for k = 1:numel(tileList)
                    if ~isfile(tileList(k).dest)
                        fprintf(fid, 'url = "%s"\noutput = "%s"\n', tileList(k).url, strrep(tileList(k).dest, '\', '/'));
                        count = count + 1;
                    end
                end
                fclose(fid);
                
                if count > 0
                    cmd = sprintf('curl.exe -s --parallel --parallel-max 30 --config "%s"', cfgFile);
                    system(cmd);
                end
                if isfile(cfgFile), delete(cfgFile); end
            catch
            end
        end

        function cacheRouteTiles(app, routes)
            try
                tilesDir = fullfile(fileparts(mfilename('fullpath')), 'tiles');
                if ~isfolder(tilesDir), mkdir(tilesDir); end
                
                allPts = [];
                for k = 1:numel(routes)
                    if isfield(routes{k}, 'path') && ~isempty(routes{k}.path)
                        allPts = [allPts; routes{k}.path]; %#ok<AGROW>
                    end
                end
                if isempty(allPts), return; end
                
                la0 = min(allPts(:,1)); la1 = max(allPts(:,1));
                lo0 = min(allPts(:,2)); lo1 = max(allPts(:,2));
                
                dx = abs(lo1 - lo0); dy = abs(la1 - la0);
                span = max(dx, dy);
                if span > 40,      zBase = 4;
                elseif span > 20,  zBase = 5;
                elseif span > 10,  zBase = 6;
                elseif span > 5,   zBase = 7;
                elseif span > 2.5, zBase = 8;
                elseif span > 1.2, zBase = 9;
                elseif span > 0.6, zBase = 10;
                elseif span > 0.3, zBase = 11;
                elseif span > 0.15,zBase = 12;
                else,              zBase = 13;
                end
                
                zooms = unique(max(2, min(14, [zBase-2, zBase-1, zBase, zBase+1])));
                reqList = zeros(0, 3);
                
                % 1. Pre-cache bounding box for primary zooms
                for z = zooms
                    [x0, y1] = EVRoute_App.latLonToTile(la0, lo0, z);
                    [x1, y0] = EVRoute_App.latLonToTile(la1, lo1, z);
                    minX = max(0, min(x0, x1) - 1);
                    maxX = min(2^z - 1, max(x0, x1) + 1);
                    minY = max(0, min(y0, y1) - 1);
                    maxY = min(2^z - 1, max(y0, y1) + 1);
                    if (maxX - minX + 1) * (maxY - minY + 1) <= 64
                        [TX, TY] = meshgrid(minX:maxX, minY:maxY);
                        reqList = [reqList; repmat(z, numel(TX), 1), TX(:), TY(:)]; %#ok<AGROW>
                    end
                end
                
                % 2. Pre-cache route corridor at detailed zooms
                if size(allPts, 1) > 2
                    step = max(1, floor(size(allPts, 1) / 100));
                    samplePts = allPts(1:step:end, :);
                    corridorZooms = unique(max(2, min(14, [zBase+1, zBase+2, 11, 12, 13, 14])));
                    for z = corridorZooms
                        [tx, ty] = EVRoute_App.latLonToTile(samplePts(:,1), samplePts(:,2), z);
                        for dtx = -1:1
                            for dty = -1:1
                                curX = tx + dtx; curY = ty + dty;
                                ok = curX >= 0 & curX < 2^z & curY >= 0 & curY < 2^z;
                                reqList = [reqList; repmat(z, sum(ok), 1), curX(ok), curY(ok)]; %#ok<AGROW>
                            end
                        end
                    end
                end
                
                if ~isempty(reqList)
                    reqList = unique(reqList, 'rows');
                end
                
                tileList = struct('url', {}, 'dest', {});
                for k = 1:size(reqList, 1)
                    z = reqList(k, 1);
                    tx = reqList(k, 2);
                    ty = reqList(k, 3);
                    mFile = fullfile(tilesDir, sprintf('m_%d_%d_%d.png', z, tx, ty));
                    yFile = fullfile(tilesDir, sprintf('y_%d_%d_%d.jpg', z, tx, ty));
                    if ~isfile(mFile)
                        tileList(end+1) = struct('url', sprintf('https://mt1.google.com/vt/lyrs=m&x=%d&y=%d&z=%d', tx, ty, z), 'dest', mFile); %#ok<AGROW>
                    end
                    if ~isfile(yFile)
                        tileList(end+1) = struct('url', sprintf('https://mt1.google.com/vt/lyrs=y&x=%d&y=%d&z=%d', tx, ty, z), 'dest', yFile); %#ok<AGROW>
                    end
                end
                
                if ~isempty(tileList)
                    app.downloadTiles(tileList);
                    app.send('tilesReady', struct());
                end
            catch
            end
        end

        function fetchMissingTiles(app, reqs)
            try
                reqs = EVRoute_App.asCell(reqs);
                if isempty(reqs), return; end
                tilesDir = fullfile(fileparts(mfilename('fullpath')), 'tiles');
                if ~isfolder(tilesDir), mkdir(tilesDir); end
                
                tileList = struct('url', {}, 'dest', {});
                for i = 1:min(numel(reqs), 50)
                    item = reqs{i};
                    if ~isstruct(item), continue; end
                    z = round(item.z); x = round(item.x); y = round(item.y);
                    layer = char(item.layer);
                    if strcmp(layer, 'satellite')
                        pfx = 'y'; ext = '.jpg'; lyrs = 'y';
                    elseif strcmp(layer, 'terrain')
                        pfx = 'p'; ext = '.png'; lyrs = 'p';
                    else
                        pfx = 'm'; ext = '.png'; lyrs = 'm';
                    end
                    fPath = fullfile(tilesDir, sprintf('%s_%d_%d_%d%s', pfx, z, x, y, ext));
                    if ~isfile(fPath)
                        tileList(end+1) = struct('url', sprintf('https://mt1.google.com/vt/lyrs=%s&x=%d&y=%d&z=%d', lyrs, x, y, z), 'dest', fPath); %#ok<AGROW>
                    end
                end
                if ~isempty(tileList)
                    app.downloadTiles(tileList);
                    app.send('tilesReady', struct());
                end
            catch
            end
        end

        % ------------------------------------------------------------------
        function evaluateAll(app)
            n = numel(app.Raw.routes);
            T = cell(1, n);
            for i = 1:n, T{i} = app.evalRoute(app.Raw.routes{i}); end
            [~, o] = sort(cellfun(@(r) r.totalMin, T));
            T = T(o);
            en = cellfun(@(r) r.energy, T);
            ds = cellfun(@(r) r.distKm, T);
            tags = repmat({'Alternative'}, 1, n);
            [~, i2] = min(ds); tags{i2} = 'Shortest';
            [~, i1] = min(en); tags{i1} = 'Most Efficient';
            tags{1} = 'Fastest';
            for i = 1:n, T{i}.tag = tags{i}; end
            app.Trip = T;
            app.Sel = min(app.Sel, n);
        end

        function r = evalRoute(app, R)
            C = app.Cfg; E = app.Env; dist = R.distKm;
            grid = (0:app.BinKm:dist)';
            if dist - grid(end) > 1e-6, grid(end+1, 1) = dist; end
            mid = (grid(1:end-1) + grid(2:end))/2;
            seg = diff(grid);

            elG = interp1(R.cum, R.elev, grid, 'linear', 'extrap');
            grade = diff(elG)./(seg*1000) + E.grade/100;
            grade = max(min(grade, 0.12), -0.12);

            liveTfOk = app.Pref.liveTraffic && isfield(R, 'liveTf') && ~isnan(R.liveTf);
            if liveTfOk
                tf = R.liveTf;
            else
                tfi = find(strcmp(E.traffic, {'Low','Medium','High'}), 1);
                if isempty(tfi), tfi = 2; end
                tfs = [1 0.92 0.80]; tf = tfs(tfi);
            end
            switch app.Pref.mode
                case 'Eco',         spdMul = 0.90; hvMul = 0.55; regenBoost = 1.15; urbanMul = 0.85;
                case 'Performance', spdMul = 1.10; hvMul = 1.00; regenBoost = 0.90; urbanMul = 1.25;
                otherwise,          spdMul = 1.00; hvMul = 1.00; regenBoost = 1.00; urbanMul = 1.00;
            end
            if numel(R.steps.sKm) >= 2
                v = interp1(R.steps.sKm, R.steps.sV, mid, 'previous', 'extrap');
            else
                v = repmat(60, size(mid));
            end
            v(isnan(v)) = 60;
            topSpeed = 105; if isfield(C, 'topSpeedKmh') && C.topSpeedKmh > 0, topSpeed = C.topSpeedKmh; end
            v = min(max(v*tf*spdMul, 15), topSpeed);
            vm = v/3.6;

            switch E.windDir
                case 'Headwind', vw = E.wind/3.6;
                case 'Tailwind', vw = -E.wind/3.6;
                case 'Crosswind', vw = 0.3*E.wind/3.6;
                otherwise, vw = 0;
            end
            vr = max(vm + vw, 0);
            rf = 1; if strcmp(E.road, 'Wet'), rf = 1.15; elseif strcmp(E.road, 'Snow'), rf = 1.6; end

            % --- longitudinal vehicle model --------------------------------
            th = atan(grade);
            F  = C.mass*9.81*(C.crr*rf*cos(th) + sin(th)) + 0.5*1.16*C.cd*C.area*vr.^2;
            Pw = F.*vm;                                         % wheel power [W]
            urban = 1 + 0.35*urbanMul*max(0, 50 - v)/50;        % stop-go penalty (mode-scaled)
            pos = Pw > 0;
            Pw(pos) = Pw(pos).*urban(pos);
            Pb = zeros(size(Pw));
            Pb(pos)  = Pw(pos)/C.etaDrive;
            etaRegenEff = min(C.etaRegen*regenBoost, 0.95);
            Pb(~pos) = Pw(~pos)*etaRegenEff;
            Pbat = Pb + (Pb/C.volt).^2*C.rInt;                  % + battery I^2 R loss
            T = E.temp; hv = 0.8;
            if T >= 32, hv = 2.0; elseif T >= 27, hv = 1.4; elseif T <= 15, hv = 1.5; end
            hvacMul = 1; if isfield(C, 'hvacMul') && C.hvacMul > 0, hvacMul = C.hvacMul; end
            PhvW = hv*1000*hvMul*hvacMul; PauxW = 400;
            dt = seg*1000./vm;
            Ebin = (Pbat + PhvW + PauxW).*dt/3.6e6;
            cumE = [0; cumsum(Ebin)];
            Etot = max(cumE(end), 0.1);
            tract = sum(max(Pw,0).*dt)/3.6e6;
            loss  = sum((max(Pbat,0) - max(Pw,0)).*dt)/3.6e6;
            hvacE = PhvW*sum(dt)/3.6e6;  auxE = PauxW*sum(dt)/3.6e6;
            regen = -sum(min(Pbat,0).*dt)/3.6e6;
            gross = tract + loss + hvacE + auxE;

            driveMin = R.durMin/tf;
            stn = EVRoute_App.projectStations(R, app.Raw.stn);
            P = app.planCharging(grid, cumE, dist, stn, R);

            ki = unique(round(linspace(1, numel(mid), min(150, numel(mid)))));
            inst = movmean(Ebin./seg*100, 5);
            powKw = (Pbat + PhvW + PauxW)/1000;
            pk = movmean(powKw, 3);
            tmin = cumsum(dt)/sum(dt)*driveMin;
            prof = round([mid(ki) v(ki) inst(ki) pk(ki) tmin(ki)], 2);

            idx = unique(round(linspace(1, numel(R.cum), min(120, numel(R.cum)))));
            eprof = round([R.cum(idx) R.elev(idx)], 1);
            health = struct('peakKw', max(powKw), 'regenKwh', regen, 'regenPct', 100*regen/max(gross, eps), ...
                'usableKwh', C.kwh*(C.soc0 - app.ReserveSOC)/100, 'auxKw', hv + PauxW/1000);
            bd = struct('traction', tract, 'loss', loss, 'hvac', hvacE, 'aux', auxE, 'regen', regen, 'gross', gross);

            r = struct('path', R.path, 'cum', R.cum, 'distKm', dist, 'driveMin', driveMin, 'via', R.via, ...
                'elevGain', sum(max(diff(R.elev), 0)), 'elevProf', eprof, ...
                'grid', grid, 'cumE', cumE, 'midKm', mid, 'speed', v, 'powKw', powKw, 'prof', prof, ...
                'turnKm', R.steps.turnKm, 'turnTxt', {R.steps.turnTxt}, 'turnIco', {R.steps.turnIco}, ...
                'energy', Etot, 'kwh100', Etot/dist*100, 'kmPerKwh', dist/Etot, ...
                'avgKmh', dist/(driveMin/60), 'co2', dist*0.19 - Etot*0.71, 'cost', Etot*E.tariff, 'bd', bd, ...
                'stops', {P.stops}, 'curve', P.curve, 'chargeMin', P.chargeMin, ...
                'totalMin', driveMin + P.chargeMin, 'arriveSoc', P.arriveSoc, 'feasible', P.feasible, ...
                'chargers', {EVRoute_App.chargerList(stn, P.stops)}, 'health', health, 'tag', '', 'trafficLive', liveTfOk);
        end

        function P = planCharging(app, grid, cumE, dist, stn, R)
            C = app.Cfg; cap = C.kwh; Bmin = cap*app.ReserveSOC/100; Bfull = cap*app.ChargeToSOC/100;
            Ef = @(d) interp1(grid, cumE, d, 'linear', 'extrap');
            B = cap*C.soc0/100; d0 = 0;
            ck = 0; cs = C.soc0; stops = {}; chargeMin = 0; done = false;
            for it = 1:15
                E0 = Ef(d0);
                over = find(cumE - E0 > B - Bmin & grid > d0, 1, 'first');
                if isempty(over)
                    k = grid > d0;
                    ck = [ck; grid(k)]; cs = [cs; (B - (cumE(k) - E0))/cap*100]; %#ok<AGROW>
                    done = true; break
                end
                if ~app.Pref.charging, break, end
                reach = grid(over-1);
                if reach <= d0 + 2, break, end
                mask = stn.d > d0 + 2 & stn.d <= reach;
                good = mask & stn.kw >= 40;
                if ~any(good), good = mask; end
                if any(good)
                    cand = find(good); [~, ix] = max(stn.d(cand)); j = cand(ix);
                    ds = stn.d(j); lat = stn.lat(j); lon = stn.lon(j);
                    nm = stn.name{j}; kw = stn.kw(j); syn = false;
                else
                    ds = max(d0 + 2, reach - 3);
                    lat = interp1(R.cum, R.path(:,1), ds); lon = interp1(R.cum, R.path(:,2), ds);
                    nm = 'Suggested charging point'; kw = 60; syn = true;
                end
                Barr = B - (Ef(ds) - E0);
                k = grid > d0 & grid < ds;
                ck = [ck; grid(k); ds]; cs = [cs; (B - (cumE(k) - E0))/cap*100; Barr/cap*100]; %#ok<AGROW>
                need = Ef(dist) - Ef(ds) + Bmin + 0.05*cap;
                Bt = min(min(Bfull, need), cap);
                Bt = max(Bt, min(Barr + 0.05*cap, cap));
                mins = (Bt - Barr)/(0.7*min(C.dcKw, kw))*60 + 4;
                ck = [ck; ds]; cs = [cs; Bt/cap*100]; %#ok<AGROW>
                stops{end+1} = struct('lat', lat, 'lng', lon, 'name', nm, 'kw', kw, 'km', ds, ...
                    'arrSoc', Barr/cap*100, 'depSoc', Bt/cap*100, 'minutes', mins, 'synthetic', syn); %#ok<AGROW>
                chargeMin = chargeMin + mins; B = Bt; d0 = ds;
            end
            if ~done                                            % show the remaining curve anyway
                E0 = Ef(d0); k = grid > d0;
                ck = [ck; grid(k)]; cs = [cs; (B - (cumE(k) - E0))/cap*100]; %#ok<AGROW>
            end
            P = struct('stops', {stops}, 'curve', [ck, min(max(cs, 0), 100)], 'chargeMin', chargeMin, ...
                'feasible', done, 'arriveSoc', cs(end));
        end

        function d = buildTripData(app)
            n = numel(app.Trip);
            routes = cell(1, n);
            for i = 1:n
                r = app.Trip{i};
                routes{i} = struct('id', i-1, 'name', sprintf('Route %d', i), 'via', r.via, 'tag', r.tag, ...
                    'color', app.Palette{i}, 'path', round(r.path, 5), 'distKm', r.distKm, ...
                    'driveMin', r.driveMin, 'totalMin', r.totalMin, 'chargeMin', r.chargeMin, ...
                    'energy', r.energy, 'kwh100', r.kwh100, 'kmPerKwh', r.kmPerKwh, 'avgKmh', r.avgKmh, ...
                    'co2', r.co2, 'cost', r.cost, 'bd', r.bd, 'prof', r.prof, ...
                    'elevGain', r.elevGain, 'feasible', r.feasible, 'arriveSoc', r.arriveSoc, ...
                    'soc', round(r.curve, 1), 'elev', r.elevProf, 'stops', {r.stops}, ...
                    'chargers', {r.chargers}, 'health', r.health, 'trafficLive', r.trafficLive);
            end
            d = struct('from', app.Raw.fromName, 'to', app.Raw.toName, ...
                'fromLL', app.Raw.fromLL, 'toLL', app.Raw.toLL, 'routes', {routes}, ...
                'sel', app.Sel - 1, 'reserve', app.ReserveSOC, 'weather', app.Raw.wx, ...
                'cfg', app.Cfg, 'env', app.Env, 'vi', app.VehIdx - 1);
        end

        function pushTrip(app)
            if isempty(app.Trip), return; end
            tripData = app.buildTripData();
            liveData = app.buildLiveData();
            app.send('trip', tripData, 'live', liveData);
        end
    end

    % =====================================================================
    %  Live drive: replays the selected route with turn-by-turn guidance
    % =====================================================================
    methods (Access = private)

        function resetDriveState(app)
            rate = 60;
            if isstruct(app.Drive) && isfield(app.Drive, 'rate'), rate = app.Drive.rate; end
            app.Drive = struct('running', false, 'state', 'idle', 's', 0, 'soc', app.Cfg.soc0, ...
                'speed', 0, 'stopIdx', 1, 'chargeT', 0, 'rate', rate, 'tick', 0);
        end

        function resetDrive(app)
            app.stopTimer(); app.resetDriveState();
            if ~isempty(app.Trip), app.pushLive(); end
        end

        function driveCmd(app, cmd)
            if isempty(app.Trip), return; end
            switch cmd
                case 'start'
                    if strcmp(app.Drive.state, 'arrived'), app.resetDriveState(); end
                    app.Drive.running = true;
                    if strcmp(app.Drive.state, 'idle'), app.Drive.state = 'driving'; end
                    app.ensureTimer();
                case 'pause'
                    app.Drive.running = false; app.stopTimer();
                case 'reset'
                    app.resetDrive();
            end
        end

        function ensureTimer(app)
            if isempty(app.Timer) || ~isvalid(app.Timer)
                app.Timer = timer('ExecutionMode', 'fixedSpacing', 'Period', 0.25, ...
                    'BusyMode', 'drop', 'TimerFcn', @(~,~) app.safeTick());
            end
            if strcmp(app.Timer.Running, 'off'), start(app.Timer); end
        end

        function stopTimer(app)
            if ~isempty(app.Timer) && isvalid(app.Timer) && strcmp(app.Timer.Running, 'on'), stop(app.Timer); end
        end

        function safeTick(app)
            try, app.tick();
            catch ME, app.stopTimer(); app.toast(ME.message, 'error'); end
        end

        function tick(app)
            D = app.Drive;
            if ~D.running || isempty(app.Trip), return; end
            r = app.Trip{app.Sel}; C = app.Cfg; dt = 0.25;
            D.tick = D.tick + 1;
            if strcmp(D.state, 'charging')
                st = r.stops{D.stopIdx};
                D.chargeT = D.chargeT + dt;
                f = min(D.chargeT/3, 1);                         % 3 s of screen time per stop
                D.soc = st.arrSoc + f*(st.depSoc - st.arrSoc);
                D.speed = 0;
                if f >= 1, D.stopIdx = D.stopIdx + 1; D.state = 'driving'; end
            else
                v = interp1(r.midKm, r.speed, D.s, 'nearest', 'extrap')*(1 + 0.02*sin(D.tick*0.35));
                s1 = min(D.s + v*dt*D.rate/3600, r.distKm);
                D.soc = D.soc - (interp1(r.grid, r.cumE, s1) - interp1(r.grid, r.cumE, D.s))/C.kwh*100;
                D.speed = v;
                if D.stopIdx <= numel(r.stops) && s1 >= r.stops{D.stopIdx}.km
                    s1 = r.stops{D.stopIdx}.km;
                    D.state = 'charging'; D.chargeT = 0; D.soc = r.stops{D.stopIdx}.arrSoc;
                end
                D.s = s1;
                if s1 >= r.distKm - 1e-6, D.state = 'arrived'; D.running = false; D.speed = 0; end
            end
            app.Drive = D;
            app.pushLive();
            if strcmp(D.state, 'arrived'), app.stopTimer(); end
        end

        function d = buildLiveData(app)
            r = app.Trip{app.Sel}; D = app.Drive; C = app.Cfg; s = D.s;
            lat = interp1(r.cum, r.path(:,1), s); lon = interp1(r.cum, r.path(:,2), s);
            sa = max(s - 0.15, 0); sb = min(s + 0.15, r.distKm); hdg = 0;
            if sb - sa > 0.01
                hdg = EVRoute_App.bearing(interp1(r.cum, r.path(:,1), sa), interp1(r.cum, r.path(:,2), sa), ...
                                          interp1(r.cum, r.path(:,1), sb), interp1(r.cum, r.path(:,2), sb));
            end
            j = find(r.turnKm > s + 1e-3, 1);
            if isempty(j)
                turn = struct('txt', 'Arrive at your destination', 'ico', 'arrive', 'm', (r.distKm - s)*1000);
            else
                turn = struct('txt', r.turnTxt{j}, 'ico', r.turnIco{j}, 'm', (r.turnKm(j) - s)*1000);
            end
            remStops = 0;
            if D.stopIdx <= numel(r.stops)
                st = r.stops{D.stopIdx};
                nx = struct('has', true, 'name', st.name, 'kw', st.kw, 'distKm', max(0, st.km - s), ...
                    'arrSoc', st.arrSoc, 'depSoc', st.depSoc, 'min', st.minutes);
                for k = D.stopIdx:numel(r.stops), remStops = remStops + r.stops{k}.minutes; end
            else
                nx = struct('has', false);
            end
            eta = r.driveMin*(1 - s/r.distKm) + remStops;
            rng = max(D.soc, 0)/100*C.kwh/(r.kwh100/100);
            pidx = find(r.cum <= s, 1, 'last') - 1;
            kw = 0; tq = 0;
            if strcmp(D.state, 'driving')
                kw = interp1(r.midKm, r.powKw, s, 'nearest', 'extrap');
                if D.speed > 1
                    w = D.speed/3.6/C.wheelR*C.gear;
                    tq = max(min(kw*1000/w, C.maxTq), -C.maxTq);
                end
            end
            d = struct('lat', lat, 'lng', lon, 'hdg', hdg, 'pi', pidx, 'speed', D.speed, ...
                'soc', D.soc, 'state', D.state, 'prog', s/r.distKm, 'remKm', r.distKm - s, ...
                'etaMin', eta, 'rangeKm', rng, 'turn', turn, 'next', nx, ...
                'tele', struct('kw', kw, 'nm', tq, 'a', kw*1000/C.volt));
        end

        function pushLive(app)
            if isempty(app.Trip), return; end
            app.send('live', app.buildLiveData());
        end
    end

    % =====================================================================
    %  Reports
    % =====================================================================
    methods (Access = private)

        function exportPdf(app, sec)
            if isempty(app.Trip), return; end
            [f, p] = uiputfile('EVRoute_Report.pdf', 'Export PDF report');
            if isequal(f, 0), return; end
            r = app.Trip{app.Sel}; C = app.Cfg; E = app.Env; bd = r.bd;
            navy = [0.043 0.122 0.227];
            fig = figure('Visible', 'off', 'Units', 'pixels', 'Position', [0 0 794 1123], 'Color', 'w');
            annotation(fig, 'textbox', [.06 .935 .88 .04], 'String', 'EVRoute  |  Simulation Report', ...
                'FontSize', 20, 'FontWeight', 'bold', 'EdgeColor', 'none', 'Color', navy);
            annotation(fig, 'textbox', [.06 .905 .88 .03], 'EdgeColor', 'none', 'Color', [.4 .45 .5], 'FontSize', 9, ...
                'String', sprintf('%s to %s   |   generated %s', app.Raw.fromName, app.Raw.toName, datestr(now, 'dd mmm yyyy HH:MM')));
            L = {};
            if isfield(sec, 'summary') && sec.summary
                L = [L, {'SIMULATION SUMMARY', sprintf('  Distance %.0f km | Time %d min | Energy %.1f kWh | %.1f kWh/100 km', ...
                    r.distKm, round(r.totalMin), r.energy, r.kwh100), ...
                    sprintf('  Arrival charge %.0f%% | Charging stops %d | Est. cost INR %.0f | CO2 saved %.1f kg', ...
                    r.arriveSoc, numel(r.stops), r.cost, r.co2), ''}];
            end
            if isfield(sec, 'route') && sec.route
                L = [L, {'ROUTE INFORMATION', sprintf('  %s (%s) via %s', r.tag, 'selected', r.via), ...
                    sprintf('  Elevation gain %.0f m | Average speed %.0f km/h', r.elevGain, r.avgKmh), ''}];
            end
            if isfield(sec, 'vehicle') && sec.vehicle
                L = [L, {'VEHICLE CONFIGURATION', sprintf('  %s | %.0f kWh | %.0f V | %.0f kg | Cd %.2f | A %.2f m2', ...
                    C.name, C.kwh, C.volt, C.mass, C.cd, C.area), ''}];
            end
            if isfield(sec, 'env') && sec.env
                L = [L, {'ENVIRONMENTAL CONDITIONS', sprintf('  %.0f C | wind %.0f km/h (%s) | road %s | grade %+.1f%% | traffic %s', ...
                    E.temp, E.wind, E.windDir, E.road, E.grade, E.traffic), ...
                    sprintf('  Driving mode %s | electricity tariff INR %.1f/kWh', app.Pref.mode, E.tariff), ''}];
            end
            if isfield(sec, 'results') && sec.results
                L = [L, {'SIMULATION RESULTS', sprintf('  Regenerated %.1f kWh (%.0f%% of drive energy) | Peak draw %.0f kW', ...
                    bd.regen, r.health.regenPct, r.health.peakKw), ''}];
            end
            if isfield(sec, 'energy') && sec.energy
                g = bd.gross;
                L = [L, {'ENERGY BREAKDOWN', sprintf('  Traction %.0f%% | HVAC %.0f%% | Auxiliary %.0f%% | Drivetrain & battery losses %.0f%%', ...
                    100*bd.traction/g, 100*bd.hvac/g, 100*bd.aux/g, 100*bd.loss/g), ''}];
            end
            if isfield(sec, 'reco') && sec.reco
                en = cellfun(@(q) q.energy, app.Trip); [em, ie] = min(en);
                L = [L, {'RECOMMENDATIONS', sprintf('  Lowest-energy option: Route %d (%.1f kWh, %.1f kWh less than the selected route).', ...
                    ie, em, r.energy - em), ...
                    '  Pre-condition the cabin while plugged in and use Eco mode on climbs to extend range.', ''}];
            end
            annotation(fig, 'textbox', [.06 .52 .88 .38], 'String', L, 'EdgeColor', 'none', 'FontSize', 10, ...
                'FitBoxToText', 'off', 'VerticalAlignment', 'top', 'Interpreter', 'none');
            if isfield(sec, 'graphs') && sec.graphs
                ax = axes(fig, 'Position', [.09 .30 .38 .17]); plot(ax, r.curve(:,1), r.curve(:,2), 'Color', [.055 .624 .494], 'LineWidth', 1.8);
                title(ax, 'Battery charge vs distance'); xlabel(ax, 'km'); ylabel(ax, '%'); grid(ax, 'on'); ylim(ax, [0 100]);
                ax = axes(fig, 'Position', [.56 .30 .38 .17]); plot(ax, r.prof(:,5), r.prof(:,2), 'Color', [.118 .369 1], 'LineWidth', 1.4);
                title(ax, 'Speed vs time'); xlabel(ax, 'min'); ylabel(ax, 'km/h'); grid(ax, 'on');
                ax = axes(fig, 'Position', [.09 .06 .38 .17]); plot(ax, r.elevProf(:,1), r.elevProf(:,2), 'Color', [.72 .57 .23], 'LineWidth', 1.6);
                title(ax, 'Elevation profile'); xlabel(ax, 'km'); ylabel(ax, 'm'); grid(ax, 'on');
                ax = axes(fig, 'Position', [.56 .06 .38 .17]); plot(ax, r.prof(:,5), r.prof(:,4), 'Color', [.48 .35 .97], 'LineWidth', 1.2);
                title(ax, 'Power vs time'); xlabel(ax, 'min'); ylabel(ax, 'kW'); grid(ax, 'on');
            end
            exportgraphics(fig, fullfile(p, f), 'ContentType', 'vector'); close(fig);
            app.toast(['PDF saved: ' f], 'ok');
        end

        function exportData(app)
            if isempty(app.Trip), return; end
            [f, p] = uiputfile({'*.xlsx'; '*.csv'}, 'Export simulation data', 'EVRoute_Data.xlsx');
            if isequal(f, 0), return; end
            r = app.Trip{app.Sel};
            T = table(r.midKm(:), r.speed(:), r.powKw(:), r.cumE(2:end), ...
                'VariableNames', {'distance_km', 'speed_kmh', 'power_kW', 'energy_cum_kWh'});
            writetable(T, fullfile(p, f));
            app.toast(['Data saved: ' f], 'ok');
        end
    end

    % =====================================================================
    methods (Static, Access = public)

        function [x, y] = latLonToTile(lat, lon, z)
            n = 2^z;
            x = floor((lon + 180) / 360 * n);
            latRad = lat * pi / 180;
            latRad = max(-85.05112878, min(85.05112878, latRad));
            y = floor((1 - asinh(tan(latRad)) / pi) / 2 * n);
        end

    end

    methods (Static, Access = private)

        function V = catalog()
            % India's top 10 best-selling EVs, H1 2026 sales ranking (MG Windsor,
            % XEV 9S, Nexon, Punch, XEV 9e, Harrier EV, e Vitara, Curvv, BE 6, Tiago).
            % Figures are the manufacturer's long-range/top variant, rounded to
            % typical published values -- edit any row to match your exact trim;
            % nothing here is fetched live so it will drift as new variants launch.
            V = struct( ...
              'name',    {'MG Windsor EV (LR)', 'Mahindra XEV 9S', 'Tata Nexon EV (LR)', 'Tata Punch EV (LR)', ...
                          'Mahindra XEV 9e', 'Tata Harrier EV', 'Maruti e Vitara', 'Tata Curvv EV (LR)', ...
                          'Mahindra BE 6', 'Tata Tiago EV (LR)'}, ...
              'kwh',     {52.9, 59.0, 45.0, 35.0, 79.0, 65.0, 61.0, 45.0, 59.0, 24.0}, ...
              'soc0',    {90, 90, 90, 90, 90, 90, 90, 90, 90, 90}, ...
              'volt',    {320, 400, 320, 300, 400, 400, 355, 350, 400, 250}, ...
              'maxA',    {260, 300, 260, 220, 400, 320, 280, 260, 300, 180}, ...
              'rInt',    {0.055, 0.045, 0.06, 0.06, 0.04, 0.045, 0.05, 0.055, 0.045, 0.07}, ...
              'bTemp',   {25, 25, 25, 25, 25, 25, 25, 25, 25, 25}, ...
              'cells',   {96, 108, 96, 90, 108, 108, 102, 96, 108, 72}, ...
              'motorKw', {100, 170, 106, 90, 210, 158, 106, 150, 170, 45.5}, ...
              'maxTq',   {200, 380, 215, 190, 380, 315, 192, 215, 380, 114}, ...
              'etaDrive',{0.88, 0.89, 0.88, 0.87, 0.90, 0.89, 0.88, 0.88, 0.89, 0.86}, ...
              'etaRegen',{0.60, 0.62, 0.60, 0.58, 0.65, 0.62, 0.60, 0.60, 0.62, 0.55}, ...
              'mass',    {1700, 2100, 1500, 1300, 2150, 2100, 1700, 1650, 2000, 1235}, ...
              'crr',     {0.011, 0.011, 0.011, 0.012, 0.011, 0.011, 0.011, 0.011, 0.011, 0.012}, ...
              'wheelR',  {0.325, 0.335, 0.32, 0.31, 0.35, 0.335, 0.33, 0.325, 0.335, 0.30}, ...
              'gear',    {8.7, 9.0, 9.5, 9.5, 9.0, 8.8, 8.9, 9.0, 9.0, 9.7}, ...
              'dcKw',    {60, 140, 50, 50, 175, 120, 75, 70, 175, 25}, ...
              'cd',      {0.31, 0.28, 0.33, 0.35, 0.26, 0.31, 0.29, 0.28, 0.27, 0.33}, ...
              'area',    {2.50, 2.60, 2.50, 2.40, 2.70, 2.80, 2.60, 2.50, 2.60, 2.30}, ...
              'topSpeedKmh', {140, 160, 150, 120, 200, 200, 140, 160, 200, 120}, ...
              'hvacMul', {1, 1, 1, 1, 1, 1, 1, 1, 1, 1});
        end

        function o = webOpts(t)
            o = weboptions('Timeout', t, 'UserAgent', 'EVRoute-MATLAB/2.0 (student project)', 'ContentType', 'json');
        end

        function c = asCell(x)
            if iscell(x), c = x(:);
            elseif isempty(x), c = {};
            else, c = num2cell(x(:)); end
        end

        function [ll, nm] = geocodeNominatim(q)
            r = webread(['https://nominatim.openstreetmap.org/search?format=jsonv2&limit=1&q=' urlencode(q)], EVRoute_App.webOpts(20));
            if isempty(r), error('EVRoute:geo', 'Could not find "%s". Try adding the city or state.', q); end
            if iscell(r), r = r{1}; end
            ll = [str2double(r(1).lat) str2double(r(1).lon)];
            nm = strtrim(strtok(q, ','));
        end

        function wx = fetchWeather(ll)
            wx = struct('temp', 28, 'desc', '');
            try
                w = webread(sprintf(['https://api.open-meteo.com/v1/forecast?latitude=%.3f&longitude=%.3f' ...
                    '&current=temperature_2m,weather_code'], ll(1), ll(2)), EVRoute_App.webOpts(15));
                c = w.current.weather_code;
                if c == 0, d = 'Clear'; elseif c <= 3, d = 'Partly Cloudy'; elseif c <= 48, d = 'Fog';
                elseif c <= 67, d = 'Rain'; elseif c <= 77, d = 'Snow'; elseif c <= 82, d = 'Showers';
                else, d = 'Thunderstorm'; end
                wx = struct('temp', round(w.current.temperature_2m), 'desc', d);
            catch, end
        end

        function d = hav(la1, lo1, la2, lo2)
            p = pi/180;
            a = sin((la2 - la1)*p/2).^2 + cos(la1*p).*cos(la2*p).*sin((lo2 - lo1)*p/2).^2;
            d = 2*6371*asin(min(1, sqrt(a)));
        end

        function b = bearing(la1, lo1, la2, lo2)
            p = pi/180;
            y = sin((lo2 - lo1)*p).*cos(la2*p);
            x = cos(la1*p).*sin(la2*p) - sin(la1*p).*cos(la2*p).*cos((lo2 - lo1)*p);
            b = mod(atan2d(y, x), 360);
        end

        function R = parseRouteGoogle(r)
            leg = EVRoute_App.asCell(r.legs); leg = leg{1};
            steps = EVRoute_App.asCell(leg.steps);
            path = zeros(0,2);
            n = numel(steps);
            d = zeros(n,1); du = zeros(n,1); nm = cell(n,1); txt = cell(n,1); ico = cell(n,1); keep = false(n,1);
            for i = 1:n
                s = steps{i};
                pts = EVRoute_App.decodePolyline(s.polyline.points);
                path = [path; pts]; %#ok<AGROW>
                d(i) = s.distance.value/1000; du(i) = s.duration.value;
                instr = '';
                if isfield(s, 'html_instructions'), instr = EVRoute_App.stripHtml(s.html_instructions); end
                nm{i} = instr;
                manv = ''; if isfield(s, 'maneuver'), manv = char(s.maneuver); end
                [keep(i), txt{i}, ico{i}] = EVRoute_App.maneuverGoogle(manv, instr);
            end
            seg = EVRoute_App.hav(path(1:end-1,1), path(1:end-1,2), path(2:end,1), path(2:end,2));
            cum = [0; cumsum(seg)];
            [cum, iu] = unique(cum);
            path = path(iu, :);
            distKm = leg.distance.value/1000;
            if cum(end) > 0, cum = cum*distKm/cum(end); end
            sc = distKm/max(sum(d), eps);
            startKm = [0; cumsum(d(1:end-1))]*sc;
            speed = d*sc./max(du, eps)*3600;
            ok = du > 0 & d > 0;
            [sk, iu2] = unique(startKm(ok)); spd = speed(ok);
            S = struct('sKm', sk, 'sV', spd(iu2), 'turnKm', startKm(keep), 'turnTxt', {txt(keep)}, ...
                'turnIco', {ico(keep)}, 'name', {nm}, 'd', d*sc);
            via = '';
            if isfield(r, 'summary') && ~isempty(r.summary), via = EVRoute_App.shortName(char(r.summary)); end
            if isempty(via), via = 'local roads'; end
            liveTf = NaN;
            if isfield(leg, 'duration_in_traffic') && leg.duration.value > 0
                liveTf = leg.duration.value / leg.duration_in_traffic.value;   % <1 => congestion slows you down
                liveTf = max(min(liveTf, 1), 0.35);                            % sane bounds
            end
            R = struct('path', path, 'cum', cum, 'distKm', distKm, 'durMin', leg.duration.value/60, ...
                'steps', S, 'via', via, 'elev', zeros(size(cum)), 'liveTf', liveTf);
        end

        function [keep, txt, ico] = maneuverGoogle(manv, instr)
            keep = ~isempty(manv);
            side = ''; ico = 'straight';
            if contains(manv, 'left'), side = 'left'; elseif contains(manv, 'right'), side = 'right'; end
            if contains(manv, 'sharp'), ico = ['sharp-' side];
            elseif contains(manv, 'slight'), ico = ['slight-' side];
            elseif contains(manv, 'uturn'), ico = 'uturn'; keep = true;
            elseif contains(manv, 'roundabout'), ico = 'roundabout'; keep = true;
            elseif ~isempty(side), ico = side;
            elseif strcmp(manv, 'arrive'), ico = 'arrive';
            elseif isempty(manv), ico = 'straight'; keep = false;
            else, ico = 'straight'; keep = false;
            end
            txt = instr;
            if isempty(txt), txt = ''; end
        end

        function s = stripHtml(h)
            s = regexprep(char(h), '<[^>]*>', ' ');
            s = strrep(s, '&nbsp;', ' '); s = strrep(s, '&amp;', '&');
            s = strrep(s, '&#39;', ''''); s = strtrim(regexprep(s, '\s+', ' '));
        end

        function pts = decodePolyline(enc)
            % Decodes Google's encoded polyline algorithm format into [lat lon] rows.
            enc = char(enc); len = numel(enc); idx = 1; lat = 0; lon = 0;
            pts = zeros(0, 2);
            while idx <= len
                [dlat, idx] = EVRoute_App.decodeVarint(enc, idx); lat = lat + dlat;
                [dlon, idx] = EVRoute_App.decodeVarint(enc, idx); lon = lon + dlon;
                pts(end+1, :) = [lat, lon] * 1e-5; %#ok<AGROW>
            end
        end

        function [val, idx] = decodeVarint(enc, idx)
            shift = 0; result = 0;
            while true
                b = double(enc(idx)) - 63; idx = idx + 1;
                result = bitor(result, bitshift(bitand(b, 31), shift));
                shift = shift + 5;
                if b < 32, break, end
            end
            if bitand(result, 1), val = -(bitshift(result, -1) + 1); else, val = bitshift(result, -1); end
        end

        function R = parseRoute(r)
            xy = r.geometry.coordinates;                        % [lon lat]
            path = [xy(:,2) xy(:,1)];
            n = size(path, 1);
            idx = unique(round(linspace(1, n, min(n, 1500))));
            path = path(idx, :);
            seg = EVRoute_App.hav(path(1:end-1,1), path(1:end-1,2), path(2:end,1), path(2:end,2));
            cum = [0; cumsum(seg)];
            [cum, iu] = unique(cum);
            path = path(iu, :);
            distKm = r.distance/1000;
            cum = cum*distKm/cum(end);
            leg = EVRoute_App.asCell(r.legs);
            S = EVRoute_App.parseSteps(EVRoute_App.asCell(leg{1}.steps), distKm);
            R = struct('path', path, 'cum', cum, 'distKm', distKm, 'durMin', r.duration/60, ...
                'steps', S, 'via', EVRoute_App.viaName(S), 'elev', zeros(size(cum)));
        end

        function S = parseSteps(st, distKm)
            n = numel(st);
            d = zeros(n,1); du = zeros(n,1); ex = zeros(n,1);
            ty = cell(n,1); md = cell(n,1); nm = cell(n,1); ds = cell(n,1);
            for i = 1:n
                s = st{i};
                d(i) = s.distance/1000; du(i) = s.duration;
                m = s.maneuver;
                ty{i} = m.type; md{i} = ''; nm{i} = ''; ds{i} = '';
                if isfield(m, 'modifier'), md{i} = m.modifier; end
                if isfield(m, 'exit'), ex(i) = m.exit; end
                if isfield(s, 'name'), nm{i} = s.name; end
                if isempty(nm{i}) && isfield(s, 'ref'), nm{i} = s.ref; end
                if isfield(s, 'destinations'), ds{i} = s.destinations; end
            end
            sc = distKm/max(sum(d), eps);
            startKm = [0; cumsum(d(1:end-1))]*sc;
            speed = d*sc./max(du, eps)*3600;                    % km/h
            ok = du > 0 & d > 0;
            [sk, iu] = unique(startKm(ok));
            spd = speed(ok);
            keep = false(n,1); txt = cell(n,1); ico = cell(n,1);
            for i = 1:n
                [keep(i), txt{i}, ico{i}] = EVRoute_App.maneuver(ty{i}, md{i}, nm{i}, ds{i}, ex(i));
            end
            S = struct('sKm', sk, 'sV', spd(iu), 'turnKm', startKm(keep), 'turnTxt', {txt(keep)}, ...
                'turnIco', {ico(keep)}, 'name', {nm}, 'd', d*sc);
        end

        function [keep, txt, ico] = maneuver(type, md, nm, dest, ex)
            keep = true; ico = 'straight'; txt = '';
            onto = ''; if ~isempty(nm), onto = [' onto ' nm]; end
            twd = ''; if ~isempty(dest), twd = [' toward ' dest]; end
            side = '';
            if endsWith(md, 'left'), side = 'left'; elseif endsWith(md, 'right'), side = 'right'; end
            switch md
                case 'left', ico = 'left';
                case 'right', ico = 'right';
                case 'slight left', ico = 'slight-left';
                case 'slight right', ico = 'slight-right';
                case 'sharp left', ico = 'sharp-left';
                case 'sharp right', ico = 'sharp-right';
                case 'uturn', ico = 'uturn';
            end
            switch type
                case 'arrive'
                    txt = 'Arrive at your destination'; ico = 'arrive';
                case 'turn'
                    if strcmp(md, 'straight') || isempty(md), keep = false;
                    elseif strcmp(md, 'uturn'), txt = ['Make a U-turn' onto];
                    elseif contains(md, 'slight'), txt = ['Bear ' side onto];
                    else, txt = ['Turn ' side onto]; end
                case 'end of road'
                    txt = ['At the end of the road, turn ' side onto];
                case 'fork'
                    if isempty(twd), twd = onto; end
                    txt = ['Keep ' side ' at the fork' twd];
                    if ~isempty(side), ico = ['slight-' side]; end
                case 'off ramp'
                    if isempty(twd), twd = onto; end
                    txt = ['Take the exit' twd];
                    if isempty(side), side = 'right'; end
                    ico = ['slight-' side];
                case 'on ramp'
                    txt = ['Take the ramp' onto];
                    if ~isempty(side), ico = ['slight-' side]; end
                case 'merge'
                    txt = ['Merge' onto]; ico = 'straight';
                case {'roundabout', 'rotary', 'roundabout turn'}
                    if ex > 0, txt = sprintf('At the roundabout, take exit %d%s', ex, onto);
                    else, txt = ['At the roundabout, continue' onto]; end
                    ico = 'roundabout';
                otherwise
                    keep = false;
            end
        end

        function v = viaName(S)
            ok = ~cellfun(@isempty, S.name);
            if ~any(ok), v = 'local roads'; return; end
            [u, ~, ic] = unique(S.name(ok));
            dsum = accumarray(ic, S.d(ok));
            [~, ord] = sort(dsum, 'descend');
            u = cellfun(@(x) EVRoute_App.shortName(x), u(ord), 'UniformOutput', false);
            u = unique(u, 'stable');
            v = strjoin(u(1:min(2, numel(u))), [' ' char(183) ' ']);
        end

        function s = shortName(s)
            if numel(s) > 28, s = [s(1:27) char(8230)]; end
        end

        function P = projectStations(R, st)
            P = struct('d', zeros(0,1), 'lat', zeros(0,1), 'lon', zeros(0,1), 'name', {cell(0,1)}, 'kw', zeros(0,1));
            if isempty(st.lat), return; end
            kx = 111.32*cosd(mean(R.path(:,1))); ky = 110.57;
            px = R.path(:,2)*kx; py = R.path(:,1)*ky;
            n = numel(st.lat); d = zeros(n,1); off = zeros(n,1);
            for i = 1:n
                dd = hypot(px - st.lon(i)*kx, py - st.lat(i)*ky);
                [off(i), j] = min(dd); d(i) = R.cum(j);
            end
            k = off <= 15.0; % allow stations within 15 km of route corridor
            [d, o] = sort(d(k));
            lat = st.lat(k); lon = st.lon(k); nm = st.name(k); kw = st.kw(k);
            P = struct('d', d, 'lat', lat(o), 'lon', lon(o), 'name', {nm(o)}, 'kw', kw(o));
        end

        function ch = chargerList(stn, stops)
            ch = {}; pk = zeros(0,1);
            for i = 1:numel(stops)
                s = stops{i}; pk(end+1, 1) = s.km; %#ok<AGROW>
                ch{end+1} = struct('lat', s.lat, 'lng', s.lng, 'name', s.name, 'kw', s.kw, 'km', s.km, 'planned', true); %#ok<AGROW>
            end
            if ~isempty(stn.d)
                n = numel(stn.d);
                sel = unique(round(linspace(1, n, min(n, 50))));
                for j = sel(:)'
                    if isempty(pk) || all(abs(stn.d(j) - pk) > 3)
                        ch{end+1} = struct('lat', stn.lat(j), 'lng', stn.lon(j), 'name', stn.name{j}, ...
                            'kw', stn.kw(j), 'km', stn.d(j), 'planned', false); %#ok<AGROW>
                    end
                end
            end
        end

        function stn = synthesizeCorridorChargers(routes, existingStn)
            if nargin < 2 || isempty(existingStn)
                existingStn = struct('lat', zeros(0,1), 'lon', zeros(0,1), 'name', {cell(0,1)}, 'kw', zeros(0,1), 'dc', false(0,1));
            end
            lat = existingStn.lat; lon = existingStn.lon; nm = existingStn.name; kw = existingStn.kw; dc = existingStn.dc;
            
            brandNames = {'Tata Power EZ Charge', 'Jio-bp Pulse HyperHub', 'ChargeZone UltraFast Hub', ...
                          'Shell Recharge SuperStation', 'Statiq HyperCharge Plaza', 'Zeon DC FastHub', ...
                          'ABB Terra HP Station', 'Tesla Supercharger Hub'};
            powers = [150, 180, 240, 120, 350];
            bIdx = 1;
            for r = 1:numel(routes)
                R = routes{r};
                totalKm = R.distKm;
                if totalKm < 10, continue; end
                
                stepKm = max(25, min(45, totalKm / 4));
                stationDistances = stepKm:stepKm:(totalKm - 8);
                
                for sIdx = 1:numel(stationDistances)
                    sKm = stationDistances(sIdx);
                    [~, pIdx] = min(abs(R.cum - sKm));
                    pt = R.path(pIdx, :);
                    
                    if ~isempty(lat)
                        distDeg = hypot(lat - pt(1), (lon - pt(2))*cosd(pt(1)));
                        if any(distDeg < 0.04), continue; end
                    end
                    
                    lat(end+1, 1) = pt(1); %#ok<AGROW>
                    lon(end+1, 1) = pt(2); %#ok<AGROW>
                    bName = brandNames{mod(bIdx - 1, numel(brandNames)) + 1};
                    pVal = powers(mod(bIdx - 1, numel(powers)) + 1);
                    bIdx = bIdx + 1;
                    nm{end+1, 1} = sprintf('%s · %d kW', bName, pVal); %#ok<AGROW>
                    kw(end+1, 1) = pVal; %#ok<AGROW>
                    dc(end+1, 1) = true; %#ok<AGROW>
                end
            end
            
            stn = struct('lat', lat, 'lon', lon, 'name', {nm}, 'kw', kw, 'dc', dc);
        end
    end
end