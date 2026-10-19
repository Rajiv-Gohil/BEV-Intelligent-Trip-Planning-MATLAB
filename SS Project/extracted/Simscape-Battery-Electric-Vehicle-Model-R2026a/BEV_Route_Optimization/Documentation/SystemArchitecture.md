# BEV Route Energy Simulation and Optimization Platform: System Architecture

## 1. High-Level Architecture Overview

The BEV Route Energy Simulation and Optimization Platform is an engineering-grade simulation environment built entirely within MATLAB. It couples real-world geographical route information, road elevation topography, dynamic traffic flow, and closed-loop driver modeling with physical BEV powertrain subsystem models.

```
┌────────────────────────────────────────────────────────────────────────┐
│                   MATLAB App Designer UI (9 Tabs)                      │
│ Home | Vehicle | Route | Scenario | Simulation | Compare | Opt | Charge │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
           ┌────────────────────────┴────────────────────────┐
           ▼                                                 ▼
┌──────────────────────┐                          ┌──────────────────────┐
│  Route Processing    │                          │   Indian BEV Data    │
│  - Distance [s]      │                          │  - 10+ Models        │
│  - Elevation [z]     │                          │  - Mass, Cd, A, Crr  │
│  - Grade [theta]     │                          │  - P_peak, T_peak    │
│  - Traffic [v_traf]  │                          │  - Battery Cap, Voc  │
└──────────┬───────────┘                          └──────────┬───────────┘
           │                                                 │
           └────────────────────────┬────────────────────────┘
                                    ▼
                       ┌─────────────────────────┐
                       │  Driving Cycle Engine   │
                       │  - Eco / Normal / Perf  │
                       │  - PI Driver Controller │
                       │  - Acceleration Limits  │
                       └────────────┬────────────┘
                                    │
                                    ▼
       ┌─────────────────────────────────────────────────────────┐
       │             Powertrain Simulation Engine                │
       │                                                         │
       │  ┌─────────────────┐       ┌─────────────────────────┐  │
       │  │ Longitudinal Dyn│       │   Motor / Inverter      │  │
       │  │ F_prop - F_res  ├──────►│   T_max(w) Envelope     │  │
       │  │ Aero, Roll, Hill│       │   2D Efficiency Map     │  │
       │  └────────┬────────┘       └───────────┬─────────────┘  │
       │           │                            │                │
       │           │                ┌───────────▼─────────────┐  │
       │           ▼                │   Battery (OCV-Rint)    │  │
       │  ┌─────────────────┐       │   Voc(SOC) - I*Rint     │  │
       │  │ Regen Blending  ├──────►│   Current Protection    │  │
       │  │ Motor vs Fric.  │       │   Thermal Derating      │  │
       │  └─────────────────┘       └───────────┬─────────────┘  │
       │                                        │                │
       │                            ┌───────────▼─────────────┐  │
       │                            │  Auxiliary & HVAC Load  │  │
       │                            │  f(T_ambient, T_target) │  │
       │                            └─────────────────────────┘  │
       └────────────────────────────┬────────────────────────────┘
                                    │
           ┌────────────────────────┴────────────────────────┐
           ▼                                                 ▼
┌──────────────────────┐                          ┌──────────────────────┐
│  Energy Accounting   │                          │  Optimization Layer  │
│  - Net Energy (kWh)  │                          │  - Multi-Criteria J  │
│  - kWh/100 km        │                          │  - Mode Selection    │
│  - Loss Breakdown    │                          │  - Charging Planner  │
│  - Energy Insights   │                          │  - Cost in INR (Rs)  │
└──────────────────────┘                          └──────────────────────┘
```

---

## 2. Subsystem Signal Flow & Interfaces

### 2.1 Route Data Layer (`RouteEngine/`)
- **Inputs**: Origin, Destination, optional Google API key, or selection of offline corridor.
- **Processing**:
  - Resamples spatial coordinate series to uniform $200\,\text{m}$ intervals: $s_k \in [0, D_{\text{total}}]$.
  - Applies a moving-average filter to filter elevation noise $\tilde{z}(s)$.
  - Calculates road grade:
    $$\text{grade}_k = \frac{z_{k+1} - z_k}{s_{k+1} - s_k} \times 100\%$$
    $$\theta_k = \arctan\left(\frac{\text{grade}_k}{100}\right)$$
  - Enforces civil highway grade bounds: $\theta \in [-15\%, +15\%]$.
  - Identifies toll booths and intersection stop locations.

### 2.2 Driving Cycle Generator (`DrivingCycle/`)
- Converts spatial route attributes into time-based trajectories $(t, v_{\text{target}}, \theta, P_{\text{aux}})$.
- Integrates driving mode constraints:
  - **ECO**: $a_{\text{max}} = 1.1\,\text{m/s}^2$, $v_{\text{cruise,max}} = 90\,\text{km/h}$, $100\%$ regen priority, $0.75\times$ HVAC load.
  - **NORMAL**: $a_{\text{max}} = 1.9\,\text{m/s}^2$, $v_{\text{cruise,max}} = 110\,\text{km/h}$, balanced regen, $1.00\times$ HVAC load.
  - **PERFORMANCE**: $a_{\text{max}} = 3.2\,\text{m/s}^2$, $v_{\text{cruise,max}} = 130\,\text{km/h}$, dynamic throttle, $1.25\times$ HVAC load.
- Incorporates stop dwell durations ($15\,\text{s}$ at toll plazas).

### 2.3 Closed-Loop Driver Controller (`driverModel.m`)
- Speed error: $e_v(t) = v_{\text{ref}}(t) - v(t)$.
- Desired force:
  $$F_{\text{des}} = K_p e_v + K_i \int e_v dt + m g \sin(\theta)$$
  where $m g \sin(\theta)$ is grade feedforward compensation to prevent hill-climb speed droop.

### 2.4 Longitudinal Vehicle Body (`longitudinalDynamics.m`)
- Net force:
  $$F_{\text{net}} = F_{\text{propulsion}} - F_{\text{resistance}} - F_{\text{frictionBrake}}$$
- Total retarding resistance:
  $$F_{\text{resistance}} = F_{\text{roll}} + F_{\text{aero}} + F_{\text{grade}}$$
  $$F_{\text{roll}} = C_{rr} m g \cos(\theta) \tanh\left(\frac{v}{0.1}\right)$$
  $$F_{\text{aero}} = \frac{1}{2} \rho C_d A v^2$$
  $$F_{\text{grade}} = m g \sin(\theta)$$
- Rotational equivalent mass:
  $$m_{\text{eff}} = m + \frac{4 J_{\text{wheel}} + J_{\text{motor}} N_{\text{gear}}^2}{r_{\text{wheel}}^2}$$
- Acceleration:
  $$\frac{dv}{dt} = \frac{F_{\text{net}}}{m_{\text{eff}}}$$

### 2.5 Motor Drive Unit & Reducer (`BEV_Model/Motor/`)
- Motor speed:
  $$\omega_{\text{motor}} = \frac{v}{r_{\text{wheel}}} N_{\text{gear}}$$
- Torque envelope:
  $$T_{\text{max}}(\omega) = \min\left(T_{\text{peak}}, \frac{P_{\text{peak}}}{\omega}\right)$$
- 2D Loss mapping:
  $$P_{\text{loss}} = k_{cu} T^2 + k_{fe} \omega + k_w \omega^3 + P_{\text{fixed}}$$
- Electrical power demand:
  $$P_{\text{elec}} = \begin{cases} P_{\text{mech}} + P_{\text{loss}}, & P_{\text{mech}} \ge 0 \quad (\text{motoring}) \\ P_{\text{mech}} - P_{\text{loss}}, & P_{\text{mech}} < 0 \quad (\text{regenerating}) \end{cases}$$

### 2.6 Battery Equivalent Circuit (`BEV_Model/Battery/`)
- Open-circuit voltage: $V_{\text{oc}} = f(\text{SOC}, T_{\text{batt}})$.
- Internal resistance: $R_{\text{int}} = f(\text{SOC}, T_{\text{batt}})$.
- Terminal voltage equation:
  $$V_{\text{term}} = V_{\text{oc}} - I_{\text{batt}} R_{\text{int}}$$
  $$P_{\text{batt}} = V_{\text{term}} I_{\text{batt}} = V_{\text{oc}} I_{\text{batt}} - I_{\text{batt}}^2 R_{\text{int}}$$
- Exact analytical current:
  $$I_{\text{batt}} = \frac{V_{\text{oc}} - \sqrt{V_{\text{oc}}^2 - 4 R_{\text{int}} P_{\text{batt}}}}{2 R_{\text{int}}}$$
- Coulomb counting SOC update:
  $$\text{SOC}(t + \Delta t) = \text{SOC}(t) - \frac{I_{\text{batt}} \Delta t}{Q_{\text{nom}} \times 3600}$$

---

## 3. Data Flow & MATLAB Integration Architecture

```
User Selection (App Designer UI)
  │
  ├─► vehicleDatabase.m (Loads verified vehicle parameters struct)
  ├─► getRoutes.m -> processRoute.m (Generates uniform segmented geometry)
  ├─► generateDrivingCycle.m (Synthesizes time-series driving profile)
  │
  ▼
runBEVSimulation.m
  ├─► Analytical Solver (0.05s vectorized execution)
  └─► Simulink Engine (Loads BEV.slx, logsout timetables)
  │
  ▼
processSimulationResults.m
  ├─► calculateEnergy.m (Net energy, kWh/100km, loss decomposition)
  ├─► calculateSOC.m (SOC trajectory, reserve safety, remaining range)
  ├─► calculateCost.m (Grid charging cost in INR)
  └─► Energy Insights Generator (Explains physical root causes of consumption)
  │
  ▼
App Designer Results Dashboard (9 KPI metric badges, 6 engineering plots)
```
