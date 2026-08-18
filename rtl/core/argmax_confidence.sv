//=============================================================================
// File: argmax_confidence.sv
// Description: Multi-class ArgMax selector, disease detection flag generator,
//              and Q8.8 fixed-point confidence score estimator.
// Standard: SystemVerilog IEEE 1800
//=============================================================================

`timescale 1ns/1ps

module argmax_confidence (
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     enable,

    // 4-Class Input Scores (S24)
    input  logic signed [23:0]       score0, // Class 0: Healthy
    input  logic signed [23:0]       score1, // Class 1: Leaf Blight
    input  logic signed [23:0]       score2, // Class 2: Leaf Rust
    input  logic signed [23:0]       score3, // Class 3: Nutrient Deficiency

    // Output Class & Confidence
    output logic [1:0]               class_id,
    output logic                     disease_detected,
    output logic signed [23:0]       max_score,
    output logic [15:0]              confidence, // Q8.8 format (0..256 -> 0.0 to 1.0)
    output logic                     valid_out
);

    import agri_drone_pkg::*;

    logic [1:0]         best_id;
    logic signed [23:0] max_s;
    logic signed [23:0] sec_s;

    // Combinational 4-way comparator to find Top 1 and Top 2 scores
    always_comb begin
        // Initialize with Class 0
        best_id = CLASS_HEALTHY;
        max_s   = score0;
        sec_s   = -24'sd8388607;

        // Compare against Class 1
        if (score1 > max_s) begin
            sec_s   = max_s;
            max_s   = score1;
            best_id = CLASS_LEAF_BLIGHT;
        end else begin
            sec_s = score1;
        end

        // Compare against Class 2
        if (score2 > max_s) begin
            sec_s   = max_s;
            max_s   = score2;
            best_id = CLASS_LEAF_RUST;
        end else if (score2 > sec_s) begin
            sec_s = score2;
        end

        // Compare against Class 3
        if (score3 > max_s) begin
            sec_s   = max_s;
            max_s   = score3;
            best_id = CLASS_NUTRIENT_DEFICIENT;
        end else if (score3 > sec_s) begin
            sec_s = score3;
        end
    end

    // Q8.8 Confidence Estimation:
    // delta = max_s - sec_s >= 0
    // If delta == 0: 50% confidence (16'h0080)
    // If delta >= 128: 100% confidence (16'h0100)
    // Linear interpolation: 128 + min(128, delta)
    wire [23:0] delta = (max_s >= sec_s) ? (max_s - sec_s) : 24'd0;
    wire [15:0] q8_conf = (delta >= 24'd128) ? 16'h0100 : (16'd128 + delta[7:0]);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            class_id         <= 2'b00;
            disease_detected <= 1'b0;
            max_score        <= '0;
            confidence       <= '0;
            valid_out        <= 1'b0;
        end else if (enable) begin
            class_id         <= best_id;
            disease_detected <= (best_id != CLASS_HEALTHY);
            max_score        <= max_s;
            confidence       <= q8_conf;
            valid_out        <= 1'b1;
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule: argmax_confidence
