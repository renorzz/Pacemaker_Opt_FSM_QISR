// pacemaker_tb.v
`timescale 1ns/1ps

module pacemaker_tb;

    // Inputs
    reg clk, rst;
    reg VT, RR, FiO2, PEEP, EP, SpO2;

    // Outputs
    wire PS, PV, FM, MS, AL, SBT;
    wire [2:0] state;

    // Instansiasi FSM
    pacemaker_fsm UUT (
        .clk(clk), .rst(rst),
        .VT(VT), .RR(RR), .FiO2(FiO2), 
        .PEEP(PEEP), .EP(EP), .SpO2(SpO2),
        .PS(PS), .PV(PV), .FM(FM), 
        .MS(MS), .AL(AL), .SBT(SBT),
        .state(state)
    );

    // Clock Generator
    always #5 clk = ~clk;

    initial begin
        $dumpfile("pacemaker.vcd");
        $dumpvars(0, pacemaker_tb);

        // 1. Inisialisasi (STANDBY)
        clk = 0; rst = 1;
        VT=1; RR=1; FiO2=1; PEEP=1; EP=1; SpO2=1; // Semua Normal
        #10 rst = 0;

        // 2. Cek MONITOR (Semua Normal)
        #20;
        $display("[TIME %0t] State: MONITOR (001) | Out: SBT=%b", $time, SBT);

        // 3. SKENARIO: Pasien Lemah (EP = 0) -> Harusnya ke ASSIST
        $display("\n--- Tes Pasien Lemah (EP=0) ---");
        EP = 0; 
        #20;
        $display("[TIME %0t] State: %b (Harus 010/ASSIST) | PS=%b AL=%b", $time, state, PS, AL);
        EP = 1; // Balik Normal
        #20;

        // 4. SKENARIO: Oksigen Drop (SpO2 = 0) -> Harusnya ke ADJ_FIO2
        $display("\n--- Tes Oksigen Drop (SpO2=0) ---");
        SpO2 = 0;
        #20;
        $display("[TIME %0t] State: %b (Harus 101/ADJ_FIO2) | FM=%b AL=%b", $time, state, FM, AL);
        SpO2 = 1; // Balik Normal
        #20;

        // 5. SKENARIO: VT Rendah (VT = 0) -> Harusnya ke SUPPORT
        $display("\n--- Tes Volume Tidal Drop (VT=0) ---");
        VT = 0;
        #20;
        $display("[TIME %0t] State: %b (Harus 011/SUPPORT) | MS=%b AL=%b", $time, state, MS, AL);
        VT = 1; // Balik Normal
        #20;

        // 6. SKENARIO: PEEP Rendah (PEEP = 0) -> Harusnya ke ADJ_PEEP
        $display("\n--- Tes PEEP Drop (PEEP=0) ---");
        PEEP = 0;
        #20;
        $display("[TIME %0t] State: %b (Harus 100/ADJ_PEEP) | PV=%b AL=%b", $time, state, PV, AL);
        PEEP = 1;
        #20;

        // 7. SKENARIO: EMERGENCY (Banyak Sensor Gagal)
        $display("\n--- Tes EMERGENCY (VT=0, RR=0, SpO2=0) ---");
        VT=0; RR=0; SpO2=0;
        #20;
        $display("[TIME %0t] State: %b (Harus 111/EMERGENCY) | AL=%b [ALL ACTIVE]", $time, state, AL);

        // 8. Recovery
        $display("\n--- Recovery (Semua Normal) ---");
        VT=1; RR=1; SpO2=1;
        #20;
        $display("[TIME %0t] State: %b (Kembali ke 001/MONITOR)", $time, state);

        #50 $finish;
    end

endmodule