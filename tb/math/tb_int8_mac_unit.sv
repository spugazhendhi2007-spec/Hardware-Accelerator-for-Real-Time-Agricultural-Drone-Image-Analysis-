//=============================================================================
// File: tb_int8_mac_unit.sv
// Description: Self-checking testbench for int8_mac_unit adhering to the
//              standard 8-test verification suite (5 Corner + 2 Normal + 1 Stress).
// Standard: SystemVerilog IEEE 1800
//=============================================================================

`timescale 1ns/1ps

module tb_int8_mac_unit;

    import tb_pkg::*;

    logic                     clk;
    logic                     rst_n;
    logic                     enable;
    logic                     clr_acc;
    logic signed [7:0]        pixel_in;
    logic signed [7:0]        weight_in;
    logic signed [23:0]       bias_in;
    logic signed [23:0]       acc_out;
    logic                     valid_out;

    // Clock generator (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // DUT
    int8_mac_unit dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .clr_acc(clr_acc),
        .pixel_in(pixel_in),
        .weight_in(weight_in),
        .bias_in(bias_in),
        .acc_out(acc_out),
        .valid_out(valid_out)
    );

    // Test sequence
    initial begin
        reset_counters();
        rst_n     = 0;
        enable    = 0;
        clr_acc   = 0;
        pixel_in  = '0;
        weight_in = '0;
        bias_in   = '0;
        #20;
        rst_n = 1;
        #10;

        //---------------------------------------------------------------------
        // CORNER TEST 1: Multiplication by Zero & Operand Isolation
        //---------------------------------------------------------------------
        @(posedge clk);
        enable = 1; clr_acc = 1; pixel_in = 8'sd0; weight_in = 8'sd127; bias_in = 24'sd0;
        @(posedge clk);
        #1;
        record_result("CORNER", (acc_out === 24'sd0 && valid_out === 1'b1), "TC1: Zero input yields zero product");

        //---------------------------------------------------------------------
        // CORNER TEST 2: Maximum positive product (+127 * +127 = +16129)
        //---------------------------------------------------------------------
        @(posedge clk);
        enable = 1; clr_acc = 1; pixel_in = 8'sd127; weight_in = 8'sd127; bias_in = 24'sd0;
        @(posedge clk);
        #1;
        record_result("CORNER", (acc_out === 24'sd16129), "TC2: Max positive product (+127*+127 = 16129)");

        //---------------------------------------------------------------------
        // CORNER TEST 3: Extreme negative products (-128 * +127 = -16256)
        //---------------------------------------------------------------------
        @(posedge clk);
        enable = 1; clr_acc = 1; pixel_in = -8'sd128; weight_in = 8'sd127; bias_in = 24'sd0;
        @(posedge clk);
        #1;
        record_result("CORNER", (acc_out === -24'sd16256), "TC3: Max negative product (-128*+127 = -16256)");

        //---------------------------------------------------------------------
        // CORNER TEST 4: Reset mid-accumulation clears accumulator
        //---------------------------------------------------------------------
        @(posedge clk);
        enable = 1; clr_acc = 0; pixel_in = 8'sd50; weight_in = 8'sd50;
        @(posedge clk);
        rst_n = 0;
        @(posedge clk);
        #1;
        record_result("CORNER", (acc_out === 24'sd0 && valid_out === 1'b0), "TC4: Reset clears accumulator to 0");
        rst_n = 1;

        //---------------------------------------------------------------------
        // CORNER TEST 5: Large signed bias initial load (+50000 + 10*10 = 50100)
        //---------------------------------------------------------------------
        @(posedge clk);
        enable = 1; clr_acc = 1; pixel_in = 8'sd10; weight_in = 8'sd10; bias_in = 24'sd50000;
        @(posedge clk);
        #1;
        record_result("CORNER", (acc_out === 24'sd50100), "TC5: Large bias initialization verified");

        //---------------------------------------------------------------------
        // NORMAL TEST 6: Standard 9-element 3x3 Conv accumulation
        //---------------------------------------------------------------------
        begin
            longint golden_sum = 0;
            bit normal_pass = 1;
            logic signed [7:0] px[9] = '{-8'sd10, 8'sd20, -8'sd30, 8'sd40, -8'sd50, 8'sd60, -8'sd70, 8'sd80, -8'sd90};
            logic signed [7:0] wt[9] = '{8'sd1,   -8'sd2, 8'sd1,   -8'sd1, 8'sd2,   -8'sd1, 8'sd1,   -8'sd2, 8'sd1};

            for (int i = 0; i < 9; i++) begin
                @(posedge clk);
                enable    = 1;
                clr_acc   = (i == 0);
                bias_in   = 24'sd100;
                pixel_in  = px[i];
                weight_in = wt[i];
                if (i == 0) golden_sum = 100 + (px[i] * wt[i]);
                else        golden_sum = golden_sum + (px[i] * wt[i]);
            end
            @(posedge clk);
            enable = 0;
            #1;
            record_result("NORMAL", (acc_out === golden_sum), $sformatf("TC6: 9-element accumulation matches golden (%0d == %0d)", acc_out, golden_sum));
        end

        //---------------------------------------------------------------------
        // NORMAL TEST 7: Continuous multi-batch stream with clear pulses
        //---------------------------------------------------------------------
        begin
            bit batch_pass = 1;
            // Batch 1
            @(posedge clk); enable = 1; clr_acc = 1; pixel_in = 8'sd5; weight_in = 8'sd10; bias_in = 24'sd0;
            @(posedge clk); enable = 1; clr_acc = 0; pixel_in = 8'sd5; weight_in = 8'sd10;
            @(posedge clk); #1;
            if (acc_out !== 24'sd100) batch_pass = 0;

            // Batch 2
            @(posedge clk); enable = 1; clr_acc = 1; pixel_in = 8'sd4; weight_in = 8'sd5; bias_in = 24'sd20;
            @(posedge clk); #1;
            if (acc_out !== 24'sd40) batch_pass = 0;

            record_result("NORMAL", batch_pass, "TC7: Multiple batch execution with clear pulses verified");
            enable = 0;
        end

        //---------------------------------------------------------------------
        // ULTIMATE STRESS TEST 8: 500 Randomized MAC Operations vs 64-bit Golden
        //---------------------------------------------------------------------
        begin
            longint golden_acc = 0;
            bit stress_pass = 1;

            for (int s = 0; s < 500; s++) begin
                logic signed [7:0]  rand_px   = $urandom_range(0, 255);
                logic signed [7:0]  rand_wt   = $urandom_range(0, 255);
                logic signed [23:0] rand_bias = $urandom_range(0, 1000);
                bit                 rand_clr  = ($urandom_range(0, 10) == 0);

                @(posedge clk);
                enable    = 1;
                clr_acc   = rand_clr;
                pixel_in  = rand_px;
                weight_in = rand_wt;
                bias_in   = rand_bias;

                if (rand_clr) golden_acc = rand_bias + (rand_px * rand_wt);
                else          golden_acc = golden_acc + (rand_px * rand_wt);

                @(posedge clk);
                #1;
                if (acc_out !== golden_acc[23:0]) begin
                    stress_pass = 0;
                end
            end
            enable = 0;
            record_result("STRESS", stress_pass, "TC8: 500 randomized MAC cycles verified against 64-bit golden accumulator");
        end

        #20;
        print_summary("int8_mac_unit");
        $finish;
    end

endmodule: tb_int8_mac_unit
