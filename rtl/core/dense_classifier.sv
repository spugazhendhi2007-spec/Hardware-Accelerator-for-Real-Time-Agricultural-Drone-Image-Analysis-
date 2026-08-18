//=============================================================================
// File: dense_classifier.sv
// Description: Fully-Connected Dense Classification Layer computing 4-class
//              scores (Healthy, Blight, Rust, Deficiency) from 121 pooled features.
// Standard: SystemVerilog IEEE 1800
//=============================================================================

`timescale 1ns/1ps

module dense_classifier #(
    parameter int NUM_FEATURES = 121,
    parameter int NUM_CLASSES  = 4
)(
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     start,

    // Streaming Pooled Feature Inputs
    input  logic                     feat_valid,
    input  logic signed [15:0]       feat_data,
    input  logic [6:0]               feat_idx,

    // Dense Weights & Biases (Configurable / Default)
    input  logic signed [7:0]        w_cls0, w_cls1, w_cls2, w_cls3, // Weight for current feature idx
    input  logic signed [23:0]       bias0, bias1, bias2, bias3,

    // 4-Class Output Scores (S24)
    output logic signed [23:0]       score0, score1, score2, score3,
    output logic                     cls_done
);

    logic signed [23:0] acc0, acc1, acc2, acc3;
    logic [6:0]         count_reg;
    logic               done_reg;

    assign score0   = acc0;
    assign score1   = acc1;
    assign score2   = acc2;
    assign score3   = acc3;
    assign cls_done = done_reg;

    // Multiplication: S16 feature * S8 weight = S24 product
    wire signed [23:0] p0 = feat_data * w_cls0;
    wire signed [23:0] p1 = feat_data * w_cls1;
    wire signed [23:0] p2 = feat_data * w_cls2;
    wire signed [23:0] p3 = feat_data * w_cls3;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc0      <= '0;
            acc1      <= '0;
            acc2      <= '0;
            acc3      <= '0;
            count_reg <= '0;
            done_reg  <= 1'b0;
        end else if (start) begin
            acc0      <= bias0;
            acc1      <= bias1;
            acc2      <= bias2;
            acc3      <= bias3;
            count_reg <= '0;
            done_reg  <= 1'b0;
        end else begin
            done_reg <= 1'b0;
            if (feat_valid) begin
                acc0 <= acc0 + p0;
                acc1 <= acc1 + p1;
                acc2 <= acc2 + p2;
                acc3 <= acc3 + p3;
                count_reg <= count_reg + 1'b1;

                if (count_reg == NUM_FEATURES - 1) begin
                    done_reg <= 1'b1;
                end
            end
        end
    end

endmodule: dense_classifier
