//=============================================================================
// File: tb_pe_array_3x3.sv
// Description: Self-checking testbench for pe_array_3x3 adhering to the
//              standard 8-test verification suite (5 Corner + 2 Normal + 1 Stress).
// Standard: SystemVerilog IEEE 1800 (Clean 0-warning compilation)
//=============================================================================

`timescale 1ns/1ps

module tb_pe_array_3x3;

    import tb_pkg::*;

    logic                     clk;
    logic                     rst_n;
    logic                     enable;
    logic signed [7:0]        p0, p1, p2, p3, p4, p5, p6, p7, p8;
    logic signed [7:0]        w0, w1, w2, w3, w4, w5, w6, w7, w8;
    logic signed [23:0]       bias;
    logic signed [23:0]       conv_out;
    logic                     valid_out;

    // Clock generator (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // DUT
    pe_array_3x3 dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .p0(p0), .p1(p1), .p2(p2),
        .p3(p3), .p4(p4), .p5(p5),
        .p6(p6), .p7(p7), .p8(p8),
        .w0(w0), .w1(w1), .w2(w2),
        .w3(w3), .w4(w4), .w5(w5),
        .w6(w6), .w7(w7), .w8(w8),
        .bias(bias),
        .conv_out(conv_out),
        .valid_out(valid_out)
    );

    // Test sequence
    initial begin : test_seq
        automatic bit sobel_pass = 1;
        automatic bit blur_pass = 1;
        automatic bit stress_pass = 1;

        reset_counters();
        rst_n  = 0;
        enable = 0;
        p0 = '0; p1 = '0; p2 = '0; p3 = '0; p4 = '0; p5 = '0; p6 = '0; p7 = '0; p8 = '0;
        w0 = '0; w1 = '0; w2 = '0; w3 = '0; w4 = '0; w5 = '0; w6 = '0; w7 = '0; w8 = '0;
        bias   = '0;
        #20;
        rst_n  = 1;
        #10;

        //---------------------------------------------------------------------
        // CORNER TEST 1: All Zero Inputs
        //---------------------------------------------------------------------
        @(negedge clk);
        enable = 1; bias = 24'sd0;
        p0 = 8'sd0; p1 = 8'sd0; p2 = 8'sd0; p3 = 8'sd0; p4 = 8'sd0; p5 = 8'sd0; p6 = 8'sd0; p7 = 8'sd0; p8 = 8'sd0;
        w0 = 8'sd10; w1 = 8'sd10; w2 = 8'sd10; w3 = 8'sd10; w4 = 8'sd10; w5 = 8'sd10; w6 = 8'sd10; w7 = 8'sd10; w8 = 8'sd10;
        @(posedge clk);
        #1;
        record_result("CORNER", (conv_out === 24'sd0 && valid_out === 1'b1), "TC1: All-zero pixels yield zero convolution");

        //---------------------------------------------------------------------
        // CORNER TEST 2: Maximum positive range (9 * 127 * 127 = 145161)
        //---------------------------------------------------------------------
        @(negedge clk);
        enable = 1; bias = 24'sd0;
        p0 = 8'sd127; p1 = 8'sd127; p2 = 8'sd127; p3 = 8'sd127; p4 = 8'sd127; p5 = 8'sd127; p6 = 8'sd127; p7 = 8'sd127; p8 = 8'sd127;
        w0 = 8'sd127; w1 = 8'sd127; w2 = 8'sd127; w3 = 8'sd127; w4 = 8'sd127; w5 = 8'sd127; w6 = 8'sd127; w7 = 8'sd127; w8 = 8'sd127;
        @(posedge clk);
        #1;
        record_result("CORNER", (conv_out === 24'sd145161), "TC2: Max positive convolution range (+145161)");

        //---------------------------------------------------------------------
        // CORNER TEST 3: Maximum negative range (9 * -128 * 127 = -146304)
        //---------------------------------------------------------------------
        @(negedge clk);
        enable = 1; bias = 24'sd0;
        p0 = -8'sd128; p1 = -8'sd128; p2 = -8'sd128; p3 = -8'sd128; p4 = -8'sd128; p5 = -8'sd128; p6 = -8'sd128; p7 = -8'sd128; p8 = -8'sd128;
        w0 = 8'sd127; w1 = 8'sd127; w2 = 8'sd127; w3 = 8'sd127; w4 = 8'sd127; w5 = 8'sd127; w6 = 8'sd127; w7 = 8'sd127; w8 = 8'sd127;
        @(posedge clk);
        #1;
        record_result("CORNER", (conv_out === -24'sd146304), "TC3: Max negative convolution range (-146304)");

        //---------------------------------------------------------------------
        // CORNER TEST 4: Reset mid-computation
        //---------------------------------------------------------------------
        @(negedge clk);
        rst_n = 0;
        @(posedge clk);
        #1;
        record_result("CORNER", (conv_out === 24'sd0 && valid_out === 1'b0), "TC4: Reset clears PE output registers");
        @(negedge clk);
        rst_n = 1;

        //---------------------------------------------------------------------
        // CORNER TEST 5: Bias cancellation to exactly zero
        //---------------------------------------------------------------------
        @(negedge clk);
        enable = 1;
        p0 = 8'sd10; p1 = 8'sd0; p2 = 8'sd0; p3 = 8'sd0; p4 = 8'sd0; p5 = 8'sd0; p6 = 8'sd0; p7 = 8'sd0; p8 = 8'sd0;
        w0 = 8'sd10; w1 = 8'sd0; w2 = 8'sd0; w3 = 8'sd0; w4 = 8'sd0; w5 = 8'sd0; w6 = 8'sd0; w7 = 8'sd0; w8 = 8'sd0;
        bias = -24'sd100;
        @(posedge clk);
        #1;
        record_result("CORNER", (conv_out === 24'sd0), "TC5: Negative bias exactly cancels dot product");

        //---------------------------------------------------------------------
        // NORMAL TEST 6: Standard Sobel Horizontal Edge Kernel
        //---------------------------------------------------------------------
        @(negedge clk);
        enable = 1; bias = 24'sd0;
        w0 = -8'sd1; w1 = -8'sd2; w2 = -8'sd1;
        w3 =  8'sd0; w4 =  8'sd0; w5 =  8'sd0;
        w6 =  8'sd1; w7 =  8'sd2; w8 =  8'sd1;

        p0 = 8'sd10; p1 = 8'sd10; p2 = 8'sd10;
        p3 = 8'sd20; p4 = 8'sd20; p5 = 8'sd20;
        p6 = 8'sd50; p7 = 8'sd50; p8 = 8'sd50;

        @(posedge clk);
        #1;
        sobel_pass = (conv_out === 24'sd160);
        record_result("NORMAL", sobel_pass, "TC6: Sobel horizontal edge response (+160)");

        //---------------------------------------------------------------------
        // NORMAL TEST 7: Gaussian Blur Weighted Smoothing Kernel
        //---------------------------------------------------------------------
        @(negedge clk);
        enable = 1; bias = 24'sd0;
        w0 = 8'sd1; w1 = 8'sd2; w2 = 8'sd1;
        w3 = 8'sd2; w4 = 8'sd4; w5 = 8'sd2;
        w6 = 8'sd1; w7 = 8'sd2; w8 = 8'sd1;

        p0 = 8'sd16; p1 = 8'sd16; p2 = 8'sd16;
        p3 = 8'sd16; p4 = 8'sd16; p5 = 8'sd16;
        p6 = 8'sd16; p7 = 8'sd16; p8 = 8'sd16;

        @(posedge clk);
        #1;
        blur_pass = (conv_out === 24'sd256);
        record_result("NORMAL", blur_pass, "TC7: Gaussian blur uniform smoothing (+256)");

        //---------------------------------------------------------------------
        // ULTIMATE STRESS TEST 8: 200 Randomized 3x3 Dot Products
        //---------------------------------------------------------------------
        stress_pass = 1;
        for (int s = 0; s < 200; s++) begin
            automatic logic signed [7:0] rp[8:0];
            automatic logic signed [7:0] rw[8:0];
            automatic logic signed [23:0] rb = $urandom_range(0, 2000) - 1000;
            automatic longint exp_sum = rb;

            for (int i = 0; i < 9; i++) begin
                rp[i] = $urandom_range(0, 255);
                rw[i] = $urandom_range(0, 255);
                exp_sum += (rp[i] * rw[i]);
            end

            @(negedge clk);
            enable = 1; bias = rb;
            p0 = rp[0]; p1 = rp[1]; p2 = rp[2];
            p3 = rp[3]; p4 = rp[4]; p5 = rp[5];
            p6 = rp[6]; p7 = rp[7]; p8 = rp[8];

            w0 = rw[0]; w1 = rw[1]; w2 = rw[2];
            w3 = rw[3]; w4 = rw[4]; w5 = rw[5];
            w6 = rw[6]; w7 = rw[7]; w8 = rw[8];

            @(posedge clk);
            #1;
            if (conv_out !== exp_sum[23:0]) begin
                stress_pass = 0;
            end
        end
        @(negedge clk);
        enable = 0;
        record_result("STRESS", stress_pass, "TC8: 200 randomized 3x3 PE dot products matched golden calculation");

        #20;
        print_summary("pe_array_3x3");
        $finish;
    end : test_seq

endmodule: tb_pe_array_3x3
