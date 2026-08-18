//=============================================================================
// File: tb_int8_mac_unit.sv
// Description: Self-checking testbench for int8_mac_unit adhering to the
//              standard 8-test verification suite (5 Corner + 2 Normal + 1 Stress).
// Standard: SystemVerilog IEEE 1800 (Clean 0-warning compilation)
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
    initial begin : test_seq
        automatic bit normal_seq_pass = 1;
        automatic bit normal_bias_pass = 1;
        automatic bit stress_pass = 1;
        automatic longint golden_acc = 0;

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
        @(negedge clk);
        enable = 1; clr_acc = 1; pixel_in = 8'sd0; weight_in = 8'sd127; bias_in = 24'sd0;
        @(posedge clk);
        #1;
        record_result("CORNER", (acc_out === 24'sd0 && valid_out === 1'b1), "TC1: Zero input yields zero product");

        //---------------------------------------------------------------------
        // CORNER TEST 2: Maximum positive product (+127 * +127 = +16129)
        //---------------------------------------------------------------------
        @(negedge clk);
        enable = 1; clr_acc = 1; pixel_in = 8'sd127; weight_in = 8'sd127; bias_in = 24'sd0;
        @(posedge clk);
        #1;
        record_result("CORNER", (acc_out === 24'sd16129), "TC2: Max positive product (+127*+127 = 16129)");

        //---------------------------------------------------------------------
        // CORNER TEST 3: Extreme negative products (-128 * +127 = -16256)
        //---------------------------------------------------------------------
        @(negedge clk);
        enable = 1; clr_acc = 1; pixel_in = -8'sd128; weight_in = 8'sd127; bias_in = 24'sd0;
        @(posedge clk);
        #1;
        record_result("CORNER", (acc_out === -24'sd16256), "TC3: Max negative product (-128*+127 = -16256)");

        //---------------------------------------------------------------------
        // CORNER TEST 4: Reset mid-accumulation clears accumulator
        //---------------------------------------------------------------------
        @(negedge clk);
        enable = 1; clr_acc = 0; pixel_in = 8'sd50; weight_in = 8'sd50;
        @(negedge clk);
        rst_n = 0;
        @(posedge clk);
        #1;
        record_result("CORNER", (acc_out === 24'sd0 && valid_out === 1'b0), "TC4: Reset clears accumulator to 0");
        @(negedge clk);
        rst_n = 1;

        //---------------------------------------------------------------------
        // CORNER TEST 5: Large signed bias initial load (+50000 + 10*10 = 50100)
        //---------------------------------------------------------------------
        @(negedge clk);
        enable = 1; clr_acc = 1; pixel_in = 8'sd10; weight_in = 8'sd10; bias_in = 24'sd50000;
        @(posedge clk);
        #1;
        record_result("CORNER", (acc_out === 24'sd50100), "TC5: Signed bias +50000 loaded with product");

        //---------------------------------------------------------------------
        // NORMAL TEST 6: 9-Element Sequential Convolution Dot Product
        //---------------------------------------------------------------------
        normal_seq_pass = 1;
        golden_acc = 0;
        for (int i = 0; i < 9; i++) begin
            automatic logic signed [7:0] p = 8'sd5 + i;
            automatic logic signed [7:0] w = 8'sd2;
            golden_acc += (p * w);

            @(negedge clk);
            enable = 1;
            clr_acc = (i == 0);
            pixel_in = p;
            weight_in = w;
            bias_in = 24'sd0;
        end
        @(posedge clk);
        #1;
        if (acc_out !== golden_acc[23:0]) normal_seq_pass = 0;
        record_result("NORMAL", normal_seq_pass, $sformatf("TC6: 9-MAC sequential dot-product (got %0d, exp %0d)", acc_out, golden_acc));

        //---------------------------------------------------------------------
        // NORMAL TEST 7: 9-Element Dot Product with Negative Bias (-500)
        //---------------------------------------------------------------------
        normal_bias_pass = 1;
        golden_acc = -500;
        for (int i = 0; i < 9; i++) begin
            automatic logic signed [7:0] p = 8'sd10;
            automatic logic signed [7:0] w = -8'sd2;
            golden_acc += (p * w);

            @(negedge clk);
            enable = 1;
            clr_acc = (i == 0);
            pixel_in = p;
            weight_in = w;
            bias_in = -24'sd500;
        end
        @(posedge clk);
        #1;
        if (acc_out !== golden_acc[23:0]) normal_bias_pass = 0;
        record_result("NORMAL", normal_bias_pass, "TC7: 9-MAC dot-product with negative bias verified");

        //---------------------------------------------------------------------
        // ULTIMATE STRESS TEST 8: 500 Randomized MAC operations vs 64-bit Golden
        //---------------------------------------------------------------------
        stress_pass = 1;
        golden_acc = 0;

        for (int s = 0; s < 500; s++) begin
            automatic logic signed [7:0] rand_p = $urandom_range(0, 255);
            automatic logic signed [7:0] rand_w = $urandom_range(0, 255);
            automatic logic signed [23:0] rand_b = $urandom_range(0, 65535) - 32768;
            automatic bit do_clr = (s % 9 == 0);

            if (do_clr) golden_acc = rand_b + (rand_p * rand_w);
            else        golden_acc += (rand_p * rand_w);

            @(negedge clk);
            enable    = 1;
            clr_acc   = do_clr;
            pixel_in  = rand_p;
            weight_in = rand_w;
            bias_in   = rand_b;

            @(posedge clk);
            #1;
            if (acc_out !== golden_acc[23:0]) begin
                stress_pass = 0;
            end
        end
        @(negedge clk);
        enable = 0;
        record_result("STRESS", stress_pass, "TC8: 500 randomized MAC operations matched 64-bit golden model");

        #20;
        print_summary("int8_mac_unit");
        $finish;
    end : test_seq

endmodule: tb_int8_mac_unit
