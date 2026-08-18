//=============================================================================
// File: int8_mac_unit.sv
// Description: Pipelined Signed INT8 Multiply-Accumulate (MAC) Unit with
//              Dynamic Operand Isolation for low dynamic power consumption.
// Standard: SystemVerilog IEEE 1800
//=============================================================================

`timescale 1ns/1ps

module int8_mac_unit (
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     enable,      // Unit compute enable
    input  logic                     clr_acc,     // Clear accumulator
    input  logic signed [7:0]        pixel_in,    // S8 pixel
    input  logic signed [7:0]        weight_in,   // S8 weight
    input  logic signed [23:0]       bias_in,     // S24 bias (loaded on clr_acc)
    output logic signed [23:0]       acc_out,     // S24 accumulation result
    output logic                     valid_out    // 1-cycle latency valid output
);

    // Operand Isolation Gating (prevents multiplier logic switching when disabled or pixel is zero)
    wire signed [7:0] gated_pixel  = (enable && (pixel_in != 8'sd0)) ? pixel_in  : 8'sd0;
    wire signed [7:0] gated_weight = (enable && (pixel_in != 8'sd0)) ? weight_in : 8'sd0;

    // Multiplier stage
    logic signed [15:0] mult_product;
    assign mult_product = gated_pixel * gated_weight;

    // Accumulator register
    logic signed [23:0] acc_reg;
    logic               valid_reg;

    assign acc_out   = acc_reg;
    assign valid_out = valid_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_reg   <= '0;
            valid_reg <= 1'b0;
        end else if (enable) begin
            valid_reg <= 1'b1;
            if (clr_acc) begin
                acc_reg <= bias_in + {{8{mult_product[15]}}, mult_product};
            end else begin
                acc_reg <= acc_reg + {{8{mult_product[15]}}, mult_product};
            end
        end else begin
            valid_reg <= 1'b0;
        end
    end

endmodule: int8_mac_unit
