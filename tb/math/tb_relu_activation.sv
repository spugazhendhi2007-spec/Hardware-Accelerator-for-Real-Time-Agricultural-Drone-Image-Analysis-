//=============================================================================
// File: tb_relu_activation.sv
// Description: Self-checking testbench for relu_activation adhering to the
//              standard 8-test verification suite (5 Corner + 2 Normal + 1 Stress).
// Standard: SystemVerilog IEEE 1800 (Clean 0-warning compilation)
//=============================================================================

`timescale 1ns/1ps

module tb_relu_activation;

    import tb_pkg::*;

    logic signed [23:0] data_in;
    logic signed [15:0] data_out;

    // DUT
    relu_activation dut (
        .data_in(data_in),
        .data_out(data_out)
    );

    // Test sequence
    initial begin : test_seq
        automatic bit ramp_pass = 1;
        automatic bit stress_pass = 1;

        reset_counters();
        data_in = '0;
        #10;

        //---------------------------------------------------------------------
        // CORNER TEST 1: Zero Input
        //---------------------------------------------------------------------
        data_in = 24'sd0;
        #1;
        record_result("CORNER", (data_out === 16'sd0), "TC1: Exact 0 input produces 0 output");

        //---------------------------------------------------------------------
        // CORNER TEST 2: Extreme Negative Input (-500000)
        //---------------------------------------------------------------------
        data_in = -24'sd500000;
        #1;
        record_result("CORNER", (data_out === 16'sd0), "TC2: Large negative value clamped to 0");

        //---------------------------------------------------------------------
        // CORNER TEST 3: Extreme Positive Saturation (+500000)
        //---------------------------------------------------------------------
        data_in = 24'sd500000;
        #1;
        record_result("CORNER", (data_out === 16'sd32767), "TC3: Large positive value saturated to 32767");

        //---------------------------------------------------------------------
        // CORNER TEST 4: Exact Threshold Boundaries (+32767 and +32768)
        //---------------------------------------------------------------------
        data_in = 24'sd32767;
        #1;
        record_result("CORNER", (data_out === 16'sd32767), "TC4: Upper threshold +32767 preserved exactly");
        data_in = 24'sd32768;
        #1;
        record_result("CORNER", (data_out === 16'sd32767), "TC4b: Upper threshold +32768 clamped to 32767");

        //---------------------------------------------------------------------
        // CORNER TEST 5: Unit Step Transitions (-1 and +1)
        //---------------------------------------------------------------------
        data_in = -24'sd1;
        #1;
        record_result("CORNER", (data_out === 16'sd0), "TC5: -1 clamped to 0");
        data_in = 24'sd1;
        #1;
        record_result("CORNER", (data_out === 16'sd1), "TC5b: +1 passed through as +1");

        //---------------------------------------------------------------------
        // NORMAL TEST 6: Typical positive activation (+1024, +20480)
        //---------------------------------------------------------------------
        data_in = 24'sd1024;
        #1;
        record_result("NORMAL", (data_out === 16'sd1024), "TC6: Linear pass-through for +1024");
        data_in = 24'sd20480;
        #1;
        record_result("NORMAL", (data_out === 16'sd20480), "TC6b: Linear pass-through for +20480");

        //---------------------------------------------------------------------
        // NORMAL TEST 7: Alternating positive and negative ramp
        //---------------------------------------------------------------------
        ramp_pass = 1;
        for (int i = -100; i <= 100; i += 10) begin
            data_in = i;
            #1;
            if (i <= 0 && data_out !== 16'sd0) ramp_pass = 0;
            if (i > 0 && data_out !== i[15:0]) ramp_pass = 0;
        end
        record_result("NORMAL", ramp_pass, "TC7: Alternating bipolar ramp verified");

        //---------------------------------------------------------------------
        // ULTIMATE STRESS TEST 8: 1000 Randomized 24-bit Inputs
        //---------------------------------------------------------------------
        stress_pass = 1;
        for (int s = 0; s < 1000; s++) begin
            automatic logic signed [23:0] rand_val = $urandom_range(0, 32'h00FFFFFF) - 24'sd8388608;
            automatic logic signed [15:0] exp_val;
            if (rand_val <= 0) exp_val = 16'sd0;
            else if (rand_val > 24'sd32767) exp_val = 16'sd32767;
            else exp_val = rand_val[15:0];

            data_in = rand_val;
            #1;
            if (data_out !== exp_val) begin
                stress_pass = 0;
            end
        end
        record_result("STRESS", stress_pass, "TC8: 1000 randomized 24-bit inputs matched golden model");

        #10;
        print_summary("relu_activation");
        $finish;
    end : test_seq

endmodule: tb_relu_activation
