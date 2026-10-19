# BEV Route Energy Simulation and Optimization Platform

> **MathWorks Excellence in Innovation Challenge — Project #255**  
> **Authors:** Rajiv Gohil & Sneha Pardeshi (Dept. of Electronics and Computer Science Engineering, Vidyalankar Institute of Technology)

---

## 👥 Project Team & Contributors

| Name | Role & Subsystem Ownership | Department & Institution | Contact Email |
| :--- | :--- | :--- | :--- |
| **Rajiv Gohil** | **Project Lead**, Powertrain Dynamics, Simulink Integration & Route Engine | Dept. of Electronics and Computer Science Engineering, Vidyalankar Institute of Technology | `rajiv.gohil24@vit.edu.in` |
| **Sneha Pardeshi** | Google Maps API, Driving Cycle Synthesis, Energy Accounting, Charging Optimization & UI | Dept. of Electronics and Computer Science Engineering, Vidyalankar Institute of Technology | `sneha.pardeshi@vit.edu.in` |

---


## 🌟 Key Capabilities

- **Indian BEV Catalogue**: Built-in, fully updateable database of 10+ leading Indian passenger BEVs (MG Windsor EV, Tata Nexon EV LR, Mahindra XEV 9e, Tata Punch EV, Tata Curvv EV, MG Comet EV, MG ZS EV, Mahindra XUV400, Tata Tigor EV, Hyundai Ioniq 5).
- **Route Abstraction Layer**: Direct Google Routes / Elevation API integration with automated, zero-configuration fallback to rich offline Indian highway corridor datasets (Mumbai-Pune Expressway & Ghat, Old NH48, Yamuna Expressway, Bengaluru-Mysuru, Chennai ECR, Mumbai Urban).
- **Realistic Driving Cycle Generator**: Synthesizes time-speed trajectories accounting for road speed limits, traffic congestion, intersection/toll stops, and driving modes (**ECO**, **NORMAL**, **PERFORMANCE**).
- **Upgraded Powertrain Physics**:
  - Full longitudinal vehicle dynamics ($F_{\text{roll}} + F_{\text{aero}} + F_{\text{grade}} + m_{\text{eff}} a$).
  - Speed-dependent motor torque envelope ($T_{\text{max}}(\omega)$) and 2D copper/iron/windage efficiency mapping.
  - Equivalent Circuit Battery Model (ECM) with $V_{\text{oc}}(\text{SOC})$ and $R_{\text{int}}(\text{SOC}, T)$ tracking and terminal voltage dynamics.
  - Regenerative braking blending with mechanical friction brakes and low-speed/high-SOC protection tapers.
  - Configurable HVAC and auxiliary power model conditioned on ambient air temperature.
- **Trip & Energy Accounting**: Gross propulsion, regenerative recovery, net energy, $\text{kWh/100 km}$, remaining range, and charging electricity costs in INR (₹).
- **Energy Explainability Engine**: Automated physical root-cause decomposition quantifying exact percentage contributions of aero drag, tire rolling resistance, hill climbs, motor losses, and HVAC loads.
- **Multi-Route & Mode Optimization**: Weighted multi-objective cost function balancing Energy, Travel Time, Cost, and Destination SOC.
- **Intelligent Fast Charging Planner**: Automatic reserve violation detection, corridor charging station search, arrival SOC prediction, charging time to $80\%$, and cost calculation.
- **Professional App Designer UI**: Clean, responsive 9-tab MATLAB interface (`BEV_Route_Optimization.mlapp`).

---

## 📁 Project Directory Structure

```
BEV_Route_Optimization/
│
├── BEV_Route_Optimization.m           % Quick CLI launcher function
├── BEV_Route_Optimization_App.m       % Complete App Designer application class
├── BEV_Route_Optimization.mlapp       % App Designer packaged application
├── initBEVPlatform.m                  % Environment startup & path configuration
│
├── BEV_Model/
│   ├── BEV.slx                        % Programmatically generated Simulink BEV model
│   ├── build_BEV_slx.m                % Script to construct/rebuild Simulink model
│   ├── Baseline_BEV/                  % Preserved baseline implementation
│   │   ├── BEV_simulation.m
│   │   ├── setup_BEV_system_model.m
│   │   └── Components/
│   ├── Battery/                       % Upgraded battery equivalent circuit models
│   │   ├── batteryEquivalentCircuit.m
│   │   ├── batteryOCV_LUT.m
│   │   └── batteryRint_LUT.m
│   ├── Motor/                         % Motor envelope and 2D efficiency map
│   │   ├── motorTorqueLimit.m
│   │   └── motorEfficiencyMap.m
│   ├── Vehicle/                       % Longitudinal dynamics & resistance forces
│   │   ├── longitudinalDynamics.m
│   │   └── resistanceForces.m
│   └── Controller/                    % Driver model, regen blending & HVAC
│       ├── driverModel.m
│       ├── regenBrakingBlending.m
│       └── auxiliaryLoadModel.m
│
├── VehicleDatabase/
│   ├── vehicleDatabase.m              % Authoritative Indian BEV database function
│   └── vehicleDatabase.mat            % MATLAB MAT container of vehicle specifications
│
├── RouteEngine/
│   ├── getRoutes.m                    % Google Routes API with offline corridor fallback
│   ├── getElevation.m                 % Elevation API with topographic model fallback
│   ├── getTraffic.m                   % Traffic speed generator
│   ├── processRoute.m                 % Elevation smoothing & road grade calculation
│   └── validateRouteData.m            % Sanity and boundary checks
│
├── DrivingCycle/
│   ├── generateDrivingCycle.m         % Speed-profile synthesizer
│   ├── driverModel.m                  % Speed tracking controller
│   ├── generateEcoCycle.m             % Eco driving mode parameters
│   ├── generateNormalCycle.m          % Normal driving mode parameters
│   └── generatePerformanceCycle.m     % Performance driving mode parameters
│
├── Simulation/
│   ├── runBEVSimulation.m             % Unified simulation runner (Analytical & Simulink)
│   ├── processSimulationResults.m     % KPI extraction & MATLAB Timetable packaging
│   ├── calculateEnergy.m              % Net energy, kWh/100km, component integrals
│   ├── calculateSOC.m                 % SOC trajectory & reserve safety check
│   └── calculateCost.m                % Grid energy & trip cost in INR
│
├── Optimization/
│   ├── optimizeRoute.m                % Multi-attribute weighted route selector
│   ├── optimizeDrivingMode.m          % Mode & cruising speed advisor
│   └── optimizeCharging.m             % Fast charging stop planner along route
│
├── Visualization/
│   ├── plotRoute.m                    % 2D route map & waypoints
│   ├── plotElevation.m                % Elevation and road grade profile
│   ├── plotDrivingCycle.m             % Speed tracking (Ref vs Actual)
│   ├── plotSOC.m                      % SOC trajectory & reserve boundary
│   ├── plotEnergyBreakdown.m          % Loss contribution bar chart
│   └── plotPowertrainResults.m        % Motor torque, battery power & current
│
├── Data/
│   ├── OfflineRoutes/                 % Pre-calculated real Indian corridors (.mat)
│   │   ├── generateOfflineCorridors.m
│   │   ├── Mumbai_Pune_Expressway.mat
│   │   ├── Mumbai_Pune_OldNH48.mat
│   │   ├── Delhi_Agra_YamunaExpressway.mat
│   │   ├── Bengaluru_Mysuru_Expressway.mat
│   │   ├── Chennai_Puducherry_ECR.mat
│   │   └── Mumbai_Urban_CoastalRoad.mat
│   ├── VehicleData/
│   └── TestScenarios/
│
├── Tests/
│   ├── testVehicleModel.m
│   ├── testBattery.m
│   ├── testDrivingCycle.m
│   ├── testRouteProcessing.m
│   ├── testEnergyCalculation.m
│   ├── testBaselineComparison.m
│   └── runAllTests.m                  % Master test suite runner
│
└── Documentation/
    ├── README.md                      % User manual and technical overview
    ├── SystemArchitecture.md          % Detailed signal flow and subsystem diagrams
    ├── ModelAssumptions.md            % Physical equations, derivations, and bounds
    └── ValidationReport.md            % Benchmark report against baseline model
```

---

## 🚀 Quick Start Guide

### Step 1: Open MATLAB
Set the Current Folder in MATLAB to:
```matlab
c:\Users\sanju\Downloads\Simscape-Battery-Electric-Vehicle-Model-R2026a\BEV_Route_Optimization
```

### Step 2: Initialize Platform
Run the initialization script:
```matlab
initBEVPlatform
```
This automatically configures the MATLAB Search Path and verifies the database and offline corridor MAT files.

### Step 3: Launch the App Designer Interface
Launch the application by running:
```matlab
BEV_Route_Optimization
```
or double-clicking `BEV_Route_Optimization.mlapp` in the MATLAB Files browser.

---

## 🧪 Automated Verification Suite

Run all 6 engineering validation tests with a single command:
```matlab
runAllTests
```
This executes:
1. `testVehicleModel`: Force equilibrium, quadratic aerodynamic scaling, grade symmetry.
2. `testBattery`: OCV-SOC monotonicity, thermal resistance scaling, equivalent circuit voltage drop.
3. `testDrivingCycle`: Dynamic mode duration, speed caps, and stop dwell events.
4. `testRouteProcessing`: Spatial interpolation, elevation smoothing, grade bounds.
5. `testEnergyCalculation`: Net energy balance, energy conservation, plausibility.
6. `testBaselineComparison`: Direct numerical comparison against `BEV_simulation.m`.

---

## 📊 Indian BEV Vehicle Catalogue

| Vehicle | Battery Capacity | Motor Power | Peak Torque | Claimed Range |
| :--- | :--- | :--- | :--- | :--- |
| **MG Windsor EV** | $38.0\,\text{kWh}$ | $100\,\text{kW}$ ($136\,\text{PS}$) | $200\,\text{N}\cdot\text{m}$ | $331\,\text{km}$ |
| **Tata Nexon EV LR** | $45.0\,\text{kWh}$ | $106.6\,\text{kW}$ ($145\,\text{PS}$) | $215\,\text{N}\cdot\text{m}$ | $489\,\text{km}$ |
| **Mahindra XEV 9e** | $79.0\,\text{kWh}$ | $210\,\text{kW}$ ($286\,\text{PS}$) | $380\,\text{N}\cdot\text{m}$ | $656\,\text{km}$ |
| **Tata Punch EV LR** | $35.0\,\text{kWh}$ | $90.0\,\text{kW}$ ($122\,\text{PS}$) | $190\,\text{N}\cdot\text{m}$ | $421\,\text{km}$ |
| **Tata Tiago EV LR** | $24.0\,\text{kWh}$ | $55.0\,\text{kW}$ ($75\,\text{PS}$) | $114\,\text{N}\cdot\text{m}$ | $315\,\text{km}$ |
| **MG Comet EV** | $17.3\,\text{kWh}$ | $31.0\,\text{kW}$ ($42\,\text{PS}$) | $110\,\text{N}\cdot\text{m}$ | $230\,\text{km}$ |
| **Tata Curvv EV** | $55.0\,\text{kWh}$ | $123.0\,\text{kW}$ ($167\,\text{PS}$) | $215\,\text{N}\cdot\text{m}$ | $585\,\text{km}$ |
| **MG ZS EV** | $50.3\,\text{kWh}$ | $130.0\,\text{kW}$ ($176\,\text{PS}$) | $280\,\text{N}\cdot\text{m}$ | $461\,\text{km}$ |
| **Mahindra XUV400** | $39.4\,\text{kWh}$ | $110.0\,\text{kW}$ ($150\,\text{PS}$) | $310\,\text{N}\cdot\text{m}$ | $456\,\text{km}$ |
| **Tata Tigor EV** | $26.0\,\text{kWh}$ | $55.0\,\text{kW}$ ($75\,\text{PS}$) | $170\,\text{N}\cdot\text{m}$ | $315\,\text{km}$ |
| **Hyundai Ioniq 5** | $72.6\,\text{kWh}$ | $160.0\,\text{kW}$ ($217\,\text{PS}$) | $350\,\text{N}\cdot\text{m}$ | $631\,\text{km}$ |

---

## 🔧 Required Toolboxes
- MATLAB (R2022a or newer recommended, R2026a fully supported)
- Simulink (Optional for `.slx` model execution; analytical solver runs 100% without Simulink)
- Optimization Toolbox (Optional; built-in solver provided)
- Mapping Toolbox (Optional; built-in coordinate engine provided)
