//=============================================================================
// File: tb_dense_classifier.sv
// Description: Self-checking testbench for dense_classifier adhering to the
//              standard 8-test verification suite (5 Corner + 2 Normal + 1 Stress).
// Standard: SystemVerilog IEEE 1800 (Clean 0-warning compilation)
//=============================================================================

`timescale 1ns/1ps

module tb_dense_classifier;

    import tb_pkg::*;

    localparam int NUM_FEATURES = 121;

    logic                     clk;
    logic                     rst_n;
    logic                     start;
    logic                     feat_valid;
    logic signed [15:0]       feat_data;
    logic [6:0]               feat_idx;
    logic signed [7:0]        w_cls0, w_cls1, w_cls2, w_cls3;
    logic signed [23:0]       bias0, bias1, bias2, bias3;
    logic signed [23:0]       score0, score1, score2, score3;
    logic                     cls_done;

    // Clock generator (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // DUT
    dense_classifier #(
        .NUM_FEATURES(NUM_FEATURES)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .feat_valid(feat_valid),
        .feat_data(feat_data),
        .feat_idx(feat_idx),
        .w_cls0(w_cls0), .w_cls1(w_cls1), .w_cls2(w_cls2), .w_cls3(w_cls3),
        .bias0(bias0), .bias1(bias1), .bias2(bias2), .bias3(bias3),
        .score0(score0), .score1(score1), .score2(score2), .score3(score3),
        .cls_done(cls_done)
    );

    // Test sequence
    initial begin : test_seq
        automatic bit stress_pass = 1;

        reset_counters();
        rst_n      = 0;
        start      = 0;
        feat_valid = 0;
        feat_data  = '0;
        feat_idx   = '0;
        w_cls0 = '0; w_cls1 = '0; w_cls2 = '0; w_cls3 = '0;
        bias0  = '0; bias1  = '0; bias2  = '0; bias3  = '0;
        #20;
        rst_n      = 1;
        #10;

        //---------------------------------------------------------------------
        // CORNER TEST 1: Reset during classification accumulation
        //---------------------------------------------------------------------
        @(negedge clk);
        start = 1; bias0 = 24'sd100;
        @(negedge clk); start = 0;
        feat_valid = 1; feat_data = 16'sd50; w_cls0 = 8'sd2;
        @(negedge clk);
        rst_n = 0;
        @(posedge clk);
        #1;
        record_result("CORNER", (score0 === 24'sd0 && cls_done === 1'b0), "TC1: Reset clears dense classifier accumulators");
        @(negedge clk);
        rst_n = 1; feat_valid = 0;
        #10;

        //---------------------------------------------------------------------
        // CORNER TEST 2: All Zero Features retain initial Biases
        //---------------------------------------------------------------------
        @(negedge clk);
        start = 1;
        bias0 = 24'sd10; bias1 = 24'sd20; bias2 = 24'sd30; bias3 = 24'sd40;
        @(negedge clk); start = 0;

        for (int i = 0; i < NUM_FEATURES; i++) begin
            @(negedge clk);
            feat_valid = 1; feat_idx = i; feat_data = 16'sd0;
            w_cls0 = 8'sd5; w_cls1 = 8'sd5; w_cls2 = 8'sd5; w_cls3 = 8'sd5;
        end
        @(negedge clk); feat_valid = 0;
        @(posedge clk);
        #1;
        record_result("CORNER", (score0 === 24'sd10 && score1 === 24'sd20 && score2 === 24'sd30 && score3 === 24'sd40 && cls_done === 1'b1),
                      "TC2: Zero feature stream retains exact biases");

        //---------------------------------------------------------------------
        // CORNER TEST 3: Extreme negative weight dot product
        //---------------------------------------------------------------------
        @(negedge clk);
        start = 1; bias0 = '0; bias1 = '0; bias2 = '0; bias3 = '0;
        @(negedge clk); start = 0;

        for (int i = 0; i < NUM_FEATURES; i++) begin
            @(negedge clk);
            feat_valid = 1; feat_idx = i; feat_data = 16'sd100;
            w_cls0 = -8'sd10; w_cls1 = 8'sd0; w_cls2 = 8'sd0; w_cls3 = 8'sd0;
        end
        @(negedge clk); feat_valid = 0;
        @(posedge clk);
        #1;
        // 121 * (100 * -10) = -121000
        record_result("CORNER", (score0 === -24'sd121000 && cls_done === 1'b1), "TC3: Extreme negative classification dot-product (-121000)");

        //---------------------------------------------------------------------
        // CORNER TEST 4: Single Feature Activation at idx 0
        //---------------------------------------------------------------------
        @(negedge clk); start = 1; bias0 = 24'sd5; @(negedge clk); start = 0;
        @(negedge clk);
        feat_valid = 1; feat_idx = 0; feat_data = 16'sd10; w_cls0 = 8'sd3;
        @(negedge clk); feat_valid = 0;
        @(posedge clk);
        #1;
        record_result("CORNER", (score0 === 24'sd35), "TC4: Single feature accumulation matches (5 + 10*3 = 35)");

        //---------------------------------------------------------------------
        // CORNER TEST 5: Restart clears accumulator mid-stream
        //---------------------------------------------------------------------
        @(negedge clk);
        start = 1; bias0 = 24'sd500;
        @(negedge clk);
        feat_valid = 1; feat_data = 16'sd100; w_cls0 = 8'sd1;
        @(negedge clk);
        start = 1; bias0 = 24'sd0;
        @(negedge clk);
        start = 0; feat_valid = 0;
        @(posedge clk);
        #1;
        record_result("CORNER", (score0 === 24'sd0), "TC5: Restart strobe cleanly clears accumulators");

        //---------------------------------------------------------------------
        // NORMAL TEST 6: Healthy Foliage Profile (Class 0 Dominant)
        //---------------------------------------------------------------------
        @(negedge clk);
        start = 1;
        bias0 = 24'sd1000; bias1 = 24'sd0; bias2 = 24'sd0; bias3 = 24'sd0;
        @(negedge clk); start = 0;

        for (int i = 0; i < NUM_FEATURES; i++) begin
            @(negedge clk);
            feat_valid = 1; feat_idx = i; feat_data = 16'sd50;
            w_cls0 = 8'sd2; w_cls1 = 8'sd0; w_cls2 = -8'sd1; w_cls3 = -8'sd1;
        end
        @(negedge clk); feat_valid = 0;
        @(posedge clk);
        #1;
        record_result("NORMAL", (score0 > score1 && score0 > score2 && score0 > score3 && cls_done === 1'b1),
                      "TC6: Healthy crop profile yields Class 0 dominance");

        //---------------------------------------------------------------------
        // NORMAL TEST 7: Leaf Blight Profile (Class 1 Dominant)
        //---------------------------------------------------------------------
        @(negedge clk);
        start = 1;
        bias0 = 24'sd0; bias1 = 24'sd5000; bias2 = 24'sd0; bias3 = 24'sd0;
        @(negedge clk); start = 0;

        for (int i = 0; i < NUM_FEATURES; i++) begin
            @(negedge clk);
            feat_valid = 1; feat_idx = i; feat_data = 16'sd80;
            w_cls0 = -8'sd1; w_cls1 = 8'sd4; w_cls2 = 8'sd0; w_cls3 = 8'sd0;
        end
        @(negedge clk); feat_valid = 0;
        @(posedge clk);
        #1;
        record_result("NORMAL", (score1 > score0 && score1 > score2 && score1 > score3 && cls_done === 1'b1),
                      "TC7: Leaf Blight profile yields Class 1 dominance");

        //---------------------------------------------------------------------
        // ULTIMATE STRESS TEST 8: 121-Feature Stream vs Matrix Golden
        //---------------------------------------------------------------------
        stress_pass = 1;
        begin
            automatic logic signed [23:0] exp_s0 = 24'sd100;
            automatic logic signed [23:0] exp_s1 = -24'sd50;
            automatic logic signed [23:0] exp_s2 = 24'sd200;
            automatic logic signed [23:0] exp_s3 = 24'sd0;

            @(negedge clk);
            start = 1;
            bias0 = exp_s0; bias1 = exp_s1; bias2 = exp_s2; bias3 = exp_s3;
            @(negedge clk); start = 0;

            for (int i = 0; i < NUM_FEATURES; i++) begin
                automatic logic signed [15:0] rf = $urandom_range(0, 1000);
                automatic logic signed [7:0] rw0 = $urandom_range(0, 10) - 5;
                automatic logic signed [7:0] rw1 = $urandom_range(0, 10) - 5;
                automatic logic signed [7:0] rw2 = $urandom_range(0, 10) - 5;
                automatic logic signed [7:0] rw3 = $urandom_range(0, 10) - 5;

                exp_s0 += (rf * rw0);
                exp_s1 += (rf * rw1);
                exp_s2 += (rf * rw2);
                exp_s3 += (rf * rw3);

                @(negedge clk);
                feat_valid = 1; feat_idx = i; feat_data = rf;
                w_cls0 = rw0; w_cls1 = rw1; w_cls2 = rw2; w_cls3 = rw3;
            end
            @(negedge clk); feat_valid = 0;
            @(posedge clk);
            #1;
            if (score0 !== exp_s0 || score1 !== exp_s1 || score2 !== exp_s2 || score3 !== exp_s3) begin
                stress_pass = 0;
            end
            record_result("STRESS", (stress_pass && cls_done === 1'b1), "TC8: 121-feature dense stream matched 4-class golden dot products");
        end

        #20;
        print_summary("dense_classifier");
        $finish;
    end : test_seq

endmodule: tb_dense_classifier
