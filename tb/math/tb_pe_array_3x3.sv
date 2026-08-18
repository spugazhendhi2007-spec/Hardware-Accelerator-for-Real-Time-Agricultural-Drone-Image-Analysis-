//=============================================================================
// File: tb_pe_array_3x3.sv
// Description: Self-checking testbench for pe_array_3x3 adhering to the
//              standard 8-test verification suite (5 Corner + 2 Normal + 1 Stress).
// Standard: SystemVerilog IEEE 1800
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
    initial begin
        reset_counters();
        rst_n  = 0;
        enable = 0;
        {p0,p1,p2,p3,p4,p5,p6,p7,p8} = '0;
        {w0,w1,w2,w3,w4,w5,w6,w7,w8} = '0;
        bias   = '0;
        #20;
        rst_n  = 1;
        #10;

        //---------------------------------------------------------------------
        // CORNER TEST 1: All Zero Inputs
        //---------------------------------------------------------------------
        @(posedge clk);
        enable = 1; bias = 24'sd0;
        {p0,p1,p2,p3,p4,p5,p6,p7,p8} = '0;
        {w0,w1,w2,w3,w4,w5,w6,w7,w8} = '{8'sd10, 8'sd10, 8'sd10, 8'sd10, 8'sd10, 8'sd10, 8'sd10, 8'sd10, 8'sd10};
        @(posedge clk);
        #1;
        record_result("CORNER", (conv_out === 24'sd0 && valid_out === 1'b1), "TC1: All-zero pixels yield zero convolution");

        //---------------------------------------------------------------------
        // CORNER TEST 2: Maximum positive range (9 * 127 * 127 = 145161)
        //---------------------------------------------------------------------
        @(posedge clk);
        enable = 1; bias = 24'sd0;
        {p0,p1,p2,p3,p4,p5,p6,p7,p8} = '{8'sd127, 8'sd127, 8'sd127, 8'sd127, 8'sd127, 8'sd127, 8'sd127, 8'sd127, 8'sd127};
        {w0,w1,w2,w3,w4,w5,w6,w7,w8} = '{8'sd127, 8'sd127, 8'sd127, 8'sd127, 8'sd127, 8'sd127, 8'sd127, 8'sd127, 8'sd127};
        @(posedge clk);
        #1;
        record_result("CORNER", (conv_out === 24'sd145161), "TC2: Max positive convolution range (+145161)");

        //---------------------------------------------------------------------
        // CORNER TEST 3: Maximum negative range (9 * -128 * 127 = -146304)
        //---------------------------------------------------------------------
        @(posedge clk);
        enable = 1; bias = 24'sd0;
        {p0,p1,p2,p3,p4,p5,p6,p7,p8} = '{-8'sd128, -8'sd128, -8'sd128, -8'sd128, -8'sd128, -8'sd128, -8'sd128, -8'sd128, -8'sd128};
        {w0,w1,w2,w3,w4,w5,w6,w7,w8} = '{8'sd127, 8'sd127, 8'sd127, 8'sd127, 8'sd127, 8'sd127, 8'sd127, 8'sd127, 8'sd127};
        @(posedge clk);
        #1;
        record_result("CORNER", (conv_out === -24'sd146304), "TC3: Max negative convolution range (-146304)");

        //---------------------------------------------------------------------
        // CORNER TEST 4: Reset mid-computation
        //---------------------------------------------------------------------
        @(posedge clk);
        rst_n = 0;
        @(posedge clk);
        #1;
        record_result("CORNER", (conv_out === 24'sd0 && valid_out === 1'b0), "TC4: Reset clears PE output registers");
        rst_n = 1;

        //---------------------------------------------------------------------
        // CORNER TEST 5: Non-zero Bias Cancellation (+500 - 500 = 0)
        //---------------------------------------------------------------------
        @(posedge clk);
        enable = 1;
        bias = -24'sd500;
        {p0,p1,p2,p3,p4,p5,p6,p7,p8} = '{8'sd50, 8'sd0, 8'sd0, 8'sd0, 8'sd0, 8'sd0, 8'sd0, 8'sd0, 8'sd0};
        {w0,w1,w2,w3,w4,w5,w6,w7,w8} = '{8'sd10, 8'sd0, 8'sd0, 8'sd0, 8'sd0, 8'sd0, 8'sd0, 8'sd0, 8'sd0};
        @(posedge clk);
        #1;
        record_result("CORNER", (conv_out === 24'sd0), "TC5: Bias exact cancellation verified (500 - 500 = 0)");

        //---------------------------------------------------------------------
        // NORMAL TEST 6: Sobel Horizontal Edge Filter
        //---------------------------------------------------------------------
        @(posedge clk);
        enable = 1; bias = 24'sd0;
        // Pixel step edge: Left column = 10, Middle column = 50, Right column = 100
        {p0,p1,p2,p3,p4,p5,p6,p7,p8} = '{8'sd10, 8'sd50, 8'sd100, 8'sd10, 8'sd50, 8'sd100, 8'sd10, 8'sd50, 8'sd100};
        // Sobel X kernel: [-1, 0, 1; -2, 0, 2; -1, 0, 1]
        {w0,w1,w2,w3,w4,w5,w6,w7,w8} = '{-8'sd1, 8'sd0, 8'sd1, -8'sd2, 8'sd0, 8'sd2, -8'sd1, 8'sd0, 8'sd1};
        @(posedge clk);
        #1;
        // Expected: (100 - 10) + 2*(100 - 10) + (100 - 10) = 90 + 180 + 90 = 360
        record_result("NORMAL", (conv_out === 24'sd360), "TC6: Sobel edge convolution gradient matches golden (360)");

        //---------------------------------------------------------------------
        // NORMAL TEST 7: Gaussian Blur Smoothing Filter
        //---------------------------------------------------------------------
        @(posedge clk);
        enable = 1; bias = 24'sd0;
        {p0,p1,p2,p3,p4,p5,p6,p7,p8} = '{8'sd16, 8'sd16, 8'sd16, 8'sd16, 8'sd16, 8'sd16, 8'sd16, 8'sd16, 8'sd16};
        // Normalized weights [1, 2, 1; 2, 4, 2; 1, 2, 1] (sum = 16)
        {w0,w1,w2,w3,w4,w5,w6,w7,w8} = '{8'sd1, 8'sd2, 8'sd1, 8'sd2, 8'sd4, 8'sd2, 8'sd1, 8'sd2, 8'sd1};
        @(posedge clk);
        #1;
        // Expected: 16 * 16 = 256
        record_result("NORMAL", (conv_out === 24'sd256), "TC7: Gaussian kernel smoothing sum matches golden (256)");

        //---------------------------------------------------------------------
        // ULTIMATE STRESS TEST 8: 200 Randomized Convolution Windows
        //---------------------------------------------------------------------
        begin
            bit stress_pass = 1;
            for (int s = 0; s < 200; s++) begin
                logic signed [7:0]  rand_p[9], rand_w[9];
                logic signed [23:0] rand_b = $urandom_range(0, 500) - 250;
                longint golden_conv = rand_b;

                for (int i = 0; i < 9; i++) begin
                    rand_p[i] = $urandom_range(0, 255);
                    rand_w[i] = $urandom_range(0, 255);
                    golden_conv += (rand_p[i] * rand_w[i]);
                end

                @(posedge clk);
                enable = 1;
                bias = rand_b;
                p0 = rand_p[0]; p1 = rand_p[1]; p2 = rand_p[2];
                p3 = rand_p[3]; p4 = rand_p[4]; p5 = rand_p[5];
                p6 = rand_p[6]; p7 = rand_p[7]; p8 = rand_p[8];
                w0 = rand_w[0]; w1 = rand_w[1]; w2 = rand_w[2];
                w3 = rand_w[3]; w4 = rand_w[4]; w5 = rand_w[5];
                w6 = rand_w[6]; w7 = rand_w[7]; w8 = rand_w[8];

                @(posedge clk);
                #1;
                if (conv_out !== golden_conv[23:0]) begin
                    stress_pass = 0;
                end
            end
            enable = 0;
            record_result("STRESS", stress_pass, "TC8: 200 randomized 3x3 convolutions matched golden reduction model");
        end

        #20;
        print_summary("pe_array_3x3");
        $finish;
    end

endmodule: tb_pe_array_3x3
