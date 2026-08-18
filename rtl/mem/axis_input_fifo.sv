//=============================================================================
// File: axis_input_fifo.sv
// Description: Synchronous AXI4-Stream Input Elastic FIFO for buffering
//              incoming pixel streams and handling backpressure.
// Standard: SystemVerilog IEEE 1800
//=============================================================================

`timescale 1ns/1ps

module axis_input_fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 32,
    parameter int ADDR_WIDTH = $clog2(DEPTH)
)(
    input  logic                  clk,
    input  logic                  rst_n,

    // AXI4-Stream Slave Interface
    input  logic [DATA_WIDTH-1:0] s_axis_tdata,
    input  logic                  s_axis_tvalid,
    output logic                  s_axis_tready,
    input  logic                  s_axis_tlast,

    // FIFO Read / Consumer Interface
    output logic [DATA_WIDTH-1:0] m_data,
    output logic                  m_last,
    output logic                  m_valid,
    input  logic                  m_ready,

    // Status Flags
    output logic                  fifo_full,
    output logic                  fifo_empty,
    output logic [ADDR_WIDTH:0]   fifo_count
);

    // Internal memory array storing {last, data}
    logic [DATA_WIDTH:0] mem [DEPTH-1:0];
    logic [ADDR_WIDTH-1:0] wr_ptr;
    logic [ADDR_WIDTH-1:0] rd_ptr;
    logic [ADDR_WIDTH:0]   count;

    wire push = s_axis_tvalid & s_axis_tready;
    wire pop  = m_valid & m_ready;

    assign fifo_full  = (count == DEPTH);
    assign fifo_empty = (count == 0);
    assign fifo_count = count;

    assign s_axis_tready = ~fifo_full;
    assign m_valid       = ~fifo_empty;
    assign m_data        = mem[rd_ptr][DATA_WIDTH-1:0];
    assign m_last        = mem[rd_ptr][DATA_WIDTH];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count  <= '0;
        end else begin
            // Memory Write
            if (push) begin
                mem[wr_ptr] <= {s_axis_tlast, s_axis_tdata};
                wr_ptr      <= wr_ptr + 1'b1;
            end

            // Memory Read
            if (pop) begin
                rd_ptr <= rd_ptr + 1'b1;
            end

            // Counter Update
            case ({push, pop})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end

endmodule: axis_input_fifo
