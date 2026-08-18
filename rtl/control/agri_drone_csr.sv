//=============================================================================
// File: agri_drone_csr.sv
// Description: Memory-mapped Control and Status Register (CSR) bank for the
//              25x25 Agricultural Drone Hardware Accelerator.
// Standard: SystemVerilog IEEE 1800
//=============================================================================

`timescale 1ns/1ps

module agri_drone_csr (
    input  logic                     clk,
    input  logic                     rst_n,

    // Host APB/CSR Write & Read Interface
    input  logic                     csr_wr_en,
    input  logic                     csr_rd_en,
    input  logic [5:0]               csr_addr,
    input  logic [31:0]              csr_wdata,
    output logic [31:0]              csr_rdata,

    // Hardware Status Feedback Inputs
    input  logic                     hw_busy,
    input  logic                     hw_done,
    input  logic [1:0]               hw_class,
    input  logic                     hw_disease_detected,
    input  logic [15:0]              hw_confidence,

    // Control Outputs to Accelerator Subsystems
    output logic                     ctrl_start,
    output logic                     ctrl_soft_rst,
    output logic                     ctrl_clk_gate_en,

    // Reconfigurable Convolution Weights & Bias
    output logic signed [23:0]       conv_bias,
    output logic signed [7:0]        conv_w0, conv_w1, conv_w2,
    output logic signed [7:0]        conv_w3, conv_w4, conv_w5,
    output logic signed [7:0]        conv_w6, conv_w7, conv_w8,

    // Reconfigurable Dense Classifier Biases (S24)
    output logic signed [23:0]       dense_bias0,
    output logic signed [23:0]       dense_bias1,
    output logic signed [23:0]       dense_bias2,
    output logic signed [23:0]       dense_bias3
);

    import agri_drone_pkg::*;

    // Internal Registers
    logic [31:0]        reg_ctrl;
    logic signed [23:0] reg_conv_bias;
    logic signed [7:0]  reg_w0, reg_w1, reg_w2;
    logic signed [7:0]  reg_w3, reg_w4, reg_w5;
    logic signed [7:0]  reg_w6, reg_w7, reg_w8;
    logic signed [23:0] reg_dbias0, reg_dbias1, reg_dbias2, reg_dbias3;

    // Direct Control and Parameter Outputs
    assign ctrl_start       = reg_ctrl[0];
    assign ctrl_soft_rst    = reg_ctrl[1];
    assign ctrl_clk_gate_en = reg_ctrl[3];

    assign conv_bias = reg_conv_bias;
    assign conv_w0   = reg_w0; assign conv_w1 = reg_w1; assign conv_w2 = reg_w2;
    assign conv_w3   = reg_w3; assign conv_w4 = reg_w4; assign conv_w5 = reg_w5;
    assign conv_w6   = reg_w6; assign conv_w7 = reg_w7; assign conv_w8 = reg_w8;

    assign dense_bias0 = reg_dbias0;
    assign dense_bias1 = reg_dbias1;
    assign dense_bias2 = reg_dbias2;
    assign dense_bias3 = reg_dbias3;

    // Synchronous Register Write Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_ctrl      <= 32'h00000000;
            reg_conv_bias <= 24'sd0;
            // Default 3x3 Laplacian / High-Pass Edge Detection Kernel
            reg_w0 <= -8'sd1; reg_w1 <= -8'sd1; reg_w2 <= -8'sd1;
            reg_w3 <= -8'sd1; reg_w4 <= 8'sd8;  reg_w5 <= -8'sd1;
            reg_w6 <= -8'sd1; reg_w7 <= -8'sd1; reg_w8 <= -8'sd1;
            reg_dbias0 <= 24'sd100;
            reg_dbias1 <= 24'sd0;
            reg_dbias2 <= 24'sd0;
            reg_dbias3 <= 24'sd0;
        end else begin
            // Auto-clear start pulse and soft_rst strobe after 1 cycle
            if (reg_ctrl[0]) reg_ctrl[0] <= 1'b0;
            if (reg_ctrl[1]) reg_ctrl[1] <= 1'b0;

            if (csr_wr_en) begin
                case (csr_addr)
                    6'h00: reg_ctrl      <= csr_wdata;
                    6'h0C: reg_conv_bias <= csr_wdata[23:0];
                    6'h10: begin
                        reg_w0 <= csr_wdata[7:0];
                        reg_w1 <= csr_wdata[15:8];
                        reg_w2 <= csr_wdata[23:16];
                        reg_w3 <= csr_wdata[31:24];
                    end
                    6'h14: begin
                        reg_w4 <= csr_wdata[7:0];
                        reg_w5 <= csr_wdata[15:8];
                        reg_w6 <= csr_wdata[23:16];
                        reg_w7 <= csr_wdata[31:24];
                    end
                    6'h18: reg_w8 <= csr_wdata[7:0];
                    6'h1C: reg_dbias0 <= csr_wdata[23:0];
                    6'h20: reg_dbias1 <= csr_wdata[23:0];
                    6'h24: reg_dbias2 <= csr_wdata[23:0];
                    6'h28: reg_dbias3 <= csr_wdata[23:0];
                    default: ;
                endcase
            end
        end
    end

    // Synchronous / Combinational Register Read
    always_comb begin
        case (csr_addr)
            6'h00: csr_rdata = reg_ctrl;
            6'h04: csr_rdata = {16'd0, 12'd0, 1'b0, 1'b0, hw_busy, hw_done};
            6'h08: csr_rdata = {8'd0, hw_confidence, 5'd0, hw_disease_detected, hw_class};
            6'h0C: csr_rdata = {{8{reg_conv_bias[23]}}, reg_conv_bias};
            6'h10: csr_rdata = {reg_w3, reg_w2, reg_w1, reg_w0};
            6'h14: csr_rdata = {reg_w7, reg_w6, reg_w5, reg_w4};
            6'h18: csr_rdata = {24'd0, reg_w8};
            6'h1C: csr_rdata = {{8{reg_dbias0[23]}}, reg_dbias0};
            6'h20: csr_rdata = {{8{reg_dbias1[23]}}, reg_dbias1};
            6'h24: csr_rdata = {{8{reg_dbias2[23]}}, reg_dbias2};
            6'h28: csr_rdata = {{8{reg_dbias3[23]}}, reg_dbias3};
            default: csr_rdata = 32'hDEADBEEF;
        endcase
    end

endmodule: agri_drone_csr
