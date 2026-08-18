//=============================================================================
// File: tb_dense_classifier.sv
// Description: Self-checking testbench for dense_classifier adhering to the
//              standard 8-test verification suite (5 Corner + 2 Normal + 1 Stress).
// Standard: SystemVerilog IEEE 1800
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
    initial begin
        reset_counters();
        rst_n      = 0;
        start      = 0;
        feat_valid = 0;
        feat_data  = '0;
        feat_idx   = '0;
        {w_cls0, w_cls1, w_cls2, w_cls3} = '0;
        {bias0, bias1, bias2, bias3}     = '0;
        #20;
        rst_n      = 1;
        #10;

        //---------------------------------------------------------------------
        // CORNER TEST 1: Reset during classification accumulation
        //---------------------------------------------------------------------
        @(posedge clk);
        start = 1; bias0 = 24'sd100;
        @(posedge clk); start = 0;
        feat_valid = 1; feat_data = 16'sd50; w_cls0 = 8'sd2;
        @(posedge clk);
        rst_n = 0;
        @(posedge clk);
        #1;
        record_result("CORNER", (score0 === 24'sd0 && cls_done === 1'b0), "TC1: Reset clears dense classifier accumulators");
        rst_n = 1; feat_valid = 0;
        #10;

        //---------------------------------------------------------------------
        // CORNER TEST 2: All Zero Features retain initial Biases
        //---------------------------------------------------------------------
        @(posedge clk);
        start = 1;
        bias0 = 24'sd10; bias1 = 24'sd20; bias2 = 24'sd30; bias3 = 24'sd40;
        @(posedge clk); start = 0;

        for (int i = 0; i < NUM_FEATURES; i++) begin
            @(posedge clk);
            feat_valid = 1; feat_idx = i; feat_data = 16'sd0;
            w_cls0 = 8'sd5; w_cls1 = 8'sd5; w_cls2 = 8'sd5; w_cls3 = 8'sd5;
        end
        @(posedge clk); feat_valid = 0;
        #1;
        record_result("CORNER", (score0 === 24'sd10 && score1 === 24'sd20 && score2 === 24'sd30 && score3 === 24'sd40 && cls_done === 1'b1),
                      "TC2: Zero feature stream retains exact biases");

        //---------------------------------------------------------------------
        // CORNER TEST 3: Extreme negative weight dot product
        //---------------------------------------------------------------------
        @(posedge clk);
        start = 1; {bias0, bias1, bias2, bias3} = '0;
        @(posedge clk); start = 0;
        @(posedge clk);
        feat_valid = 1; feat_idx = 0; feat_data = 16'sd1000; w_cls0 = -8'sd100;
        @(posedge clk); feat_valid = 0;
        #1;
        record_result("CORNER", (score0 === -24'sd100000), "TC3: Large negative product (-100000) verified");

        //---------------------------------------------------------------------
        // CORNER TEST 4: Start pulse re-initializes count and accumulator
        //---------------------------------------------------------------------
        @(posedge clk);
        start = 1; bias0 = 24'sd500;
        @(posedge clk); start = 0;
        #1;
        record_result("CORNER", (score0 === 24'sd500 && dut.count_reg === '0), "TC4: Start pulse resets feature count to 0");

        //---------------------------------------------------------------------
        // CORNER TEST 5: Stream with stall pauses
        //---------------------------------------------------------------------
        begin
            @(posedge clk); start = 1; {bias0, bias1, bias2, bias3} = '0;
            @(posedge clk); start = 0;
            for (int i = 0; i < 10; i++) begin
                @(posedge clk);
                feat_valid = 1; feat_data = 16'sd10; w_cls0 = 8'sd2;
                @(posedge clk);
                feat_valid = 0; // Pause 1 cycle
            end
            #1;
            record_result("CORNER", (score0 === 24'sd200), "TC5: Intermittent feature stall preserves exact score");
        end

        //---------------------------------------------------------------------
        // NORMAL TEST 6: Healthy Class Dominant Prediction
        //---------------------------------------------------------------------
        begin
            @(posedge clk);
            start = 1; bias0 = 24'sd1000; bias1 = 24'sd0; bias2 = 24'sd0; bias3 = 24'sd0;
            @(posedge clk); start = 0;

            for (int i = 0; i < NUM_FEATURES; i++) begin
                @(posedge clk);
                feat_valid = 1; feat_idx = i; feat_data = 16'sd10;
                w_cls0 = 8'sd5; w_cls1 = 8'sd1; w_cls2 = 8'sd0; w_cls3 = -8'sd1;
            end
            @(posedge clk); feat_valid = 0;
            #1;
            // score0 = 1000 + 121*50 = 7050
            record_result("NORMAL", (score0 > score1 && score0 > score2 && score0 > score3 && cls_done === 1'b1),
                          "TC6: Healthy class (Score 0) highest score achieved");
        end

        //---------------------------------------------------------------------
        // NORMAL TEST 7: Leaf Blight Class Dominant Prediction
        //---------------------------------------------------------------------
        begin
            @(posedge clk);
            start = 1; bias0 = 24'sd0; bias1 = 24'sd2000; bias2 = 24'sd0; bias3 = 24'sd0;
            @(posedge clk); start = 0;

            for (int i = 0; i < NUM_FEATURES; i++) begin
                @(posedge clk);
                feat_valid = 1; feat_idx = i; feat_data = 16'sd20;
                w_cls0 = 8'sd0; w_cls1 = 8'sd10; w_cls2 = 8'sd1; w_cls3 = 8'sd0;
            end
            @(posedge clk); feat_valid = 0;
            #1;
            record_result("NORMAL", (score1 > score0 && score1 > score2 && score1 > score3 && cls_done === 1'b1),
                          "TC7: Leaf Blight (Score 1) highest score achieved");
        end

        //---------------------------------------------------------------------
        // ULTIMATE STRESS TEST 8: Full 121-Feature Vector vs Golden Model
        //---------------------------------------------------------------------
        begin
            longint gold0, gold1, gold2, gold3;
            bit stress_pass = 1;

            @(posedge clk);
            start = 1;
            bias0 = 24'sd100; bias1 = 24'sd200; bias2 = 24'sd300; bias3 = 24'sd400;
            gold0 = 100; gold1 = 200; gold2 = 300; gold3 = 400;
            @(posedge clk); start = 0;

            for (int i = 0; i < NUM_FEATURES; i++) begin
                logic signed [15:0] rf  = $urandom_range(0, 1000);
                logic signed [7:0]  rw0 = $urandom_range(0, 20) - 10;
                logic signed [7:0]  rw1 = $urandom_range(0, 20) - 10;
                logic signed [7:0]  rw2 = $urandom_range(0, 20) - 10;
                logic signed [7:0]  rw3 = $urandom_range(0, 20) - 10;

                @(posedge clk);
                feat_valid = 1; feat_idx = i; feat_data = rf;
                w_cls0 = rw0; w_cls1 = rw1; w_cls2 = rw2; w_cls3 = rw3;

                gold0 += (rf * rw0);
                gold1 += (rf * rw1);
                gold2 += (rf * rw2);
                gold3 += (rf * rw3);
            end
            @(posedge clk); feat_valid = 0;
            #1;
            if (score0 !== gold0[23:0] || score1 !== gold1[23:0] ||
                score2 !== gold2[23:0] || score3 !== gold3[23:0] || cls_done !== 1'b1) begin
                stress_pass = 0;
            end
            record_result("STRESS", stress_pass, "TC8: Complete 121-feature classification matched golden model");
        end

        #20;
        print_summary("dense_classifier");
        $finish;
    end

endmodule: tb_dense_classifier
