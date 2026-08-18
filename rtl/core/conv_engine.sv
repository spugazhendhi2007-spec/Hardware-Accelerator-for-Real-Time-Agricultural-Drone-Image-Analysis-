//=============================================================================
// File: conv_engine.sv
// Description: 2D Convolution Processing Engine integrating 3x3 PE Array,
//              ReLU activation, and 2x2 Max-Pooling for 25x25 image patches.
// Standard: SystemVerilog IEEE 1800
//=============================================================================

`timescale 1ns/1ps

module conv_engine #(
    parameter int IMAGE_WIDTH  = 25,
    parameter int IMAGE_HEIGHT = 25,
    parameter int KERNEL_SIZE  = 3
)(
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     start,

    // Streaming pixel inputs from 3x3 window generator
    input  logic                     window_valid,
    input  logic [7:0]               p0, p1, p2,
    input  logic [7:0]               p3, p4, p5,
    input  logic [7:0]               p6, p7, p8,
    input  logic [5:0]               win_col,
    input  logic [5:0]               win_row,

    // 3x3 Filter Weights & Bias
    input  logic signed [7:0]        w0, w1, w2,
    input  logic signed [7:0]        w3, w4, w5,
    input  logic signed [7:0]        w6, w7, w8,
    input  logic signed [23:0]       bias,

    // Pooled Feature Output
    output logic                     feat_valid,
    output logic signed [15:0]       feat_data,
    output logic [6:0]               feat_idx,     // 0..120 (121 total features)
    output logic                     conv_done
);

    import agri_drone_pkg::*;

    // Center 8-bit unsigned pixels to signed 8-bit [-128, +127]
    wire signed [7:0] sp0 = center_pixel(p0);
    wire signed [7:0] sp1 = center_pixel(p1);
    wire signed [7:0] sp2 = center_pixel(p2);
    wire signed [7:0] sp3 = center_pixel(p3);
    wire signed [7:0] sp4 = center_pixel(p4);
    wire signed [7:0] sp5 = center_pixel(p5);
    wire signed [7:0] sp6 = center_pixel(p6);
    wire signed [7:0] sp7 = center_pixel(p7);
    wire signed [7:0] sp8 = center_pixel(p8);

    // PE Array Instantiation
    logic signed [23:0] pe_conv_out;
    logic               pe_valid_out;

    pe_array_3x3 u_pe_array (
        .clk(clk),
        .rst_n(rst_n),
        .enable(window_valid),
        .p0(sp0), .p1(sp1), .p2(sp2),
        .p3(sp3), .p4(sp4), .p5(sp5),
        .p6(sp6), .p7(sp7), .p8(sp8),
        .w0(w0),  .w1(w1),  .w2(w2),
        .w3(w3),  .w4(w4),  .w5(w5),
        .w6(w6),  .w7(w7),  .w8(w8),
        .bias(bias),
        .conv_out(pe_conv_out),
        .valid_out(pe_valid_out)
    );

    // ReLU Activation
    wire signed [15:0] relu_act = relu_clamp(pe_conv_out);

    // Coordinate pipeline registers (align with PE output latency)
    logic [5:0] r_col, r_row;
    logic [9:0] conv_cnt;

    // 2x2 Spatial Max-Pooling Buffering
    // Conv output is 23x23. 2x2 maxpool takes (2r, 2c), (2r, 2c+1), (2r+1, 2c), (2r+1, 2c+1) for r,c in 0..10.
    logic signed [15:0] pool_line_buf [22:0]; // 23 elements line buffer
    logic signed [15:0] pool_h_max;           // Horizontal max register
    logic [6:0]         f_idx_reg;
    logic               f_valid_reg;
    logic signed [15:0] f_data_reg;
    logic               done_reg;

    assign feat_valid = f_valid_reg;
    assign feat_data  = f_data_reg;
    assign feat_idx   = f_idx_reg;
    assign conv_done  = done_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_col       <= '0;
            r_row       <= '0;
            conv_cnt    <= '0;
            f_idx_reg   <= '0;
            f_valid_reg <= 1'b0;
            f_data_reg  <= '0;
            done_reg    <= 1'b0;
            pool_h_max  <= '0;
        end else if (start) begin
            r_col       <= '0;
            r_row       <= '0;
            conv_cnt    <= '0;
            f_idx_reg   <= '0;
            f_valid_reg <= 1'b0;
            f_data_reg  <= '0;
            done_reg    <= 1'b0;
            pool_h_max  <= '0;
        end else begin
            f_valid_reg <= 1'b0;

            // Pipeline coordinate tracking
            r_col <= win_col;
            r_row <= win_row;

            if (pe_valid_out) begin
                conv_cnt <= conv_cnt + 1'b1;

                // 2x2 Max-Pooling Logic on 23x23 feature stream:
                // Only sample even/odd pairs within 22x22 grid (0..21)
                if (r_row < 6'd22 && r_col < 6'd22) begin
                    if (r_row[0] == 1'b0) begin
                        // Even row (Row 0, 2, 4...): buffer intermediate results
                        if (r_col[0] == 1'b0) begin
                            pool_h_max <= relu_act;
                        end else begin
                            // Store max of (col 2c, col 2c+1) into line buffer for next row
                            pool_line_buf[r_col >> 1] <= (relu_act >= pool_h_max) ? relu_act : pool_h_max;
                        end
                    end else begin
                        // Odd row (Row 1, 3, 5...): combine with even row max
                        if (r_col[0] == 1'b0) begin
                            pool_h_max <= relu_act;
                        end else begin
                            // Complete 2x2 window: max of row 0 pair and row 1 pair
                            logic signed [15:0] top_max;
                            logic signed [15:0] bot_max;
                            logic signed [15:0] final_pool;

                            top_max = pool_line_buf[r_col >> 1];
                            bot_max = (relu_act >= pool_h_max) ? relu_act : pool_h_max;
                            final_pool = (bot_max >= top_max) ? bot_max : top_max;

                            f_valid_reg <= 1'b1;
                            f_data_reg  <= final_pool;
                            f_idx_reg   <= f_idx_reg + 1'b1;
                        end
                    end
                end

                if (conv_cnt == TOTAL_CONV_PIXELS - 1) begin
                    done_reg <= 1'b1;
                end
            end
        end
    end

endmodule: conv_engine
