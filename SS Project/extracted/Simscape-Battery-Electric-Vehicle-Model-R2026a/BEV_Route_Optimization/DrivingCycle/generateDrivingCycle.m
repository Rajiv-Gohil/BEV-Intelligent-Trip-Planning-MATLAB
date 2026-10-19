function drivingCycle = generateDrivingCycle(processedRoute, vehicle, drivingMode, ambientTemp_C)
% GENERATEDRIVINGCYCLE Generates a realistic time-speed profile from route segments and mode
%
% Inputs:
%   processedRoute - Route struct from processRoute
%   vehicle        - Vehicle struct from vehicleDatabase
%   drivingMode    - 'ECO', 'NORMAL', or 'PERFORMANCE' (default: 'NORMAL')
%   ambientTemp_C  - Ambient air temperature in Celsius (default: 32 C for Indian summer)
%
% Output:
%   drivingCycle   - Struct containing:
%                    - Time_s: Time vector (1 Hz or 2 Hz sampling)
%                    - SpeedRef_kmh: Reference speed (km/h)
%                    - SpeedRef_mps: Reference speed (m/s)
%                    - Grade_pct: Road grade profile over time (%)
%                    - Grade_rad: Road grade profile over time (rad)
%                    - Distance_km: Cumulative distance over time (km)
%                    - Elevation_m: Elevation over time (m)
%                    - AuxLoad_W: Time-varying auxiliary and HVAC power (W)
%                    - DrivingMode: Name of selected mode

    if nargin < 3 || isempty(drivingMode)
        drivingMode = 'NORMAL';
    end
    if nargin < 4 || isempty(ambientTemp_C)
        ambientTemp_C = 32.0; % Typical Indian ambient temperature
    end

    % Load driving mode parameters
    switch upper(string(drivingMode))
        case 'ECO'
            modeConfig = generateEcoCycle();
        case 'PERFORMANCE'
            modeConfig = generatePerformanceCycle();
        otherwise
            modeConfig = generateNormalCycle();
    end

    % Route distance and target speed spatial profile
    s_route = processedRoute.Distance_km;
    elev_route = processedRoute.Elevation_m;
    grade_route = processedRoute.Grade_pct;
    spd_limit = processedRoute.SpeedLimit_kmh;
    traf_spd = processedRoute.TrafficSpeed_kmh;

    % Target speed considering traffic, mode factor, and mode cruising speed cap
    v_target_spatial_kmh = min(traf_spd * modeConfig.CruisingSpeedFactor, modeConfig.MaxCruisingSpeed_kmh);
    v_target_spatial_kmh = min(v_target_spatial_kmh, spd_limit);
    v_target_spatial_mps = v_target_spatial_kmh / 3.6;

    % Incorporate Stop Events (Tolls, intersections)
    stopDistances = [];
    if isfield(processedRoute, 'StopEvents_Distance_km') && ~isempty(processedRoute.StopEvents_Distance_km)
        stopDistances = processedRoute.StopEvents_Distance_km(:);
    end

    % Forward integration over time with acceleration and deceleration limits
    dt = 0.5; % 2 Hz temporal resolution
    maxTimeSteps = 20000; % Safety preallocation

    t_vec = zeros(maxTimeSteps, 1);
    v_vec = zeros(maxTimeSteps, 1);
    s_vec = zeros(maxTimeSteps, 1);

    current_s = 0;
    current_v = 0;
    t = 0;
    step = 1;
    totalDist_km = s_route(end);

    while current_s < totalDist_km && step < maxTimeSteps
        % Current spatial target speed
        target_v = interp1(s_route, v_target_spatial_mps, current_s, 'linear', 'extrap');

        % Check if approaching a stop event within stopping distance
        isStopping = false;
        for i = 1:numel(stopDistances)
            d_to_stop = (stopDistances(i) - current_s) * 1000; % meters
            if d_to_stop > 0 && d_to_stop < 250
                % Decelerate towards stop
                target_v = max(0, min(target_v, sqrt(2 * modeConfig.MaxDeceleration_mps2 * max(0, d_to_stop - 5))));
                if d_to_stop < 10
                    isStopping = true;
                end
                break;
            end
        end

        % Acceleration / Deceleration bounding
        dv_desired = target_v - current_v;
        if dv_desired > 0
            % Accelerating
            dv_max = modeConfig.MaxAcceleration_mps2 * dt;
            current_v = current_v + min(dv_desired, dv_max);
        else
            % Decelerating
            dv_max = modeConfig.MaxDeceleration_mps2 * dt;
            current_v = current_v + max(dv_desired, -dv_max);
        end
        current_v = max(0, current_v);

        % Handle stop dwell time (e.g. 15s at toll booth)
        if isStopping && current_v < 0.5
            current_v = 0;
            % Add 15 second dwell
            dwellSteps = round(15 / dt);
            for d = 1:dwellSteps
                if step >= maxTimeSteps, break; end
                t = t + dt;
                step = step + 1;
                t_vec(step) = t;
                v_vec(step) = 0;
                s_vec(step) = current_s;
            end
            % Advance past stop mark to prevent re-triggering
            current_s = current_s + 0.02;
            continue;
        end

        % Advance distance
        ds = current_v * dt / 1000; % km
        current_s = current_s + ds;
        t = t + dt;

        step = step + 1;
        t_vec(step) = t;
        v_vec(step) = current_v;
        s_vec(step) = current_s;
    end

    % Truncate preallocated arrays
    t_vec = t_vec(1:step);
    v_vec = v_vec(1:step);
    s_vec = min(totalDist_km, s_vec(1:step));

    % Map time-series back to route elevation and grade
    elev_t = interp1(s_route, elev_route, s_vec, 'pchip');
    grade_t = interp1(s_route, grade_route, s_vec, 'linear');
    grade_rad_t = atan(grade_t / 100);

    % Compute Ambient-Dependent HVAC & Auxiliary Electrical Power
    % Baseline auxiliary: lighting, compute, coolant pump
    P_base_aux = vehicle.AuxBaseLoad_W;
    % HVAC Power based on Delta T from comfortable cabin (22 C)
    deltaT = abs(ambientTemp_C - 22.0);
    % Heat pump / AC power: ~120W per degree delta T, scaled by mode factor
    P_hvac = deltaT * 120.0 * modeConfig.AuxLoadFactor;
    P_aux_total = (P_base_aux + P_hvac) * ones(size(t_vec));

    % Output struct
    drivingCycle = struct();
    drivingCycle.Time_s = t_vec;
    drivingCycle.SpeedRef_mps = v_vec;
    drivingCycle.SpeedRef_kmh = v_vec * 3.6;
    drivingCycle.Distance_km = s_vec;
    drivingCycle.Elevation_m = elev_t;
    drivingCycle.Grade_pct = grade_t;
    drivingCycle.Grade_rad = grade_rad_t;
    drivingCycle.AuxLoad_W = P_aux_total;
    drivingCycle.DrivingMode = drivingMode;
    drivingCycle.ModeConfig = modeConfig;
    drivingCycle.AmbientTemp_C = ambientTemp_C;
    drivingCycle.TotalDuration_s = t_vec(end);
    drivingCycle.TotalDistance_km = s_vec(end);
    drivingCycle.AverageSpeed_kmh = mean(v_vec * 3.6);
end
