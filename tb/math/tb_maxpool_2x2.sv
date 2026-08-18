//=============================================================================
// File: tb_maxpool_2x2.sv
// Description: Self-checking testbench for maxpool_2x2 adhering to the
//              standard 8-test verification suite (5 Corner + 2 Normal + 1 Stress).
// Standard: SystemVerilog IEEE 1800
//=============================================================================

`timescale 1ns/1ps

module tb_maxpool_2x2;

    import tb_pkg::*;

    logic signed [15:0] a, b, c, d;
    logic signed [15:0] max_out;

    // DUT
    maxpool_2x2 dut (
        .a(a), .b(b), .c(c), .d(d),
        .max_out(max_out)
    );

    // Test sequence
    initial begin
        reset_counters();
        {a, b, c, d} = '0;
        #10;

        //---------------------------------------------------------------------
        // CORNER TEST 1: All Identical Inputs
        //---------------------------------------------------------------------
        a = 16'sd100; b = 16'sd100; c = 16'sd100; d = 16'sd100;
        #1;
        record_result("CORNER", (max_out === 16'sd100), "TC1: All identical inputs return exact value");

        //---------------------------------------------------------------------
        // CORNER TEST 2: All Negative Inputs
        //---------------------------------------------------------------------
        a = -16'sd50; b = -16'sd20; c = -16'sd100; d = -16'sd10;
        #1;
        record_result("CORNER", (max_out === -16'sd10), "TC2: All negative inputs select closest to zero (-10)");

        //---------------------------------------------------------------------
        // CORNER TEST 3: Permutation of Maximum in Positions a, b, c, d
        //---------------------------------------------------------------------
        begin
            bit perm_pass = 1;
            a = 16'sd999; b = 16'sd1; c = 16'sd2; d = 16'sd3; #1; if (max_out !== 16'sd999) perm_pass = 0;
            a = 16'sd1; b = 16'sd999; c = 16'sd2; d = 16'sd3; #1; if (max_out !== 16'sd999) perm_pass = 0;
            a = 16'sd1; b = 16'sd2; c = 16'sd999; d = 16'sd3; #1; if (max_out !== 16'sd999) perm_pass = 0;
            a = 16'sd1; b = 16'sd2; c = 16'sd3; d = 16'sd999; #1; if (max_out !== 16'sd999) perm_pass = 0;
            record_result("CORNER", perm_pass, "TC3: Maximum located in each of 4 port positions verified");
        end

        //---------------------------------------------------------------------
        // CORNER TEST 4: Extreme Range Limits (-32768 and +32767)
        //---------------------------------------------------------------------
        a = -16'sd32768; b = 16'sd32767; c = 16'sd0; d = -16'sd1;
        #1;
        record_result("CORNER", (max_out === 16'sd32767), "TC4: Extreme signed 16-bit dynamic limits handled");

        //---------------------------------------------------------------------
        // CORNER TEST 5: Duplicate Maximum Values
        //---------------------------------------------------------------------
        a = 16'sd500; b = 16'sd500; c = 16'sd100; d = 16'sd200;
        #1;
        record_result("CORNER", (max_out === 16'sd500), "TC5: Duplicate maxima correctly selected");

        //---------------------------------------------------------------------
        // NORMAL TEST 6: Standard Positive Feature Patch
        //---------------------------------------------------------------------
        a = 16'sd120; b = 16'sd340; c = 16'sd50; d = 16'sd210;
        #1;
        record_result("NORMAL", (max_out === 16'sd340), "TC6: Typical spatial feature pooling (340)");

        //---------------------------------------------------------------------
        // NORMAL TEST 7: Single Active Hotspot among Zeros
        //---------------------------------------------------------------------
        a = 16'sd0; b = 16'sd0; c = 16'sd85; d = 16'sd0;
        #1;
        record_result("NORMAL", (max_out === 16'sd85), "TC7: Single active hotspot detected cleanly (85)");

        //---------------------------------------------------------------------
        // ULTIMATE STRESS TEST 8: 500 Randomized 4-Tuples
        //---------------------------------------------------------------------
        begin
            bit stress_pass = 1;
            for (int s = 0; s < 500; s++) begin
                logic signed [15:0] ra = $urandom_range(0, 65535);
                logic signed [15:0] rb = $urandom_range(0, 65535);
                logic signed [15:0] rc = $urandom_range(0, 65535);
                logic signed [15:0] rd = $urandom_range(0, 65535);
                logic signed [15:0] exp_max = ra;
                if (rb > exp_max) exp_max = rb;
                if (rc > exp_max) exp_max = rc;
                if (rd > exp_max) exp_max = rd;

                a = ra; b = rb; c = rc; d = rd;
                #1;
                if (max_out !== exp_max) begin
                    stress_pass = 0;
                end
            end
            record_result("STRESS", stress_pass, "TC8: 500 randomized 4-tuple pooling operations matched golden max()");
        end

        #10;
        print_summary("maxpool_2x2");
        $finish;
    end

endmodule: tb_maxpool_2x2
