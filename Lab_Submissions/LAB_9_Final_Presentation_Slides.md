# LAB 9: Final Project Presentation (Slide Deck & Speaker Notes)

**Subject:** System Simulation Lab / Capstone Project  
**Submission Date:** 19 September 2026  
**Project Title:** Intelligent Trip Planning for Battery Electric Vehicles Using Real-Time Map Data  
**Challenge Reference:** MathWorks Excellence in Innovation Challenge — Project #255  
**Institution:** Vidyalankar Institute of Technology (VIT), Mumbai  
**Department:** Department of Electronics and Computer Science Engineering  

### Presenters:
1. **Rajiv Gohil** (Project Lead, Powertrain Dynamics & Simulink, Route Engine) — `rajiv.gohil24@vit.edu.in`  
2. **Sneha Pardeshi** (Google Maps API & Driving Cycles, Energy Accounting, Charging Optimization & UI) — `sneha.pardeshi@vit.edu.in`  

---

## 🖥️ Presentation Slide Deck (15 Slides)

```
================================================================================
SLIDE 1: Title & Team Introduction
================================================================================
[Visual: High-tech EV Dashboard Graphic with MATLAB & Simulink Logos]

TITLE: Intelligent Trip Planning for Battery Electric Vehicles Using Real-Time Map Data
SUBTITLE: MathWorks Excellence in Innovation Challenge — Project #255

PRESENTED BY:
• Rajiv Gohil (Project Lead, Powertrain Dynamics, Simulink Integration & Route Engine)
• Sneha Pardeshi (Google Maps API, Driving Cycle Synthesis, Energy Accounting & UI)

AFFILIATION:
Department of Electronics and Computer Science Engineering
Vidyalankar Institute of Technology (VIT), Mumbai

--------------------------------------------------------------------------------
SPEAKER SCRIPT (Rajiv):
"Good morning, respected professors and evaluators. Today, Sneha and I are proud to present our project: 'Intelligent Trip Planning for Battery Electric Vehicles Using Real-Time Map Data', developed as part of MathWorks Excellence in Innovation Challenge Project #255."
================================================================================


================================================================================
SLIDE 2: Problem Statement & Motivation
================================================================================
[Visual: Split Comparison Graphic — Flat Standard WLTP Cycle vs Real-World Mountainous Highway with Traffic]

THE PROBLEM:
• Traditional test cycles (WLTP, NEDC) are flat, speed-averaged, and idealized.
• Real-world EV range frequently drops 20% to 35% below manufacturer claims.
• Primary causes of discrepancy:
  1. Topographical road grade (climbing hills consumes massive energy).
  2. Stop-and-go traffic bottlenecks (dissipates kinetic energy).
  3. Aerodynamic drag scaling quadratically with highway cruising speed.
  4. Environmental temperatures requiring active HVAC cooling/heating.

THE SOLUTION:
A high-fidelity simulation workflow combining real-time Google Maps data with longitudinal vehicle dynamics and battery equivalent circuit modeling in MATLAB & Simulink.

--------------------------------------------------------------------------------
SPEAKER SCRIPT (Sneha):
"Electric vehicle buyers frequently complain that their real-world driving range is far less than advertised. A car that claims 450 km may struggle to reach 320 km when driving through the Western Ghats. Our project replaces idealized flat cycles with actual on-road geography, elevation, and traffic data directly imported into Simulink."
================================================================================


================================================================================
SLIDE 3: System Architecture & Data Flow
================================================================================
[Visual: System Block Diagram showing 4 functional layers]

• Data Ingestion Layer:
  - Google Maps Directions API (Route polyline, legal speed limits, step durations)
  - Google Maps Elevation API (Continuous elevation profile, road slopes)
  - Pre-compiled Offline Corridors (Mumbai-Pune, Yamuna Expressway, etc.)

• Processing & Cycle Synthesis:
  - Road grade smoothing filter
  - 2 Hz Time-Speed Trajectory Generator [t, v(t), θ(t)]
  - Format to MATLAB timeseries & route_drive_cycle.mat for Simulink

• Simulation & Physics Layer:
  - Virtual Vehicle Composer BEV parameterization
  - Longitudinal dynamic equilibrium (F_net = m*a)
  - 2D Motor efficiency map (copper, iron, windage losses)
  - Equivalent Circuit Battery Model (Voc - I*Rint)

• Output & Decision Layer:
  - Net kWh, kWh/100km, SOC trajectory, trip cost in INR (₹)
  - Driving mode selector (Eco, Normal, Performance)
  - DC Fast Charging planner

--------------------------------------------------------------------------------
SPEAKER SCRIPT (Rajiv):
"Here is the architecture of our platform. We ingest real-time geospatial data, smooth the elevation to calculate slope gradients, synthesize a realistic 2 Hz driving cycle, feed it into our Simulink vehicle model, and compute detailed battery depletion and fast charging requirements."
================================================================================


================================================================================
SLIDE 4: Core Task 1 — Real-Time Route & Topography Ingestion
================================================================================
[Visual: Google Maps Polyline + Elevation Profile of Mumbai-Pune Expressway]

• Real-Time REST Interface:
  - Implemented via `fetchGoogleRouteData.m` and `RouteEngine/getRoutes.m`.
  - Extracts turn-by-turn road polyline, traffic congestion factors, and waypoint elevations.
• Spatial Interpolation & Grade Filtering:
  - Calculates instantaneous road slope: θ = arctan(Δz / Δx).
  - Employs Savitzky-Golay smoothing to eliminate high-frequency elevation noise.
• Zero-Configuration Offline Corridors:
  - High-resolution 2-meter datasets for Mumbai-Pune, Old NH48, Yamuna Expressway, Bengaluru-Mysuru, Chennai ECR.

--------------------------------------------------------------------------------
SPEAKER SCRIPT (Sneha):
"Core Task 1 was acquiring and processing route data. Using the Google Maps API, our system extracts real elevation profiles. For example, on the Mumbai-Pune Expressway, the car climbs from near sea level in Navi Mumbai to over 600 meters at Lonavala. Our code processes this topography into smooth road grade angles for the vehicle equations."
================================================================================


================================================================================
SLIDE 5: Core Task 2 — Driving Cycle Synthesis for Simulink
================================================================================
[Visual: Speed vs Time Graph showing legal limit adherence and toll plaza stops]

• Synthesis Methodology:
  - Synthesizes 2 Hz discrete speed trajectories: [time_sec, speed_mps].
  - Respects legal highway speed limits and real-time congestion slowdowns.
  - Inserts realistic deceleration ramps and idle dwell times at highway toll plazas.
• Simulink Driving Cycle Source Block Integration:
  - Implemented in `export_route_to_simulink.m`.
  - Automatically builds a standard MATLAB `timeseries` object (`simulink_drive_cycle`).
  - Exports `route_drive_cycle.mat` directly compatible with Simulink's Drive Cycle Source block.

--------------------------------------------------------------------------------
SPEAKER SCRIPT (Sneha):
"In Core Task 2, we convert spatial map data into a continuous time-speed driving cycle. Unlike flat synthetic cycles, our synthesizer accounts for local speed limits, acceleration limits, and mandatory stops like toll booths. We export this directly as a timeseries and a MAT-file for Simulink's Driving Cycle Source block."
================================================================================


================================================================================
SLIDE 6: Core Task 3 — BEV Modeling & Virtual Vehicle Composer
================================================================================
[Visual: Virtual Vehicle Composer App Screenshot + Base Workspace Parameters]

• MathWorks Virtual Vehicle Composer Integration:
  - Preloads vehicle mass, drag coefficient, frontal area, rolling resistance, motor envelope, and battery capacity.
  - Executed via one-click helper: `open_virtual_vehicle_composer('TATA_NEXON_EV_LR')`.
• Calibrated Database of 10 Indian BEVs:
  1. Tata Nexon EV LR (45 kWh, 106.6 kW)
  2. MG Windsor EV (38 kWh, 100 kW)
  3. Mahindra XEV 9e (79 kWh, 210 kW)
  4. Hyundai Ioniq 5 (72.6 kWh, 160 kW)
  5. Tata Curvv EV (55 kWh, 123 kW)
  6. MG ZS EV (50.3 kWh, 130 kW)
  7. Tata Punch EV LR (35 kWh, 90 kW)
  8. Mahindra XUV400 (39.4 kWh, 110 kW)
  9. Tata Tiago EV LR (24 kWh, 55 kW)
  10. MG Comet EV (17.3 kWh, 31 kW)

--------------------------------------------------------------------------------
SPEAKER SCRIPT (Rajiv):
"For Core Task 3, we modeled the electric vehicle. We created a dedicated script that loads certified vehicle parameters into the base workspace, matching the exact input fields of MathWorks Virtual Vehicle Composer. Our database contains 10 leading Indian electric vehicles, allowing instant side-by-side powertrain comparisons."
================================================================================


================================================================================
SLIDE 7: Core Task 4 — Powertrain Dynamics & Battery ECM
================================================================================
[Visual: Longitudinal Free-Body Diagram + Battery Equivalent Circuit Schematic]

1. Longitudinal Force Equilibrium:
   m_eff * (dv/dt) = F_tract - F_aero - F_roll - F_grade - F_brake
   - F_aero = 0.5 * rho * Cd * A * v^2
   - F_roll = Crr * m * g * cos(θ)
   - F_grade = m * g * sin(θ)

2. Electric Motor Efficiency Map:
   - P_loss(ω, T) = k_cu * T^2 + k_fe * ω + k_w * ω^3 + P_fixed

3. Equivalent Circuit Battery Model (ECM):
   - V_term = V_oc(SOC) - I_batt * R_int(SOC, T)
   - I_batt = [V_oc - sqrt(V_oc^2 - 4 * R_int * P_batt)] / (2 * R_int)
   - Continuous Coulomb counting updates battery SOC.

--------------------------------------------------------------------------------
SPEAKER SCRIPT (Rajiv):
"Core Task 4 handles powertrain simulation. We solve full longitudinal vehicle dynamics, accounting for aerodynamic drag, tire rolling resistance, and gravity forces on slopes. The motor loss model captures copper and iron losses, while the battery Equivalent Circuit Model computes real terminal voltage drops and internal resistance heating."
================================================================================


================================================================================
SLIDE 8: Core Task 5 — Visualization & Satellite Mapping
================================================================================
[Visual: Dual-mode App Interface displaying Satellite Map, Roadmap, and Graphs]

• High-Performance Dual-Mode Dashboard:
  - Vector Roadmap View: Crisp road geometry, waypoints, and markers.
  - Real Google Maps Satellite View: Topographical aerial imagery of terrain.
• Comprehensive Result Panels:
  - Continuous Elevation & Slope Profile.
  - Dynamic Battery SOC Trajectory (%) with 15% safety threshold.
  - Instantaneous Power & Motor Torque tracking.
  - Energy Root-Cause Breakdown (Aero vs Rolling vs Hill climb vs Motor vs HVAC).
• One-Click Official PDF Report Generation.

--------------------------------------------------------------------------------
SPEAKER SCRIPT (Sneha):
"For Core Task 5, we created an interactive dashboard. Evaluators can toggle between high-resolution Google Maps satellite imagery and street maps. The app visualizes the route, elevation profile, SOC curve, and automatically decomposes total energy consumption into aerodynamic, rolling, slope, and HVAC loss percentages."
================================================================================


================================================================================
SLIDE 9: Advanced Extension 1 — User-Informed Driving Modes
================================================================================
[Visual: Bar Chart comparing Eco vs Normal vs Performance Energy Consumption]

OPTIMIZING DRIVING BEHAVIOR:
• ECO Mode:
  - a_max = 1.2 m/s² | Speed cap: 85 km/h | 100% Regen | HVAC Eco (0.8 kW)
  - Net Energy: 21.4 kWh | Final SOC: 47.4% | Energy Saved: 27.2%
• NORMAL Mode:
  - a_max = 1.8 m/s² | Speed cap: 100 km/h | 80% Regen | HVAC Normal (1.5 kW)
  - Net Energy: 25.1 kWh | Final SOC: 39.2% | Energy Saved: 14.6%
• PERFORMANCE Mode:
  - a_max = 2.8 m/s² | Speed cap: 120 km/h | 60% Regen | HVAC Sport (2.2 kW)
  - Net Energy: 29.4 kWh | Final SOC: 29.6% | Baseline

KEY INSIGHT:
Driving in Eco mode saves 8.0 kWh (providing 45 km of bonus range) with only a 20-minute travel time difference over 148 km.

--------------------------------------------------------------------------------
SPEAKER SCRIPT (Sneha):
"In Advanced Extension 1, we implemented user-selectable driving modes. By capping cruising speeds to 85 km/h, limiting harsh accelerations, and optimizing HVAC cooling, Eco mode achieves a massive 27.2% energy savings compared to Performance mode, proving that driving behavior is just as critical as battery size."
================================================================================


================================================================================
SLIDE 10: Advanced Extension 2 — Highway Fast Charging Planner
================================================================================
[Visual: Route Map with DC Fast Charger Marker + Battery SOC Rebound Curve]

INTELLIGENT CHARGING DECISIONS:
• Reserve Violation Detection:
  - Flagged when battery SOC drops below 15% reserve threshold.
• Fast Charging Station Identification:
  - Locates commercial DC Fast Chargers along highway corridors (Tata Power, Jio-bp, etc.).
• Non-Linear CC-CV Taper Model:
  - High-speed Constant Current (CC) charging up to 80% SOC.
  - Constant Voltage (CV) taper above 80% prevents battery degradation.
• Total Trip Cost & Dwell Time:
  - Computes exact charging session duration and electricity tariff cost in INR (₹).

--------------------------------------------------------------------------------
SPEAKER SCRIPT (Rajiv):
"In Advanced Extension 2, we addressed charging optimization. If a vehicle cannot complete the journey on a single charge, the system detects when SOC drops below 15%, selects the optimal highway fast charger, computes non-linear CC-CV charging time to 80%, and adds the charging stop directly to the trip itinerary."
================================================================================


================================================================================
SLIDE 11: Automated Verification Suite (24 / 24 Tests Passed)
================================================================================
[Visual: MATLAB Terminal Output showing 100% green test passes]

MASTER TEST HARNESS (`runAllTests.m`):
1. Vehicle Dynamics & Force Equilibrium Tests (4/4 passed)
   - Verified aero quadratic scaling (v^2) and grade force symmetry.
2. Battery Equivalent Circuit & OCV Tests (4/4 passed)
   - Monotonic OCV-SOC mapping and thermal internal resistance scaling.
3. Driving Cycle Generation Tests (4/4 passed)
   - Validated acceleration limits, dwell stops, and speed clamps.
4. Route Processing & Topography Tests (4/4 passed)
   - Spatial interpolation, elevation smoothing, and grade bounds.
5. Energy Accounting & Conservation Tests (4/4 passed)
   - Conservation of energy, positive net consumption, plausible kWh/100km.
6. Baseline vs Upgraded Numerical Benchmark (4/4 passed)
   - Direct numerical comparison against Simscape baseline model.

RESULT: 24 of 24 Verification Checks Passed (100% Success Rate)

--------------------------------------------------------------------------------
SPEAKER SCRIPT (Rajiv):
"To ensure engineering rigor, we built an automated test harness with 6 test suites and 24 individual validation checks covering vehicle dynamics, battery chemistry, and energy conservation. All 24 tests pass with a 100% success rate."
================================================================================


================================================================================
SLIDE 12: Live Demonstration Sequence
================================================================================
[Visual: Screenshots of the 3 Command Execution Steps in MATLAB]

THREE COMMANDS FOR LIVE DEMO:
1. `run_app`
   - Launches interactive application.
   - Shows Google Maps Satellite & Roadmap views.
   - Simulates Mumbai-Pune trip for Tata Nexon EV and MG Windsor.
   - Compares Eco vs Performance modes and visualizes charging stops.

2. `open_virtual_vehicle_composer('TATA_NEXON_EV_LR')`
   - Demonstrates MathWorks Virtual Vehicle Composer integration.
   - Preloads calibrated BEV specifications into base workspace.

3. `export_route_to_simulink`
   - Demonstrates continuous timeseries drive cycle export into Simulink.

--------------------------------------------------------------------------------
SPEAKER SCRIPT (Sneha):
"During our live demonstration, we show three simple commands in MATLAB: `run_app` to interact with satellite maps and simulation metrics, `open_virtual_vehicle_composer` to demonstrate MathWorks vehicle parameterization, and `export_route_to_simulink` to export the cycle into Simulink."
================================================================================


================================================================================
SLIDE 13: Project Impact & Engineering Value
================================================================================
[Visual: Summary Graphic of Key Engineering Outcomes]

• Real-World Accuracy: Eliminates the 25–35% error of flat standard drive cycles by modeling true road grade and traffic congestion.
• Driver Guidance: Quantifies the tangible range benefit of driving in Eco mode (saving up to 8 kWh / 45 km of range).
• Range Anxiety Mitigation: Predicts exact fast charging stop locations, charging durations to 80%, and trip costs.
• Open & Extensible: 100% native MATLAB & Simulink architecture ready for academic research or automotive fleet planning.

--------------------------------------------------------------------------------
SPEAKER SCRIPT (Rajiv):
"In conclusion, this project provides a practical engineering toolset that bridges the gap between digital map data and automotive simulation. It proves that accounting for real topography and driver behavior is essential for accurate BEV energy management."
================================================================================


================================================================================
SLIDE 14: Project Submission Proof
================================================================================
[Visual: Screenshots of GitHub Repository and MathWorks Hub Discussion Post]

• Public GitHub Repository:
  https://github.com/Rajiv-Gohil/BEV-Intelligent-Trip-Planning-MATLAB
  - Complete code, models, documentation, and automated test harness.
• MathWorks Challenge Project Hub:
  - Official solution submitted on Discussion Thread #128 for Project #255.
• Academic Team Attribution:
  - Rajiv Gohil & Sneha Pardeshi
  - Dept. of Electronics & Computer Science Engineering, VIT Mumbai.

--------------------------------------------------------------------------------
SPEAKER SCRIPT (Sneha):
"Our complete project has been published to our public GitHub repository and officially submitted to the MathWorks Challenge Project Hub on Discussion Thread #128. All documentation, instructions, and source files are openly accessible."
================================================================================


================================================================================
SLIDE 15: Conclusion & Q&A
================================================================================
[Visual: Thank You Slide with VIT Logo, Team Contact Details, and GitHub QR Code]

THANK YOU!

Presenters:
• Rajiv Gohil (rajiv.gohil24@vit.edu.in)
• Sneha Pardeshi (sneha.pardeshi@vit.edu.in)

Department of Electronics and Computer Science Engineering
Vidyalankar Institute of Technology (VIT), Mumbai

Questions & Discussion
================================================================================
SPEAKER SCRIPT (Rajiv & Sneha):
"Thank you to our faculty guide and evaluators for your time and guidance. We are now open for any questions and live demonstration."
```
