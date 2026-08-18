//=============================================================================
// File: pe_array_3x3.sv
// Description: 9-Element Parallel 2D Convolution Processing Element Array
//              with adder-tree reduction and bias addition.
// Standard: SystemVerilog IEEE 1800
//=============================================================================

`timescale 1ns/1ps

module pe_array_3x3 (
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     enable,

    // 3x3 Pixel Window Inputs (S8)
    input  logic signed [7:0]        p0, p1, p2,
    input  logic signed [7:0]        p3, p4, p5,
    input  logic signed [7:0]        p6, p7, p8,

    // 3x3 Filter Kernel Weights (S8)
    input  logic signed [7:0]        w0, w1, w2,
    input  logic signed [7:0]        w3, w4, w5,
    input  logic signed [7:0]        w6, w7, w8,

    // Bias Input (S24)
    input  logic signed [23:0]       bias,

    // Convolution Output (S24)
    output logic signed [23:0]       conv_out,
    output logic                     valid_out
);

    // Operand Isolation on 9 Multipliers
    wire signed [7:0] gp0 = enable ? p0 : 8'sd0;
    wire signed [7:0] gp1 = enable ? p1 : 8'sd0;
    wire signed [7:0] gp2 = enable ? p2 : 8'sd0;
    wire signed [7:0] gp3 = enable ? p3 : 8'sd0;
    wire signed [7:0] gp4 = enable ? p4 : 8'sd0;
    wire signed [7:0] gp5 = enable ? p5 : 8'sd0;
    wire signed [7:0] gp6 = enable ? p6 : 8'sd0;
    wire signed [7:0] gp7 = enable ? p7 : 8'sd0;
    wire signed [7:0] gp8 = enable ? p8 : 8'sd0;

    // Stage 1: Parallel 9 Multipliers (S16)
    wire signed [15:0] prod0 = gp0 * w0;
    wire signed [15:0] prod1 = gp1 * w1;
    wire signed [15:0] prod2 = gp2 * w2;
    wire signed [15:0] prod3 = gp3 * w3;
    wire signed [15:0] prod4 = gp4 * w4;
    wire signed [15:0] prod5 = gp5 * w5;
    wire signed [15:0] prod6 = gp6 * w6;
    wire signed [15:0] prod7 = gp7 * w7;
    wire signed [15:0] prod8 = gp8 * w8;

    // Stage 2: Adder Tree (Combinational Tree Reduction)
    wire signed [17:0] sum_row0 = {{2{prod0[15]}}, prod0} + {{2{prod1[15]}}, prod1} + {{2{prod2[15]}}, prod2};
    wire signed [17:0] sum_row1 = {{2{prod3[15]}}, prod3} + {{2{prod4[15]}}, prod4} + {{2{prod5[15]}}, prod5};
    wire signed [17:0] sum_row2 = {{2{prod6[15]}}, prod6} + {{2{prod7[15]}}, prod7} + {{2{prod8[15]}}, prod8};

    wire signed [19:0] total_dot_product = {{2{sum_row0[17]}}, sum_row0} +
                                          {{2{sum_row1[17]}}, sum_row1} +
                                          {{2{sum_row2[17]}}, sum_row2};

    // Output Pipeline Register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            conv_out  <= '0;
            valid_out <= 1'b0;
        end else if (enable) begin
            conv_out  <= bias + {{4{total_dot_product[19]}}, total_dot_product};
            valid_out <= 1'b1;
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule: pe_array_3x3
