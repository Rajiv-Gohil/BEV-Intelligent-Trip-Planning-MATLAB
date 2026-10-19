# LAB 8: Project Progress Report

**Subject:** System Simulation Lab / Capstone Project  
**Submission Date:** 05 September 2026  
**Project Title:** Intelligent Trip Planning for Battery Electric Vehicles Using Real-Time Map Data  
**Challenge Reference:** MathWorks Excellence in Innovation Challenge — Project #255  
**Institution:** Vidyalankar Institute of Technology (VIT), Mumbai  
**Department:** Department of Electronics and Computer Science Engineering  

### Team Members:
1. **Rajiv Gohil** (Project Lead, Powertrain Dynamics & Simulink, Route Engine) — `rajiv.gohil24@vit.edu.in`  
2. **Sneha Pardeshi** (Google Maps API & Driving Cycles, Energy Accounting, Charging Optimization & UI) — `sneha.pardeshi@vit.edu.in`  

---

## 1. Executive Summary & Project Status

Since the submission of the initial working prototype in LAB 7, the project has progressed into the **Advanced Optimization & Validation Phase**. All 5 Core Project Tasks are complete, and both optional Advanced Extensions have been implemented in the codebase.

### Progress Summary Dashboard
| Task / Module | Target Milestone | Status | % Completion |
| :--- | :--- | :---: | :---: |
| **Core Task 1: Real-Time Map & Elevation Ingestion** | Google Maps Directions & Elevation API integration | Completed | 100% |
| **Core Task 2: Driving Cycle Synthesis for Simulink** | Time-speed synthesizer & `timeseries` export | Completed | 100% |
| **Core Task 3: Virtual Vehicle Composer BEV Modeling** | Base workspace mapping & 10 Indian BEVs database | Completed | 100% |
| **Core Task 4: Powertrain Simulation & Energy Accounting**| Longitudinal forces, 2D motor map, battery ECM | Completed | 100% |
| **Core Task 5: Visualization & Mapping Toolbox** | Satellite/roadmap tiles, elevation & SOC plotting | Completed | 100% |
| **Advanced Task 1: Driving Mode Optimization** | Eco, Normal, Performance mode trade-off engine | Completed | 100% |
| **Advanced Task 2: Highway Fast Charging Planner** | Reserve violation detection, CC-CV taper model | Completed | 100% |

---

## 2. Implementation of Advanced Project Extensions

### 2.1 Advanced Extension 1: User-Informed Driving Modes (`optimizeDrivingMode.m`)
Three distinct driving profiles were calibrated to simulate behavioral impacts on powertrain efficiency:

1. **ECO Mode**:
   - Acceleration limit: $a_{\text{max}} = 1.2\,\text{m/s}^2$
   - Cruising speed cap: $v_{\text{cap}} = 85\,\text{km/h}$
   - Regenerative braking prioritization: $100\%$ regen capture before mechanical friction brake engagement.
   - Auxiliary HVAC load: Eco compressor setting ($0.8\,\text{kW}$).
2. **NORMAL Mode**:
   - Acceleration limit: $a_{\text{max}} = 1.8\,\text{m/s}^2$
   - Cruising speed cap: $v_{\text{cap}} = 100\,\text{km/h}$
   - Standard regen blending: $80\%$ recovery efficiency.
   - Auxiliary HVAC load: Standard comfort setting ($1.5\,\text{kW}$).
3. **PERFORMANCE Mode**:
   - Acceleration limit: $a_{\text{max}} = 2.8\,\text{m/s}^2$
   - Cruising speed cap: $v_{\text{cap}} = 120\,\text{km/h}$ (expressway legal ceiling)
   - Dynamic sport regen: $60\%$ capture ratio with high wheel torque response.
   - Auxiliary HVAC load: High cooling capacity ($2.2\,\text{kW}$).

#### Mode Comparison Results (Mumbai-Pune Corridor, Tata Nexon EV LR, 148 km):
| Driving Mode | Travel Time | Net Energy | Avg. Efficiency | Final SOC | Trip Cost | Energy Savings vs Performance |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **ECO** | $2\text{h } 14\text{m}$ | $21.4\,\text{kWh}$ | $14.4\,\text{kWh/100km}$ | **$47.4\%$** | $₹\,192.60$ | **$+27.2\%$ saved** |
| **NORMAL** | $2\text{h } 08\text{m}$ | $25.1\,\text{kWh}$ | $16.9\,\text{kWh/100km}$ | **$39.2\%$** | $₹\,225.90$ | **$+14.6\%$ saved** |
| **PERFORMANCE**| $1\text{h } 54\text{m}$ | $29.4\,\text{kWh}$ | $19.8\,\text{kWh/100km}$ | **$29.6\%$** | $₹\,264.60$ | Baseline |

> **Key Finding:** Driving in Eco mode saves $8.0\,\text{kWh}$ of battery energy (equivalent to $45\,\text{km}$ of additional range) while only increasing travel time by 20 minutes across the 148 km trip.

---

### 2.2 Advanced Extension 2: Highway Fast Charging Optimization (`optimizeCharging.m`)
When a planned route exceeds the vehicle's safe single-charge radius, the platform automatically plans charging stops:

1. **Reserve Violation Detection**:
   Monitors instantaneous battery State of Charge. If $\text{SOC}(t) < 15\%$, a violation flag is triggered.
2. **Candidate Station Spatial Query**:
   Scans the corridor for verified DC Fast Charging stations (Tata Power EZ Charge, Jio-bp pulse, Zeon Electric, etc.).
3. **Non-Linear CC-CV Taper Model**:
   Models constant-current (CC) high-speed charging up to 80% SOC followed by constant-voltage (CV) thermal taper, preventing unrealistic linear charging estimations:
   $$t_{\text{charge}} = \frac{E_{\text{needed}}}{P_{\text{charger}} \cdot \eta_{\text{charge}} \cdot \kappa_{\text{taper}}}$$
   Where $\kappa_{\text{taper}} = 0.85$ accounts for the slowing charge rate above 70% SOC.
4. **Session Cost Calculation**:
   Computes electricity billing in INR based on commercial EV fast-charging tariffs ($₹\,18.50/\text{kWh}$).

---

## 3. Technical Challenges Overcome

| Challenge | Impact | Engineering Solution Implemented |
| :--- | :--- | :--- |
| **Noisy Raw Elevation Data** | Step discontinuities from raw GPS/Google elevation caused unrealistic high-frequency grade spikes. | Implemented a spatial moving-average smoothing filter (`sgolay` / `smoothdata`) to produce realistic, smooth road slope angles ($\theta$). |
| **API Rate Limits / Quotas** | Network failures or missing API keys could crash simulations during offline grading. | Developed automated fallback to 6 high-resolution pre-compiled `.mat` Indian highway corridors. |
| **Simulink Integration Friction** | Manually importing custom cycles into Simulink was error-prone for evaluators. | Created `export_route_to_simulink.m` which automatically writes variables to base workspace and saves `route_drive_cycle.mat`. |

---

## 4. Work Remaining for Final Phase

1. **Master Test Suite Integration**: Assemble all unit and integration tests into a single master verification harness (`runAllTests.m`).
2. **Comprehensive Final Documentation**: Compile physical derivations into `ModelAssumptions.md` and `SystemArchitecture.md`.
3. **Public GitHub Repository Deployment**: Push codebase, configure clean README, and post official submission on MathWorks Challenge Hub Discussion #128.
4. **Final Presentation & Slide Deck**: Prepare slide materials for final project viva (LAB 9).
