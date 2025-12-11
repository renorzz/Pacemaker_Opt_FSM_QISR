import numpy as np
from qiskit import QuantumCircuit, transpile
from qiskit_aer import AerSimulator

# --- 1. DEFINISI LOGIKA KLASIK ---
def calculate_actuators_and_state(inputs):
    # Memastikan input dipotong hanya 6 bit pertama jika ada kelebihan
    # (Jaga-jaga, meski kode sirkuit di bawah sudah diperbaiki)
    inputs = inputs[:6] 
    
    VT, RR, FiO2, PEEP, EP, SpO2 = inputs

    # Logic 1 = Normal, Logic 0 = Abnormal
    AL = not(VT and RR and FiO2 and PEEP and EP and SpO2)
    SBT = (VT and RR and FiO2 and PEEP and EP and SpO2)
    PS = not(RR) or not(EP)
    PV = not(PEEP)
    FM = not(SpO2) or not(FiO2)
    MS = (RR and not VT) or (not RR and EP)

    # Menentukan Next State
    fail_count = [VT, RR, FiO2, PEEP, EP, SpO2].count(0)
    
    state_name = "MONITOR"
    if fail_count >= 3:
        state_name = "EMERGENCY"
    elif not VT:
        state_name = "SUPPORT"
    elif not FiO2 or not SpO2:
        state_name = "ADJ_FIO2"
    elif not PEEP:
        state_name = "ADJ_PEEP"
    elif not RR or not EP:
        state_name = "ASSIST"
    elif SBT:
        state_name = "WEAN / MONITOR"

    return {
        "Actuators": {"PS": int(PS), "PV": int(PV), "FM": int(FM), "MS": int(MS), "AL": int(AL), "SBT": int(SBT)},
        "Next_State": state_name
    }

# --- 2. QUANTUM CIRCUIT SIMULATOR ---
def run_pacemaker_simulation(scenario_name, sensor_probabilities):
    print(f"\n--- Running Quantum Simulation: {scenario_name} ---")
    
    # PERBAIKAN DI SINI: Inisialisasi hanya Quantum Register (tanpa Classical Register manual)
    # measure_all() akan otomatis membuatkan register yang pas.
    qc = QuantumCircuit(6) 
    
    sensor_names = ["VT", "RR", "FiO2", "PEEP", "EP", "SpO2"]

    # A. Encode Input States
    for i, prob in enumerate(sensor_probabilities):
        theta = 2 * np.arcsin(np.sqrt(prob))
        qc.ry(theta, i)

    # B. Measurement
    qc.measure_all()

    # C. Execute Simulation
    simulator = AerSimulator()
    compiled_circuit = transpile(qc, simulator)
    job = simulator.run(compiled_circuit, shots=1)
    result = job.result()
    counts = result.get_counts()
    
    # D. Parse Output
    raw_bitstring = list(counts.keys())[0]
    raw_bitstring = raw_bitstring.replace(" ", "")
    
    # Qiskit urutannya terbalik (q5..q0). Kita balik lagi jadi (q0..q5)
    measured_bits = [int(bit) for bit in reversed(raw_bitstring)]
    
    # Map bit values to sensor names
    sensor_status = dict(zip(sensor_names, measured_bits))
    
    print(f"1. Quantum Probability Inputs: {dict(zip(sensor_names, sensor_probabilities))}")
    print(f"2. Measurement Outcome (Collapsed): {sensor_status}")
    
    # E. Logic Verification
    logic_out = calculate_actuators_and_state(measured_bits)
    
    print(f"3. Verified Actuator Outputs: {logic_out['Actuators']}")
    print(f"4. Resulting FSM State: {logic_out['Next_State']}")
    print("-" * 60)

# --- 3. SKENARIO PENGUJIAN ---

# Skenario 1: Normal (Semua Sehat)
run_pacemaker_simulation("Normal Patient", [1.0, 1.0, 1.0, 1.0, 1.0, 1.0])

# Skenario 2: Apnea (RR & EP Mati)
run_pacemaker_simulation("Apnea / Weak Patient", [1.0, 0.0, 1.0, 1.0, 0.0, 1.0])

# Skenario 3: Sensor Oksigen Tidak Stabil (50% kemungkinan error)
run_pacemaker_simulation("Unstable O2 Sensor", [1.0, 1.0, 1.0, 1.0, 1.0, 0.5])

# Skenario 4: Kritis (Banyak Sensor Mati)
run_pacemaker_simulation("Critical Multi-Failure", [0.1, 0.1, 1.0, 1.0, 1.0, 0.1])