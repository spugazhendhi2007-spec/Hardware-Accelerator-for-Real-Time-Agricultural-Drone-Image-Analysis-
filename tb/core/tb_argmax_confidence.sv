//=============================================================================
// File: tb_argmax_confidence.sv
// Description: Self-checking testbench for argmax_confidence adhering to the
//              standard 8-test verification suite (5 Corner + 2 Normal + 1 Stress).
// Standard: SystemVerilog IEEE 1800
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
    initial begin
        reset_counters();
        rst_n  = 0;
        enable = 0;
        {score0, score1, score2, score3} = '0;
        #20;
        rst_n  = 1;
        #10;

        //---------------------------------------------------------------------
        // CORNER TEST 1: All Scores Exactly Equal (Tie-breaking to Class 0)
        //---------------------------------------------------------------------
        @(posedge clk);
        enable = 1;
        score0 = 24'sd1000; score1 = 24'sd1000; score2 = 24'sd1000; score3 = 24'sd1000;
        @(posedge clk);
        #1;
        record_result("CORNER", (class_id === 2'b00 && disease_detected === 1'b0 && confidence === 16'd128),
                      "TC1: Equal tie scores resolve to Class 0 with 50% confidence (128)");

        //---------------------------------------------------------------------
        // CORNER TEST 2: All Negative Scores with Close Margin
        //---------------------------------------------------------------------
        @(posedge clk);
        enable = 1;
        score0 = -24'sd500; score1 = -24'sd100; score2 = -24'sd800; score3 = -24'sd900;
        @(posedge clk);
        #1;
        record_result("CORNER", (class_id === 2'b01 && disease_detected === 1'b1 && max_score === -24'sd100),
                      "TC2: Negative score ranking correctly identified Class 1 (-100)");

        //---------------------------------------------------------------------
        // CORNER TEST 3: High Margin Confidence Saturation (100% / 16'h0100)
        //---------------------------------------------------------------------
        @(posedge clk);
        enable = 1;
        score0 = 24'sd5000; score1 = 24'sd100; score2 = 24'sd50; score3 = 24'sd0;
        @(posedge clk);
        #1;
        record_result("CORNER", (confidence === 16'h0100), "TC3: Large score margin saturates to 100% confidence (256)");

        //---------------------------------------------------------------------
        // CORNER TEST 4: Reset clears output registers
        //---------------------------------------------------------------------
        @(posedge clk);
        rst_n = 0;
        @(posedge clk);
        #1;
        record_result("CORNER", (class_id === 2'b00 && valid_out === 1'b0), "TC4: Reset clears classification registers");
        rst_n = 1;

        //---------------------------------------------------------------------
        // CORNER TEST 5: Single-Cycle Enable Pulse Handling
        //---------------------------------------------------------------------
        @(posedge clk);
        enable = 1; score0 = 24'sd10; score1 = 24'sd20; score2 = 24'sd30; score3 = 24'sd40;
        @(posedge clk);
        enable = 0;
        @(posedge clk);
        #1;
        record_result("CORNER", (valid_out === 1'b0 && class_id === 2'b11), "TC5: Single pulse valid de-asserted on next cycle");

        //---------------------------------------------------------------------
        // NORMAL TEST 6: Healthy Crop Classification (Class 0, Disease Flag = 0)
        //---------------------------------------------------------------------
        @(posedge clk);
        enable = 1;
        score0 = 24'sd10000; score1 = 24'sd1000; score2 = 24'sd500; score3 = 24'sd200;
        @(posedge clk);
        #1;
        record_result("NORMAL", (class_id === CLASS_HEALTHY && disease_detected === 1'b0),
                      "TC6: Healthy crop detected cleanly (disease_flag = 0)");

        //---------------------------------------------------------------------
        // NORMAL TEST 7: Leaf Rust Classification (Class 2, Disease Flag = 1)
        //---------------------------------------------------------------------
        @(posedge clk);
        enable = 1;
        score0 = 24'sd500; score1 = 24'sd800; score2 = 24'sd12000; score3 = 24'sd300;
        @(posedge clk);
        #1;
        record_result("NORMAL", (class_id === CLASS_LEAF_RUST && disease_detected === 1'b1),
                      "TC7: Leaf Rust disease detected (class_id = 2, disease_flag = 1)");

        //---------------------------------------------------------------------
        // ULTIMATE STRESS TEST 8: 500 Randomized 4-Score Vectors vs Golden ArgMax
        //---------------------------------------------------------------------
        begin
            bit stress_pass = 1;
            for (int s = 0; s < 500; s++) begin
                logic signed [23:0] rs0 = $urandom_range(0, 32'h000FFFFF) - 24'sd500000;
                logic signed [23:0] rs1 = $urandom_range(0, 32'h000FFFFF) - 24'sd500000;
                logic signed [23:0] rs2 = $urandom_range(0, 32'h000FFFFF) - 24'sd500000;
                logic signed [23:0] rs3 = $urandom_range(0, 32'h000FFFFF) - 24'sd500000;

                logic [1:0]         exp_id = 2'b00;
                logic signed [23:0] exp_max = rs0;

                if (rs1 > exp_max) begin exp_max = rs1; exp_id = 2'b01; end
                if (rs2 > exp_max) begin exp_max = rs2; exp_id = 2'b10; end
                if (rs3 > exp_max) begin exp_max = rs3; exp_id = 2'b11; end

                @(posedge clk);
                enable = 1;
                score0 = rs0; score1 = rs1; score2 = rs2; score3 = rs3;
                @(posedge clk);
                #1;
                if (class_id !== exp_id || max_score !== exp_max || disease_detected !== (exp_id != 2'b00)) begin
                    stress_pass = 0;
                end
            end
            enable = 0;
            record_result("STRESS", stress_pass, "TC8: 500 randomized multi-class vectors matched golden ArgMax");
        end

        #20;
        print_summary("argmax_confidence");
        $finish;
    end

endmodule: tb_argmax_confidence
