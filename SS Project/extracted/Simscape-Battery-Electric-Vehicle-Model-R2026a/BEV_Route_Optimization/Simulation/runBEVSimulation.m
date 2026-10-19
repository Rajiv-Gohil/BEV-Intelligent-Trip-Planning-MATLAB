function results = runBEVSimulation(vehicle, drivingCycle, initialSOC_pct, simEngine, tariff_INR)
% RUNBEVSIMULATION Executes BEV powertrain simulation over route driving cycle
%
% Supports:
%   1. 'Analytical' : High-speed vectorized physical simulation solver (instantaneous execution)
%   2. 'Simulink'   : Simulink model execution with logged signals and parameterization
%
% Inputs:
%   vehicle        - Vehicle parameter structure from vehicleDatabase
%   drivingCycle   - Driving cycle structure from generateDrivingCycle
%   initialSOC_pct - Starting battery State of Charge in % (default: 90%)
%   simEngine      - 'Analytical' (default) or 'Simulink'
%   tariff_INR     - Electricity tariff in INR/kWh (default: 8.50)

    if nargin < 3 || isempty(initialSOC_pct)
        initialSOC_pct = 90.0;
    end
    if nargin < 4 || isempty(simEngine)
        simEngine = 'Analytical';
    end
    if nargin < 5 || isempty(tariff_INR)
        tariff_INR = 8.50;
    end

    switch lower(string(simEngine))
        case 'simulink'
            rawSim = runSimulinkEngine(vehicle, drivingCycle, initialSOC_pct);
        otherwise
            rawSim = runAnalyticalEngine(vehicle, drivingCycle, initialSOC_pct);
    end

    % Package and analyze results
    results = processSimulationResults(rawSim, vehicle, drivingCycle, tariff_INR);
end

%% Vectorized High-Fidelity Physical Analytical Solver
function rawSim = runAnalyticalEngine(vehicle, drivingCycle, initialSOC_pct)
    T = drivingCycle.Time_s(:);
    v_ref = drivingCycle.SpeedRef_mps(:);
    theta = drivingCycle.Grade_rad(:);
    grade_pct = drivingCycle.Grade_pct(:);
    P_aux_in = drivingCycle.AuxLoad_W(:);
    elev_in = drivingCycle.Elevation_m(:);
    modeConfig = drivingCycle.ModeConfig;

    n = numel(T);
    dt = mean(diff(T));

    % Preallocate time-series arrays
    v_act = zeros(n, 1);
    a_act = zeros(n, 1);
    dist_m = zeros(n, 1);
    torque_motor = zeros(n, 1);
    omega_motor = zeros(n, 1);
    P_motor = zeros(n, 1);
    P_motor_loss = zeros(n, 1);
    P_batt = zeros(n, 1);
    V_batt = zeros(n, 1);
    I_batt = zeros(n, 1);
    soc = zeros(n, 1);
    P_regen = zeros(n, 1);

    % Initial conditions
    soc(1) = initialSOC_pct / 100.0;
    v_act(1) = 0;
    V_batt(1) = batteryOCV_LUT(soc(1), vehicle);
    driverState = struct('integralError', 0, 'prevAcc', 0);

    r_w = vehicle.WheelRadius_m;
    N_g = vehicle.GearRatio;
    eta_dt = vehicle.DrivetrainEfficiency;

    for k = 1:n-1
        % 1. Driver controller produces desired motor torque and friction brake force
        [T_cmd, F_fric_cmd, driverState] = driverModel(...
            v_ref(k), v_act(k), theta(k), vehicle, modeConfig, dt, driverState);

        % 2. Motor angular speed
        omega_rpm = (v_act(k) / r_w) * N_g * (60 / (2 * pi));
        omega_motor(k) = omega_rpm;

        % 3. Enforce motor torque-speed limits
        [T_max_mot, T_max_reg] = motorTorqueLimit(omega_rpm, vehicle);
        if T_cmd >= 0
            T_actual = min(T_max_mot, T_cmd);
            F_fric_actual = F_fric_cmd;
        else
            % Blend regen with friction brakes considering SOC taper
            [T_actual, F_fric_regen_add, ~] = regenBrakingBlending(...
                abs(T_cmd) * N_g * eta_dt / r_w, v_act(k), soc(k), vehicle, modeConfig);
            F_fric_actual = F_fric_cmd + F_fric_regen_add;
        end
        torque_motor(k) = T_actual;

        % 4. Drivetrain propulsion / retarding force on road
        if T_actual >= 0
            F_propulsion = (T_actual * N_g * eta_dt) / r_w;
        else
            F_propulsion = (T_actual * N_g / eta_dt) / r_w;
        end

        % 5. Road resistance forces (rolling, aero, grade)
        [F_resist, ~, ~, ~] = resistanceForces(v_act(k), theta(k), vehicle);

        % 6. Forward longitudinal vehicle dynamics
        [v_act(k+1), a_act(k), dist_m(k+1)] = longitudinalDynamics(...
            v_act(k), F_propulsion, F_resist, F_fric_actual, vehicle, dt, dist_m(k));

        % 7. Motor electrical power & losses
        [~, P_elec_motor, P_loss_m] = motorEfficiencyMap(T_actual, omega_rpm, vehicle);
        P_motor(k) = T_actual * (omega_rpm * 2 * pi / 60);
        P_motor_loss(k) = P_loss_m;

        if P_elec_motor < 0
            P_regen(k) = abs(P_elec_motor);
        end

        % 8. Total battery power demand = Motor Electrical Power + Auxiliary/HVAC
        P_batt_demand = P_elec_motor + P_aux_in(k);

        % 9. Equivalent circuit battery update
        [V_term, I_b, soc_next, P_batt_act, ~] = batteryEquivalentCircuit(...
            P_batt_demand, soc(k), dt, vehicle);

        V_batt(k) = V_term;
        I_batt(k) = I_b;
        P_batt(k) = P_batt_act;
        soc(k+1) = soc_next;
    end

    % Fill last step values
    torque_motor(end) = torque_motor(end-1);
    omega_motor(end) = omega_motor(end-1);
    P_motor(end) = P_motor(end-1);
    P_motor_loss(end) = P_motor_loss(end-1);
    P_batt(end) = P_batt(end-1);
    V_batt(end) = V_batt(end-1);
    I_batt(end) = I_batt(end-1);
    a_act(end) = a_act(end-1);
    P_regen(end) = P_regen(end-1);

    rawSim = struct();
    rawSim.Time_s = T;
    rawSim.VehicleSpeed_mps = v_act;
    rawSim.Acceleration_mps2 = a_act;
    rawSim.Distance_km = dist_m / 1000;
    rawSim.Elevation_m = elev_in;
    rawSim.Grade_pct = grade_pct;
    rawSim.Grade_rad = theta;
    rawSim.Torque_Nm = torque_motor;
    rawSim.MotorSpeed_rpm = omega_motor;
    rawSim.MotorPower_W = P_motor;
    rawSim.MotorLoss_W = P_motor_loss;
    rawSim.BatteryPower_W = P_batt;
    rawSim.BatteryVoltage_V = V_batt;
    rawSim.BatteryCurrent_A = I_batt;
    rawSim.SOC_pct = soc * 100;
    rawSim.AuxPower_W = P_aux_in;
    rawSim.RegenPower_W = P_regen;
end

%% Simulink Engine Execution Helper
function rawSim = runSimulinkEngine(vehicle, drivingCycle, initialSOC_pct)
    modelName = 'BEV';
    slxPath = fullfile(fileparts(mfilename('fullpath')), '..', 'BEV_Model', [modelName '.slx']);

    % Check if BEV.slx exists, if not build it
    if ~isfile(slxPath)
        try
            build_BEV_slx;
        catch
            warning('Simulink build failed or license unavailable. Falling back to analytical solver.');
            rawSim = runAnalyticalEngine(vehicle, drivingCycle, initialSOC_pct);
            return;
        end
    end

    try
        load_system(modelName);
        sim_in = Simulink.SimulationInput(modelName);
        sim_in = setModelParameter(sim_in, 'StopTime', num2str(drivingCycle.Time_s(end)));

        % Set workspace variables for simulation
        sim_in = setVariable(sim_in, 'veh_mass', vehicle.VehicleMass_kg);
        sim_in = setVariable(sim_in, 'veh_cd', vehicle.DragCoeff_Cd);
        sim_in = setVariable(sim_in, 'veh_area', vehicle.FrontalArea_m2);
        sim_in = setVariable(sim_in, 'veh_crr', vehicle.RollingResistance_Crr);
        sim_in = setVariable(sim_in, 'veh_rw', vehicle.WheelRadius_m);
        sim_in = setVariable(sim_in, 'veh_gear', vehicle.GearRatio);
        sim_in = setVariable(sim_in, 'batt_cap_kwh', vehicle.BatteryCapacity_kWh);
        sim_in = setVariable(sim_in, 'batt_nom_v', vehicle.NominalVoltage_V);
        sim_in = setVariable(sim_in, 'initial_soc', initialSOC_pct / 100);
        sim_in = setVariable(sim_in, 'drive_time', drivingCycle.Time_s);
        sim_in = setVariable(sim_in, 'drive_spd', drivingCycle.SpeedRef_mps);
        sim_in = setVariable(sim_in, 'drive_grade', drivingCycle.Grade_rad);
        sim_in = setVariable(sim_in, 'aux_load_w', drivingCycle.AuxLoad_W);

        simOut = sim(sim_in);
        logs = simOut.logsout;

        % Extract logged signals
        rawSim = struct();
        rawSim.Time_s = logs.get('VehicleSpeed').Values.Time;
        rawSim.VehicleSpeed_mps = logs.get('VehicleSpeed').Values.Data;
        rawSim.Distance_km = logs.get('Distance').Values.Data / 1000;
        rawSim.Torque_Nm = logs.get('MotorTorque').Values.Data;
        rawSim.MotorPower_W = logs.get('MotorPower').Values.Data;
        rawSim.BatteryPower_W = logs.get('BatteryPower').Values.Data;
        rawSim.BatteryVoltage_V = logs.get('BatteryVoltage').Values.Data;
        rawSim.BatteryCurrent_A = logs.get('BatteryCurrent').Values.Data;
        rawSim.SOC_pct = logs.get('BatterySOC').Values.Data * 100;
        rawSim.AuxPower_W = drivingCycle.AuxLoad_W;
        rawSim.Elevation_m = drivingCycle.Elevation_m;
        rawSim.Grade_pct = drivingCycle.Grade_pct;
        rawSim.Grade_rad = drivingCycle.Grade_rad;
        rawSim.Acceleration_mps2 = [0; diff(rawSim.VehicleSpeed_mps) ./ diff(rawSim.Time_s)];
        rawSim.MotorLoss_W = abs(rawSim.BatteryPower_W - rawSim.MotorPower_W);
        rawSim.RegenPower_W = max(0, -rawSim.MotorPower_W);
    catch ME
        warning('Simulink execution error: %s. Reverting to analytical solver.', ME.message);
        rawSim = runAnalyticalEngine(vehicle, drivingCycle, initialSOC_pct);
    end
end
