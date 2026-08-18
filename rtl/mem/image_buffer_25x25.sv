//=============================================================================
// File: image_buffer_25x25.sv
// Description: Dual-port 625-byte SRAM / Register Buffer for holding a complete
//              25x25 pixel agricultural drone patch.
// Standard: SystemVerilog IEEE 1800
//=============================================================================

`timescale 1ns/1ps

module image_buffer_25x25 #(
    parameter int IMAGE_WIDTH  = 25,
    parameter int IMAGE_HEIGHT = 25,
    parameter int TOTAL_PIXELS = IMAGE_WIDTH * IMAGE_HEIGHT, // 625
    parameter int ADDR_WIDTH   = $clog2(TOTAL_PIXELS),       // 10 bits
    parameter int DATA_WIDTH   = 8
)(
    input  logic                  clk,
    input  logic                  rst_n,

    // Write Port (Streaming Ingestion)
    input  logic                  wr_en,
    input  logic [ADDR_WIDTH-1:0] wr_addr,
    input  logic [DATA_WIDTH-1:0] wr_data,

    // Read Port (Convolution Engine Retrieval)
    input  logic                  rd_en,
    input  logic [ADDR_WIDTH-1:0] rd_addr,
    output logic [DATA_WIDTH-1:0] rd_data
);

    // 625 x 8-bit memory storage
    logic [DATA_WIDTH-1:0] mem [TOTAL_PIXELS-1:0];

    // Synchronous Write & Read
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_data <= '0;
        end else begin
            if (wr_en && (wr_addr < TOTAL_PIXELS)) begin
                mem[wr_addr] <= wr_data;
            end
            if (rd_en && (rd_addr < TOTAL_PIXELS)) begin
                rd_data <= mem[rd_addr];
            end
        end
    end

endmodule: image_buffer_25x25
