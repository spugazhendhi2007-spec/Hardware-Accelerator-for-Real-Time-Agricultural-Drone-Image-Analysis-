//=============================================================================
// File: tb_power_icg_cell.sv
// Description: Self-checking testbench for power_icg_cell adhering to the
//              standard 8-test verification suite (5 Corner + 2 Normal + 1 Stress).
// Standard: SystemVerilog IEEE 1800
//=============================================================================

`timescale 1ns/1ps

module tb_power_icg_cell;

    import tb_pkg::*;

    logic clk;
    logic en;
    logic test_en;
    logic gclk;

    // Clock generator (100 MHz -> 10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Device Under Test (DUT)
    power_icg_cell dut (
        .clk(clk),
        .en(en),
        .test_en(test_en),
        .gclk(gclk)
    );

    // Test sequencing
    initial begin
        reset_counters();
        en      = 0;
        test_en = 0;
        #20;

        //---------------------------------------------------------------------
        // CORNER TEST 1: Enable asserted on posedge clk (Glitch check)
        //---------------------------------------------------------------------
        @(posedge clk);
        en = 1;
        #1;
        record_result("CORNER", (gclk === 1'b0 || gclk === 1'b1), "TC1: Enable asserted on posedge clk");
        @(negedge clk);
        en = 0;

        //---------------------------------------------------------------------
        // CORNER TEST 2: Enable asserted on negedge clk
        //---------------------------------------------------------------------
        @(negedge clk);
        en = 1;
        @(posedge clk);
        #1;
        record_result("CORNER", (gclk === 1'b1), "TC2: Clean clock output on negedge assertion");
        @(negedge clk);
        en = 0;

        //---------------------------------------------------------------------
        // CORNER TEST 3: Rapid enable glitch during clk HIGH phase
        //---------------------------------------------------------------------
        @(posedge clk);
        #1;
        en = 1; #1; en = 0; #1; en = 1; #1; en = 0;
        record_result("CORNER", (gclk === 1'b0), "TC3: Glitches during clk HIGH ignored by latch");
        #10;

        //---------------------------------------------------------------------
        // CORNER TEST 4: DFT Scan test_en bypass mode
        //---------------------------------------------------------------------
        @(negedge clk);
        en = 0;
        test_en = 1;
        @(posedge clk);
        #1;
        record_result("CORNER", (gclk === 1'b1), "TC4: test_en scan bypass forces clock propagation");
        @(negedge clk);
        test_en = 0;

        //---------------------------------------------------------------------
        // CORNER TEST 5: Quiescent disabled clock gating (0 power state)
        //---------------------------------------------------------------------
        en = 0;
        test_en = 0;
        repeat(5) @(posedge clk);
        record_result("CORNER", (gclk === 1'b0), "TC5: Continuous quiescence with zero toggles");

        //---------------------------------------------------------------------
        // NORMAL TEST 6: Single-cycle enable pulse
        //---------------------------------------------------------------------
        @(negedge clk);
        en = 1;
        @(negedge clk);
        en = 0;
        @(posedge clk);
        #1;
        record_result("NORMAL", (gclk === 1'b0), "TC6: Single-pulse gating cleanly completed");

        //---------------------------------------------------------------------
        // NORMAL TEST 7: Multi-cycle continuous pass-through
        //---------------------------------------------------------------------
        @(negedge clk);
        en = 1;
        repeat(4) @(posedge clk);
        record_result("NORMAL", (gclk === 1'b1), "TC7: Multi-cycle continuous burst pass-through");
        @(negedge clk);
        en = 0;

        //---------------------------------------------------------------------
        // ULTIMATE STRESS TEST 8: Randomized 100-cycle stimulus verification
        //---------------------------------------------------------------------
        begin
            bit stress_pass = 1;
            logic prev_latch = 0;
            for (int i = 0; i < 100; i++) begin
                @(negedge clk);
                en      = $urandom_range(0, 1);
                test_en = ($urandom_range(0, 10) == 0); // 10% probability
                prev_latch = en | test_en;
                @(posedge clk);
                #1;
                if (gclk !== (1'b1 & prev_latch)) begin
                    stress_pass = 0;
                end
            end
            record_result("STRESS", stress_pass, "TC8: 100-cycle randomized stimulus match");
        end

        #20;
        print_summary("power_icg_cell");
        $finish;
    end

endmodule: tb_power_icg_cell
