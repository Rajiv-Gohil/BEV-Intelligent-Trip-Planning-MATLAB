t = (0:1:100)';
v_kph = zeros(size(t));
v_kph(11:30)=linspace(0,50,20); v_kph(31:50)=50;
v_kph(51:70)=linspace(50,0,20); v_kph(71:80)=0;
v_kph(81:90)=linspace(0,50,10); v_kph(91:100)=50; v_kph(101)=0;
VehicleSpeedReference.Time_s=t;
VehicleSpeedReference.Speed_kph=v_kph;
