%% BEV simulation-ready analytical model
clear; clc; close all;
run(fullfile(fileparts(mfilename('fullpath')),'setup_BEV_system_model.m'));

T = VehicleSpeedReference.Time_s; vref = VehicleSpeedReference.Speed_kph/3.6;
dt = mean(diff(T)); n=numel(T);
v=zeros(n,1); torque=zeros(n,1); force=zeros(n,1); Pbatt=zeros(n,1); soc=zeros(n,1);
soc(1)=initial.hvBattery_SOC_pct/100;

rho=1.2; g=vehicle.gravAccel_m_per_s2; theta=atan(ctrl.roadGrade_pct/100);
for k=1:n-1
    e=vref(k)-v(k);
    torque(k)=max(min(120*e,MotorDriveUnit.MaxTorque_Nm),MotorDriveUnit.MaxRegenTorque_Nm);
    axleTorque=torque(k)*reducer.GearRatio*reducer.Efficiency_normalized;
    force(k)=axleTorque/vehicle.tireRollingRadius_m;
    Froll=vehicle.mass_kg*g*vehicle.tireRollingCoeff*cos(theta);
    Faero=0.5*rho*vehicle.airDragCoeff*vehicle.frontalArea_m2*v(k)^2;
    Fgrade=vehicle.mass_kg*g*sin(theta);
    acc=(force(k)-Froll-Faero-Fgrade)/vehicle.mass_kg;
    v(k+1)=max(0,v(k)+acc*dt);
    omega=max(0,v(k)/vehicle.tireRollingRadius_m*reducer.GearRatio);
    Pmech=torque(k)*omega;
    if Pmech>=0, Pbatt(k)=Pmech/0.95+ctrl.auxiliaryLoad_W; else, Pbatt(k)=Pmech*0.95+ctrl.auxiliaryLoad_W; end
    I=Pbatt(k)/batteryHV.nominalVoltage_V;
    soc(k+1)=max(0,min(1,soc(k)-I*dt/(batteryHV.nominalCharge_Ahr*3600)));
end
energy_kWh=trapz(T,Pbatt)/3.6e6;
distance_km=trapz(T,v)/1000;
efficiency=100*energy_kWh/max(distance_km,eps);

fprintf('Trip energy: %.3f kWh\nDistance: %.3f km\nConsumption: %.3f kWh/100 km\nFinal SOC: %.2f %%\n',energy_kWh,distance_km,efficiency,100*soc(end));
figure('Name','BEV Results');
subplot(3,1,1); plot(T,vref*3.6,'--',T,v*3.6); grid on; ylabel('Speed (km/h)'); legend('Reference','Actual');
subplot(3,1,2); plot(T,torque); grid on; ylabel('Motor Torque (N m)');
subplot(3,1,3); plot(T,100*soc); grid on; ylabel('SOC (%)'); xlabel('Time (s)');
