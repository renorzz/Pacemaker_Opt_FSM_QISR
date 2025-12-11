using System;
using System.Threading;

public class PacemakerFsm
{
    // 1. Menggunakan Nama State yang Sesuai dengan Dokumen/Verilog
    public enum State 
    { 
        STANDBY,    // S0
        MONITOR,    // S1
        ASSIST,     // S2
        SUPPORT,    // S3
        ADJ_PEEP,   // S4
        ADJ_FIO2,   // S5
        WEAN,       // S6
        EMERGENCY   // S7
    }

    public State CurrState { get; private set; } = State.STANDBY;
    
    // Output Actuators
    public bool PS, PV, FM, MS, AL, SBT;

    public void Update(bool VT, bool RR, bool FiO2, bool PEEP, bool EP, bool SpO2)
    {
        // Hitung jumlah sensor yang fail (Logika '0' = Fail)
        // Jika input true = Normal, false = Abnormal
        int failCount = (VT ? 0 : 1) + (RR ? 0 : 1) + (FiO2 ? 0 : 1) + 
                        (PEEP ? 0 : 1) + (EP ? 0 : 1) + (SpO2 ? 0 : 1);
        
        bool all_ok = (failCount == 0);

        // --- LOGIKA TRANSISI (Next State Logic) ---
        // Sesuai prioritas di Verilog pacemaker_fsm.v

        if (CurrState == State.STANDBY)
        {
            if (all_ok) CurrState = State.MONITOR;
            else if (failCount >= 3) CurrState = State.EMERGENCY;
        }
        else // State Operasional Lainnya
        {
            // PRIORITAS 1: Emergency (Multi-failure)
            if (failCount >= 3) 
            {
                CurrState = State.EMERGENCY;
            }
            // PRIORITAS 2: Recovery (Semua Normal)
            else if (all_ok) 
            {
                CurrState = State.MONITOR;
            }
            // PRIORITAS 3: VT Rendah -> SUPPORT (Paling fatal setelah emergency)
            else if (!VT) 
            {
                CurrState = State.SUPPORT;
            }
            // PRIORITAS 4: Masalah Oksigen -> ADJ_FIO2
            else if (!FiO2 || !SpO2) 
            {
                CurrState = State.ADJ_FIO2;
            }
            // PRIORITAS 5: Masalah PEEP -> ADJ_PEEP
            else if (!PEEP) 
            {
                CurrState = State.ADJ_PEEP;
            }
            // PRIORITAS 6: Napas/Effort Lemah -> ASSIST
            else if (!RR || !EP) 
            {
                CurrState = State.ASSIST;
            }
        }

        // --- LOGIKA OUTPUT (Output Logic) ---
        // Reset semua output ke false dulu
        PS = false; PV = false; FM = false; MS = false; AL = false; SBT = false;

        switch (CurrState)
        {
            case State.STANDBY:
                // Idle, semua 0
                break;
            case State.MONITOR:
                SBT = true;
                break;
            case State.ASSIST:
                PS = true; AL = true;
                break;
            case State.SUPPORT:
                PS = true; MS = true; AL = true;
                break;
            case State.ADJ_PEEP:
                PV = true; AL = true;
                break;
            case State.ADJ_FIO2:
                FM = true; AL = true;
                break;
            case State.WEAN:
                SBT = true;
                break;
            case State.EMERGENCY:
                // Semua aktif di mode darurat
                PS = true; PV = true; FM = true; MS = true; AL = true;
                break;
        }
    }
}

class Program
{
    static void Main()
    {
        PacemakerFsm fsm = new PacemakerFsm();
        
        // Inisialisasi Sensor (true = Normal)
        bool VT = true, RR = true, FiO2 = true, PEEP = true, EP = true, SpO2 = true;
        
        // Counter untuk simulasi perubahan input sederhana
        int tick = 0;

        Console.WriteLine("Memulai Simulasi Pacemaker FSM...");
        Thread.Sleep(1000);

        while (true)
        {
            // Simulasi perubahan input berdasarkan waktu (tick)
            tick++;
            
            // Contoh skenario otomatis:
            if (tick == 5) { EP = false; Console.WriteLine("\n[EVENT] Pasien Lemah (EP Fail)"); }
            if (tick == 10) { EP = true; Console.WriteLine("\n[EVENT] Pasien Pulih"); }
            if (tick == 15) { VT = false; Console.WriteLine("\n[EVENT] Tidal Volume Drop!"); }
            if (tick == 20) { VT = false; RR = false; SpO2 = false; Console.WriteLine("\n[EVENT] CRITICAL FAILURE!"); }
            if (tick == 25) { VT = true; RR = true; SpO2 = true; Console.WriteLine("\n[EVENT] Recovery Total"); }

            // Update FSM
            fsm.Update(VT, RR, FiO2, PEEP, EP, SpO2);

            // Tampilkan Status
            // Console.Clear(); // Opsional: Hapus komentar jika ingin layar bersih
            Console.WriteLine($"Tick {tick} | State: {fsm.CurrState}");
            Console.WriteLine($"   Inputs -> VT:{VT} RR:{RR} FiO2:{FiO2} PEEP:{PEEP} EP:{EP} SpO2:{SpO2}");
            Console.WriteLine($"   Outputs-> PS:{fsm.PS} PV:{fsm.PV} FM:{fsm.FM} MS:{fsm.MS} AL:{fsm.AL} SBT:{fsm.SBT}");
            Console.WriteLine(new string('-', 50));

            Thread.Sleep(1000); // Delay 1 detik
        }
    }
}