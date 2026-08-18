//=============================================================================
// File: tb_argmax_confidence.sv
// Description: Self-checking testbench for argmax_confidence adhering to the
//              standard 8-test verification suite (5 Corner + 2 Normal + 1 Stress).
// Standard: SystemVerilog IEEE 1800 (Clean 0-warning compilation)
//=============================================================================

`timescale 1ns/1ps

module tb_argmax_confidence;

    import tb_pkg::*;
    import agri_drone_pkg::*;

    logic                     clk;
    logic                     rst_n;
    logic                     enable;
    logic signed [23:0]       score0, score1, score2, score3;
    logic [1:0]               class_id;
    logic                     disease_detected;
    logic signed [23:0]       max_score;
    logic [15:0]              confidence;
    logic                     valid_out;

    // Clock generator (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // DUT
    argmax_confidence dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .score0(score0), .score1(score1), .score2(score2), .score3(score3),
        .class_id(class_id),
        .disease_detected(disease_detected),
        .max_score(max_score),
        .confidence(confidence),
        .valid_out(valid_out)
    );

    // Test sequence
    initial begin : test_seq
        automatic bit stress_pass = 1;

        reset_counters();
        rst_n  = 0;
        enable = 0;
        score0 = '0; score1 = '0; score2 = '0; score3 = '0;
        #20;
        rst_n  = 1;
        #10;

        //---------------------------------------------------------------------
        // CORNER TEST 1: All Scores Exactly Equal (Tie-breaking to Class 0)
        //---------------------------------------------------------------------
        @(negedge clk);
        enable = 1;
        score0 = 24'sd1000; score1 = 24'sd1000; score2 = 24'sd1000; score3 = 24'sd1000;
        @(posedge clk);
        #1;
        record_result("CORNER", (class_id === 2'b00 && disease_detected === 1'b0 && confidence === 16'd128),
                      "TC1: Equal tie scores resolve to Class 0 with 50% confidence (128)");

        //---------------------------------------------------------------------
        // CORNER TEST 2: All Negative Scores with Close Margin
        //---------------------------------------------------------------------
        @(negedge clk);
        enable = 1;
        score0 = -24'sd500; score1 = -24'sd100; score2 = -24'sd800; score3 = -24'sd900;
        @(posedge clk);
        #1;
        record_result("CORNER", (class_id === 2'b01 && disease_detected === 1'b1 && max_score === -24'sd100),
                      "TC2: Negative score ranking correctly identified Class 1 (-100)");

        //---------------------------------------------------------------------
        // CORNER TEST 3: High Margin Confidence Saturation (100% / 16'h0100)
        //---------------------------------------------------------------------
        @(negedge clk);
        enable = 1;
        score0 = 24'sd5000; score1 = 24'sd100; score2 = 24'sd50; score3 = 24'sd0;
        @(posedge clk);
        #1;
        record_result("CORNER", (confidence === 16'h0100), "TC3: Large score margin saturates to 100% confidence (256)");

        //---------------------------------------------------------------------
        // CORNER TEST 4: Reset clears output registers
        //---------------------------------------------------------------------
        @(negedge clk);
        rst_n = 0;
        @(posedge clk);
        #1;
        record_result("CORNER", (class_id === 2'b00 && valid_out === 1'b0), "TC4: Reset clears classification registers");
        @(negedge clk);
        rst_n = 1;

        //---------------------------------------------------------------------
        // CORNER TEST 5: Single-Cycle Enable Pulse Handling
        //---------------------------------------------------------------------
        @(negedge clk);
        enable = 1; score0 = 24'sd10; score1 = 24'sd20; score2 = 24'sd30; score3 = 24'sd40;
        @(negedge clk);
        enable = 0;
        @(posedge clk);
        #1;
        record_result("CORNER", (class_id === 2'b11 && max_score === 24'sd40), "TC5: Single-cycle enable captures Class 3");

        //---------------------------------------------------------------------
        // NORMAL TEST 6: Healthy Foliage Classification (Class 0)
        //---------------------------------------------------------------------
        @(negedge clk);
        enable = 1;
        score0 = 24'sd300; score1 = 24'sd50; score2 = 24'sd10; score3 = 24'sd0;
        @(posedge clk);
        #1;
        record_result("NORMAL", (class_id === CLASS_HEALTHY && disease_detected === 1'b0 && confidence > 16'd128),
                      "TC6: Healthy Crop classified with disease_detected = 0");

        //---------------------------------------------------------------------
        // NORMAL TEST 7: Leaf Blight Disease Classification (Class 1)
        //---------------------------------------------------------------------
        @(negedge clk);
        enable = 1;
        score0 = 24'sd20; score1 = 24'sd600; score2 = 24'sd50; score3 = 24'sd10;
        @(posedge clk);
        #1;
        record_result("NORMAL", (class_id === CLASS_LEAF_BLIGHT && disease_detected === 1'b1 && confidence > 16'd128),
                      "TC7: Leaf Blight classified with disease_detected = 1");

        //---------------------------------------------------------------------
        // ULTIMATE STRESS TEST 8: 100 Randomized Score Vectors
        //---------------------------------------------------------------------
        stress_pass = 1;
        for (int s = 0; s < 100; s++) begin
            automatic logic signed [23:0] rs0 = $urandom_range(0, 10000) - 5000;
            automatic logic signed [23:0] rs1 = $urandom_range(0, 10000) - 5000;
            automatic logic signed [23:0] rs2 = $urandom_range(0, 10000) - 5000;
            automatic logic signed [23:0] rs3 = $urandom_range(0, 10000) - 5000;

            automatic logic signed [23:0] exp_max = rs0;
            automatic logic [1:0] exp_cls = 2'b00;

            if (rs1 > exp_max) begin exp_max = rs1; exp_cls = 2'b01; end
            if (rs2 > exp_max) begin exp_max = rs2; exp_cls = 2'b10; end
            if (rs3 > exp_max) begin exp_max = rs3; exp_cls = 2'b11; end

            @(negedge clk);
            enable = 1;
            score0 = rs0; score1 = rs1; score2 = rs2; score3 = rs3;
            @(posedge clk);
            #1;
            if (class_id !== exp_cls || max_score !== exp_max || valid_out !== 1'b1) begin
                stress_pass = 0;
            end
        end
        @(negedge clk);
        enable = 0;
        record_result("STRESS", stress_pass, "TC8: 100 randomized multi-class score vectors matched golden ArgMax");

        #20;
        print_summary("argmax_confidence");
        $finish;
    end : test_seq

endmodule: tb_argmax_confidence
