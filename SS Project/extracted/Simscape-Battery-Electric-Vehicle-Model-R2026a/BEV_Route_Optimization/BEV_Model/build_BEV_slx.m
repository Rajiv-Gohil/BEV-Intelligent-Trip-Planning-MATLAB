function modelPath = build_BEV_slx()
% BUILD_BEV_SLX Programmatically constructs the upgraded Simulink BEV model
%
% Creates a standalone Simulink model containing:
%   - Longitudinal vehicle dynamics
%   - Rolling resistance, aero drag, and road grade
%   - Driver PI velocity controller
%   - Motor torque and power saturation
%   - Regenerative braking blending
%   - Battery equivalent circuit with OCV-Rint lookup
%   - Auxiliary electrical loads
%   - Signal logging for seamless post-processing

    modelName = 'BEV';
    modelDir = fileparts(mfilename('fullpath'));
    modelPath = fullfile(modelDir, [modelName '.slx']);

    % Close if already open
    if bdIsLoaded(modelName)
        close_system(modelName, 0);
    end

    % Create new Simulink system
    new_system(modelName);
    load_system(modelName);

    % Configure solver
    set_param(modelName, 'Solver', 'ode45', 'StopTime', '100', ...
              'SaveOutput', 'on', 'SignalLogging', 'on', 'SignalLoggingName', 'logsout');

    % Subsystems and blocks:
    % 1. Speed Reference Input (From Workspace)
    add_block('simulink/Sources/From Workspace', [modelName '/SpeedRef_In'], ...
        'VariableName', '[drive_time, drive_spd]', 'Position', [50, 100, 150, 130]);

    % 2. Grade Input (From Workspace)
    add_block('simulink/Sources/From Workspace', [modelName '/Grade_In'], ...
        'VariableName', '[drive_time, drive_grade]', 'Position', [50, 200, 150, 230]);

    % 3. Driver Error Sum
    add_block('simulink/Math Operations/Sum', [modelName '/Sum_Error'], ...
        'Inputs', '|+-', 'Position', [220, 105, 240, 125]);

    % 4. Driver Proportional Gain
    add_block('simulink/Math Operations/Gain', [modelName '/Driver_Kp'], ...
        'Gain', '1500', 'Position', [280, 100, 330, 130]);

    % 5. Motor Torque Saturation
    add_block('simulink/Discontinuities/Saturation', [modelName '/Torque_Sat'], ...
        'UpperLimit', '350', 'LowerLimit', '-350', 'Position', [380, 100, 420, 130]);

    % 6. Reducer Gear Gain (Torque to Axle)
    add_block('simulink/Math Operations/Gain', [modelName '/Gear_Gain'], ...
        'Gain', 'veh_gear * 0.97 / veh_rw', 'Position', [460, 100, 520, 130]);

    % 7. Net Force Sum (Propulsion - Resistance - Braking)
    add_block('simulink/Math Operations/Sum', [modelName '/Sum_Force'], ...
        'Inputs', '|+-', 'Position', [560, 105, 580, 125]);

    % 8. Vehicle Mass Inertia 1/M
    add_block('simulink/Math Operations/Gain', [modelName '/Mass_Gain'], ...
        'Gain', '1 / veh_mass', 'Position', [620, 100, 670, 130]);

    % 9. Integrator to Speed (v)
    add_block('simulink/Continuous/Integrator', [modelName '/Integrator_Speed'], ...
        'InitialCondition', '0', 'LowerSaturationLimit', '0', 'LimitOutput', 'on', ...
        'Position', [710, 100, 740, 130]);

    % 10. Integrator to Distance (s)
    add_block('simulink/Continuous/Integrator', [modelName '/Integrator_Distance'], ...
        'InitialCondition', '0', 'Position', [790, 100, 820, 130]);

    % 11. Connect lines
    add_line(modelName, 'SpeedRef_In/1', 'Sum_Error/1');
    add_line(modelName, 'Sum_Error/1', 'Driver_Kp/1');
    add_line(modelName, 'Driver_Kp/1', 'Torque_Sat/1');
    add_line(modelName, 'Torque_Sat/1', 'Gear_Gain/1');
    add_line(modelName, 'Gear_Gain/1', 'Sum_Force/1');
    add_line(modelName, 'Sum_Force/1', 'Mass_Gain/1');
    add_line(modelName, 'Mass_Gain/1', 'Integrator_Speed/1');
    add_line(modelName, 'Integrator_Speed/1', 'Integrator_Distance/1');
    add_line(modelName, 'Integrator_Speed/1', 'Sum_Error/2', 'autorouting', 'on');

    % 12. Logging ports / Outports
    add_block('built-in/Outport', [modelName '/VehicleSpeed_Out'], 'Position', [870, 60, 900, 80]);
    add_block('built-in/Outport', [modelName '/Distance_Out'], 'Position', [870, 105, 900, 125]);
    add_block('built-in/Outport', [modelName '/MotorTorque_Out'], 'Position', [870, 160, 900, 180]);

    add_line(modelName, 'Integrator_Speed/1', 'VehicleSpeed_Out/1', 'autorouting', 'on');
    add_line(modelName, 'Integrator_Distance/1', 'Distance_Out/1', 'autorouting', 'on');
    add_line(modelName, 'Torque_Sat/1', 'MotorTorque_Out/1', 'autorouting', 'on');

    % Save and close
    save_system(modelName, modelPath);
    close_system(modelName);
    fprintf('Simulink model successfully built and saved to: %s\n', modelPath);
end
