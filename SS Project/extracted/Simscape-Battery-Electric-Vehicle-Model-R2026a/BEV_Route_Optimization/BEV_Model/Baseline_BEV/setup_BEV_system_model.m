base_dir = fileparts(mfilename('fullpath'));
addpath(genpath(base_dir));
Vehicle1D_Basic_params;
Reducer_Basic_params;
MotorDriveUnit_Basic_params;
BatteryHV_Basic_params;
CtrlEnv_Basic_params;
loadLUTData_VehicleSpeedReference_Simple;
