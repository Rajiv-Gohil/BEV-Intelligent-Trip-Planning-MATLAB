# Battery Electric Vehicle — MATLAB/Simulink Project Starter

Based on the supplied BEV study guide. MATLAB R2026a target.

## Run
1. Open MATLAB.
2. Set the project root as the Current Folder.
3. Run `BEV/BEV_simulation.m`.
4. The script reports trip energy, distance, kWh/100 km and final SOC, and plots reference/actual speed, motor torque and SOC.

## Parameter files
- Components/Vehicle1D/Vehicle1D_Basic_params.m
- Components/Reducer/Reducer_Basic_params.m
- Components/MotorDriveUnit/MotorDriveUnit_Basic_params.m
- Components/BatteryHighVoltage/BatteryHV_Basic_params.m
- Components/ControllerAndEnvironment/CtrlEnv_Basic_params.m
- BEV/loadLUTData_VehicleSpeedReference_Simple.m

## Important
This package contains runnable MATLAB analytical code and parameter/setup scripts. It does not contain proprietary Simscape block implementations or an actual `.slx/.mdl` model, because those cannot be reconstructed from the supplied markdown alone without silently inventing block-level implementation details.
