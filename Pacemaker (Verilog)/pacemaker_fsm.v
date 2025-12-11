// pacemaker_fsm.v
`timescale 1ns/1ps

module pacemaker_fsm (
    input  wire clk,
    input  wire rst,
    // Input Sensor (1 = Normal, 0 = Abnormal)
    input  wire VT,    // Volume Tidal
    input  wire RR,    // Respiratory Rate
    input  wire FiO2,  // Fraksi Oksigen
    input  wire PEEP,  // Tekanan Positif
    input  wire EP,    // Effort Pasien
    input  wire SpO2,  // Saturasi Oksigen
    
    // Output Actuator & Alarm sesuai Tabel
    output reg  PS,    // Pressure Support
    output reg  PV,    // PEEP Valve
    output reg  FM,    // Flow Mixer
    output reg  MS,    // Machine Support
    output reg  AL,    // Alarm
    output reg  SBT,   // Spontaneous Breathing Trial
    output reg [2:0] state // Debug State
);

    // --- 1. STATE ENCODING (Sesuai Tabel FSM) ---
    localparam STANDBY     = 3'b000;
    localparam MONITOR     = 3'b001; // All OK
    localparam ASSIST      = 3'b010; // Pasien Lemah
    localparam SUPPORT     = 3'b011; // Mode Mesin (VT Fail)
    localparam ADJ_PEEP    = 3'b100; // PEEP Correction
    localparam ADJ_FIO2    = 3'b101; // O2 Correction
    localparam WEAN        = 3'b110; // Weaning Mode
    localparam EMERGENCY   = 3'b111; // Critical / Multi Fail

    reg [2:0] curr_state, next_state;

    // --- 2. LOGIKA TRANSISI (Next State Logic) ---
    // Variabel bantu untuk menghitung jumlah kegagalan sensor
    wire [2:0] fail_count;
    wire all_ok;
    
    // Menghitung berapa sensor yang bernilai 0 (Abnormal)
    assign fail_count = (!VT) + (!RR) + (!FiO2) + (!PEEP) + (!EP) + (!SpO2);
    assign all_ok = (fail_count == 0);

    always @(*) begin
        next_state = curr_state; // Default hold

        case (curr_state)
            // State: STANDBY
            STANDBY: begin
                if (all_ok) next_state = MONITOR;
                else if (fail_count >= 3) next_state = EMERGENCY;
            end

            // State Operational (MONITOR, ASSIST, etc)
            MONITOR, ASSIST, SUPPORT, ADJ_PEEP, ADJ_FIO2, WEAN: begin
                // PRIORITAS 1: Emergency (Jika banyak sensor gagal sekaligus)
                // Lihat tabel: "Banyak sensor gagal -> Emergency"
                if (fail_count >= 3) begin
                    next_state = EMERGENCY;
                end
                // PRIORITAS 2: Normal (Recovery)
                else if (all_ok) begin
                    next_state = MONITOR;
                end
                // PRIORITAS 3: Machine Support (VT rendah sangat fatal)
                // Tabel: VT rendah -> ModeSelect (MS) aktif -> State SUPPORT
                else if (VT == 0) begin
                    next_state = SUPPORT;
                end
                // PRIORITAS 4: Masalah Oksigen (FiO2 atau SpO2)
                // Tabel: O2/FiO2 rendah -> Mixer (FM) aktif -> State ADJ_FIO2
                else if (FiO2 == 0 || SpO2 == 0) begin
                    next_state = ADJ_FIO2;
                end
                // PRIORITAS 5: Masalah PEEP
                // Tabel: PEEP rendah -> Valve (PV) aktif -> State ADJ_PEEP
                else if (PEEP == 0) begin
                    next_state = ADJ_PEEP;
                end
                // PRIORITAS 6: Masalah Napas Ringan (RR atau EP)
                // Tabel: RR/EP rendah -> PS aktif -> State ASSIST
                else if (RR == 0 || EP == 0) begin
                    next_state = ASSIST;
                end
            end

            // State: EMERGENCY
            EMERGENCY: begin
                if (all_ok) next_state = MONITOR; // Pulih total
                else next_state = EMERGENCY;      // Tetap alarm
            end
        endcase
    end

    // --- 3. STATE REGISTER (Sequential) ---
    always @(posedge clk or posedge rst) begin
        if (rst) curr_state <= STANDBY;
        else curr_state <= next_state;
    end

    // --- 4. OUTPUT LOGIC (Sesuai Tabel State Output Kamu) ---
    always @(*) begin
        // Default nilai 0 semua
        PS=0; PV=0; FM=0; MS=0; AL=0; SBT=0;
        state = curr_state; // Assign output debug

        case (curr_state)
            STANDBY: begin
                // 0 0 0 0 0 0 (Idle)
            end
            MONITOR: begin
                SBT = 1; // 0 0 0 0 0 1
            end
            ASSIST: begin
                PS = 1; AL = 1; // 1 0 0 0 1 0 (Pasien lemah)
            end
            SUPPORT: begin
                PS = 1; MS = 1; AL = 1; // 1 0 0 1 1 0 (Mode Mesin)
            end
            ADJ_PEEP: begin
                PV = 1; AL = 1; // 0 1 0 0 1 0 (PEEP rendah)
            end
            ADJ_FIO2: begin
                FM = 1; AL = 1; // 0 0 1 0 1 0 (Koreksi O2)
            end
            WEAN: begin
                SBT = 1; // 0 0 0 0 0 1 (Weaning/SBT)
            end
            EMERGENCY: begin
                PS=1; PV=1; FM=1; MS=1; AL=1; // 1 1 1 1 1 0 (Semua Aktif + Alarm)
            end
        endcase
    end

endmodule