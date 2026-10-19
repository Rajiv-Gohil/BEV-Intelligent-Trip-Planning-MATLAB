# Mathematical Formulations, Physical Modeling Assumptions, and Limitations

## 1. Longitudinal Vehicle Dynamics

### 1.1 Fundamental Dynamic Equilibrium
The motion of the vehicle along its longitudinal axis is governed by Newton's Second Law:
$$m_{\text{eff}} \frac{dv}{dt} = F_{\text{traction}} - F_{\text{rolling}} - F_{\text{aero}} - F_{\text{grade}} - F_{\text{frictionBrake}}$$

Where:
- $v(t)$ is the forward velocity of the vehicle along the road tangent ($\text{m/s}$).
- $m_{\text{eff}}$ is the effective equivalent mass including rotational inertia ($\text{kg}$):
  $$m_{\text{eff}} = m_{\text{veh}} + m_{\text{payload}} + \frac{4 J_{\text{wheel}} + J_{\text{motor}} N_{\text{gear}}^2}{r_{\text{wheel}}^2}$$
- $r_{\text{wheel}}$ is the dynamic rolling radius of the tires ($\text{m}$).
- $N_{\text{gear}}$ is the overall single-speed reducer gear ratio.

### 1.2 Aerodynamic Drag Resistance
$$F_{\text{aero}} = \frac{1}{2} \rho_{\text{air}} C_d A_{\text{frontal}} v^2$$
- **Assumptions**:
  - Headwind is assumed zero unless specifically perturbed.
  - Air density $\rho_{\text{air}} = 1.20\,\text{kg/m}^3$ at sea level and standard pressure ($101.3\,\text{kPa}, 20^\circ\text{C}$).
  - Drag coefficient $C_d$ and frontal area $A$ are taken from vehicle homologation sheets.

### 1.3 Rolling Resistance
$$F_{\text{rolling}} = C_{rr} m g \cos(\theta) \tanh\left(\frac{v}{v_{\text{threshold}}}\right)$$
- **Assumptions**:
  - Rolling resistance coefficient $C_{rr}$ is constant for a given tire compound ($0.0095$ to $0.0120$ for EV low-rolling-resistance tires).
  - Hyperbolic tangent smoothing $\tanh(v / 0.1)$ prevents discontinuous force chatter around zero vehicle speed.

### 1.4 Road Grade Resistance
$$F_{\text{grade}} = m g \sin(\theta)$$
- $\theta = \arctan(\text{grade}_{\%} / 100)$ is the road inclination angle.
- Positive on hill climbs (retarding force, consumes energy).
- Negative on descents (assisting force, enables regenerative energy capture).

---

## 2. Electric Motor & Inverter Drive Unit

### 2.1 Torque-Speed Capability Envelope
Permanent Magnet Synchronous Motors (PMSM) operate in two regions:
1. **Constant Torque Region** ($\omega \le \omega_{\text{base}}$):
   $$T_{\text{max}}(\omega) = T_{\text{peak}}$$
2. **Constant Power / Field-Weakening Region** ($\omega > \omega_{\text{base}}$):
   $$T_{\text{max}}(\omega) = \frac{P_{\text{peak}}}{\omega}$$

Where $\omega_{\text{base}} = \frac{P_{\text{peak}}}{T_{\text{peak}}}$.

### 2.2 2D Physical Loss Modeling
Total electrical power loss in the motor and inverter is represented as:
$$P_{\text{loss}}(\omega, T) = k_{\text{cu}} T^2 + k_{\text{fe}} \omega + k_w \omega^3 + P_{\text{fixed}}$$
- $k_{\text{cu}} T^2$: Stator winding copper Joule heating ($I^2 R$).
- $k_{\text{fe}} \omega$: Stator core hysteresis and eddy current iron dissipation.
- $k_w \omega^3$: Rotor aerodynamic windage and bearing friction losses.
- $P_{\text{fixed}}$: Inverter switching, gate drive, and control electronics standby power.

---

## 3. High-Voltage Traction Battery Subsystem

### 3.1 Equivalent Circuit Model (ECM)
The battery is modeled as a state-of-charge dependent Open-Circuit Voltage $V_{\text{oc}}(\text{SOC})$ in series with an equivalent internal resistance $R_{\text{int}}(\text{SOC}, T)$:
$$V_{\text{terminal}} = V_{\text{oc}}(\text{SOC}) - I_{\text{batt}} R_{\text{int}}(\text{SOC}, T_{\text{batt}})$$

### 3.2 Terminal Power and Current Solution
Terminal power is defined as:
$$P_{\text{batt}} = V_{\text{terminal}} I_{\text{batt}} = V_{\text{oc}} I_{\text{batt}} - I_{\text{batt}}^2 R_{\text{int}}$$
Rearranging into quadratic form:
$$R_{\text{int}} I_{\text{batt}}^2 - V_{\text{oc}} I_{\text{batt}} + P_{\text{batt}} = 0$$
Using the quadratic formula:
$$I_{\text{batt}} = \frac{V_{\text{oc}} - \sqrt{V_{\text{oc}}^2 - 4 R_{\text{int}} P_{\text{batt}}}}{2 R_{\text{int}}}$$

### 3.3 Sign Conventions
- $P_{\text{batt}} > 0$: Discharging (current flows out, SOC decreases).
- $P_{\text{batt}} < 0$: Charging / Regeneration (current flows in, SOC increases).

### 3.4 Physical Protection Constraints
1. **Theoretical Power Transfer Bound**:
   $$P_{\text{max,theoretical}} = \frac{V_{\text{oc}}^2}{4 R_{\text{int}}}$$
2. **Current Limits**:
   - Continuous discharge limited to $3.5\text{C}$.
   - Continuous charge / regen limited to $2.0\text{C}$.
3. **Regenerative Braking SOC Taper**:
   Above $90\%$ SOC, regenerative braking is linearly derated to zero at $98\%$ SOC to prevent cell overvoltage and plating.

---

## 4. Auxiliary Subsystems & Thermal HVAC Model

Total auxiliary power demand:
$$P_{\text{aux}} = P_{\text{base}} + P_{\text{HVAC}}(T_{\text{ambient}}, T_{\text{target}}) + P_{\text{BTMS}}$$

- $P_{\text{base}}$: Base infotainment, ECU microcontrollers, lighting ($300 - 600\,\text{W}$).
- $P_{\text{HVAC}}$: Thermal heat pump / AC compressor model:
  $$P_{\text{HVAC}} = \frac{|T_{\text{ambient}} - T_{\text{target}}| \times 220\,\text{W/}^\circ\text{C}}{\text{COP}} + P_{\text{blower}}$$
  $\text{COP} = 2.8$ for cooling, $2.2$ for heating.
- $P_{\text{BTMS}}$: Battery thermal chiller ($800\,\text{W}$) active if $T_{\text{batt}} > 38^\circ\text{C}$.

---

## 5. Model Assumptions and Engineering Limitations

| Subsystem | Assumption Made | Engineering Justification & Limitation |
| :--- | :--- | :--- |
| **Lateral Dynamics** | 1D Pure Longitudinal Model | Cornering lateral tire slip is negligible for trip energy consumption on highway corridors. |
| **Driveline** | Single-speed fixed ratio | Standard for passenger BEVs; gear lash and torsional compliance are neglected. |
| **Battery Chemistry** | Lumped $R_{\text{int}}$ Equivalent Circuit | Captures $98\%$ of electrical energy losses; diffusion RC relaxation branches ($RC$ pairs) omitted for computational speed during optimization. |
| **Road Grade** | Smoothed $\Delta z / \Delta s$ | High-frequency GPS noise is smoothed out; road banking is neglected. |
| **Wind** | Zero mean ambient headwind | Environmental crosswind aerodynamic yaw drag is neglected. |
| **Tire Pressure** | Nominal calibrated $C_{rr}$ | Cold tire pressure fluctuations are not modeled dynamically. |
