//=============================================================================
// File: line_buffer_window_3x3.sv
// Description: Streaming 2D 3x3 kernel sliding window generator using two
//              25-element line buffers for single-cycle 2D convolution.
// Standard: SystemVerilog IEEE 1800
//=============================================================================

`timescale 1ns/1ps

module line_buffer_window_3x3 #(
    parameter int IMAGE_WIDTH  = 25,
    parameter int IMAGE_HEIGHT = 25,
    parameter int DATA_WIDTH   = 8
)(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  clr,

    // Streaming Pixel Input
    input  logic                  in_valid,
    input  logic [DATA_WIDTH-1:0] in_pixel,

    // 3x3 Neighborhood Window Output
    output logic                  window_valid,
    output logic [DATA_WIDTH-1:0] p0, p1, p2, // Row 0: Top-Left, Top-Mid, Top-Right
    output logic [DATA_WIDTH-1:0] p3, p4, p5, // Row 1: Mid-Left, Mid-Center, Mid-Right
    output logic [DATA_WIDTH-1:0] p6, p7, p8, // Row 2: Bot-Left, Bot-Mid, Bot-Right
    output logic [5:0]            out_col,     // Current window column (0..22)
    output logic [5:0]            out_row      // Current window row (0..22)
);

    // Line Buffers of depth IMAGE_WIDTH (25 pixels each)
    logic [DATA_WIDTH-1:0] line_buf0 [IMAGE_WIDTH-1:0];
    logic [DATA_WIDTH-1:0] line_buf1 [IMAGE_WIDTH-1:0];
    logic [4:0] lb_wr_ptr;

    // 3x3 Window Registers
    logic [DATA_WIDTH-1:0] w00, w01, w02;
    logic [DATA_WIDTH-1:0] w10, w11, w12;
    logic [DATA_WIDTH-1:0] w20, w21, w22;

    // Coordinate Tracking
    logic [5:0] col_cnt;
    logic [5:0] row_cnt;
    logic [9:0] total_pixel_cnt;

    // Line buffer tap reads
    logic [DATA_WIDTH-1:0] tap0_data;
    logic [DATA_WIDTH-1:0] tap1_data;

    assign p0 = w00; assign p1 = w01; assign p2 = w02;
    assign p3 = w10; assign p4 = w11; assign p5 = w12;
    assign p6 = w20; assign p7 = w21; assign p8 = w22;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lb_wr_ptr       <= '0;
            w00 <= '0; w01 <= '0; w02 <= '0;
            w10 <= '0; w11 <= '0; w12 <= '0;
            w20 <= '0; w21 <= '0; w22 <= '0;
            col_cnt         <= '0;
            row_cnt         <= '0;
            total_pixel_cnt <= '0;
            window_valid    <= 1'b0;
            out_col         <= '0;
            out_row         <= '0;
        end else if (clr) begin
            lb_wr_ptr       <= '0;
            w00 <= '0; w01 <= '0; w02 <= '0;
            w10 <= '0; w11 <= '0; w12 <= '0;
            w20 <= '0; w21 <= '0; w22 <= '0;
            col_cnt         <= '0;
            row_cnt         <= '0;
            total_pixel_cnt <= '0;
            window_valid    <= 1'b0;
            out_col         <= '0;
            out_row         <= '0;
        end else if (in_valid) begin
            // Read from line buffer at current pointer
            tap0_data = line_buf0[lb_wr_ptr];
            tap1_data = line_buf1[lb_wr_ptr];

            // Shift current incoming pixel into Line Buffer 0, Line Buffer 0 into Line Buffer 1
            line_buf0[lb_wr_ptr] <= in_pixel;
            line_buf1[lb_wr_ptr] <= tap0_data;

            // Advance line buffer pointer circularly
            if (lb_wr_ptr == IMAGE_WIDTH - 1) begin
                lb_wr_ptr <= '0;
            end else begin
                lb_wr_ptr <= lb_wr_ptr + 1'b1;
            end

            // Shift 3x3 Window Registers (Row 0 from tap1, Row 1 from tap0, Row 2 from in_pixel)
            w00 <= w01; w01 <= w02; w02 <= tap1_data;
            w10 <= w11; w11 <= w12; w12 <= tap0_data;
            w20 <= w21; w21 <= w22; w22 <= in_pixel;

            // Pixel & Coordinate Counters
            total_pixel_cnt <= total_pixel_cnt + 1'b1;

            if (col_cnt == IMAGE_WIDTH - 1) begin
                col_cnt <= '0;
                row_cnt <= row_cnt + 1'b1;
            end else begin
                col_cnt <= col_cnt + 1'b1;
            end

            // Window valid when at least 2 rows and 2 columns have been shifted
            if ((row_cnt >= 6'd2) && (col_cnt >= 6'd2)) begin
                window_valid <= 1'b1;
                out_col      <= col_cnt - 6'd2;
                out_row      <= row_cnt - 6'd2;
            end else begin
                window_valid <= 1'b0;
            end
        end else begin
            window_valid <= 1'b0;
        end
    end

endmodule: line_buffer_window_3x3
