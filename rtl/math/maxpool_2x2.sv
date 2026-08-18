//=============================================================================
// File: maxpool_2x2.sv
// Description: Spatial 2x2 Max-Pooling unit selecting the maximum activation
//              among 4 input points: max(max(a, b), max(c, d)).
// Standard: SystemVerilog IEEE 1800
//=============================================================================

`timescale 1ns/1ps

module maxpool_2x2 (
    input  logic signed [15:0] a,
    input  logic signed [15:0] b,
    input  logic signed [15:0] c,
    input  logic signed [15:0] d,
    output logic signed [15:0] max_out
);

    wire signed [15:0] max_ab = (a >= b) ? a : b;
    wire signed [15:0] max_cd = (c >= d) ? c : d;

    assign max_out = (max_ab >= max_cd) ? max_ab : max_cd;

endmodule: maxpool_2x2
