function [F_total, F_roll, F_aero, F_grade] = resistanceForces(v_mps, grade_rad, vehicle, airDensity_kgpm3)
% RESISTANCEFORCES Calculates physical resistance forces acting on BEV
%
% Equations:
%   F_roll  = Crr * m * g * cos(theta)
%   F_aero  = 0.5 * rho * Cd * A * v^2
%   F_grade = m * g * sin(theta)
%   F_total = F_roll + F_aero + F_grade
%
% Inputs:
%   v_mps            - Vehicle forward speed (m/s)
%   grade_rad        - Road inclination angle (radians)
%   vehicle          - Vehicle parameters struct
%   airDensity_kgpm3 - Ambient air density (default: 1.20 kg/m^3)

    if nargin < 4 || isempty(airDensity_kgpm3)
        airDensity_kgpm3 = 1.20;
    end

    g = 9.81; % Gravitational acceleration (m/s^2)
    m = vehicle.VehicleMass_kg;

    % Rolling resistance (only active when vehicle is in motion)
    % Uses hyperbolic tangent smoothing around zero speed to prevent chattering
    speedSign = tanh(v_mps / 0.1);
    F_roll = vehicle.RollingResistance_Crr * m * g * cos(grade_rad) * speedSign;

    % Aerodynamic drag force
    F_aero = 0.5 * airDensity_kgpm3 * vehicle.DragCoeff_Cd * vehicle.FrontalArea_m2 * (v_mps^2) * speedSign;

    % Road grade force (hill climb / descent)
    F_grade = m * g * sin(grade_rad);

    % Total retarding resistance force
    F_total = F_roll + F_aero + F_grade;
end
