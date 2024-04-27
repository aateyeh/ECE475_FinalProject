/*
Copyright (c) 2020 Princeton University
All rights reserved.
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Princeton University nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.
THIS SOFTWARE IS PROVIDED BY PRINCETON UNIVERSITY "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL PRINCETON UNIVERSITY BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

`include "dcp.h"

`ifdef DEFAULT_NETTYPE_NONE
`default_nettype none
`endif

module tight_acc_iface (
    input  wire clk,
    input  wire rst_n,
    // Command iface to receive "instructions" and configurations
    input  wire                             cmd_val,        // New valid command
    output wire                             busy,           // effectively behaves as cmd_rdy
    input  wire [5:0]                       cmd_opcode,     // Command operation code, 64 values
    input  wire [63:0]                      cmd_config_data, // Payload of command if needed

    // Interface to respond to the core after the accelerator has processed data
    output wire                             resp_val,
    input  wire                             resp_rdy, //whether the core is ready to take the data
    output wire [63:0]                      resp_data,

    // Request iface to memory hierarchy
    input  wire                             mem_req_rdy, //whether the network is ready to take the request
    output wire                             mem_req_val,
    output wire [5:0]                       mem_req_transid, //can have up to 64 inflight requests
    output wire [`DCP_PADDR_MASK       ]    mem_req_addr, // physical memory addr

    // Response iface from memory hierarchy (L2 shared cache)
    input  wire                              mem_resp_val,
    input  wire [5:0]                        mem_resp_transid, // up to 64 outstanding requests 
    input  wire [`DCP_NOC_RES_DATA_SIZE-1:0] mem_resp_data //up to 64Bytes
);

parameter CMD_OPCODE = 6'b000000;
parameter SIZE = 64;

reg [1:0] state;
reg [63:0] output;
reg [63:0] input_A; // Input element of matrix A
reg [63:0] input_B; // Input element of matrix B
reg [63:0] matrix_A [0:63][0:63]; // Matrix A
reg [63:0] matrix_B [0:63][0:63]; // Matrix B
reg [63:0] result [0:63][0:63];   // Result matrix
reg valid;
wire multiplier_start;
wire multiplier_done;

// Matrix multiplication module instance
MatrixMultiplier multiplier_inst (
    .clk(clk),
    .start(multiplier_start),
    .matrix_A(matrix_A),
    .matrix_B(matrix_B),
    .result(result),
    .done(multiplier_done)
);

integer row_index; // Index for the current row of the matrix being filled
integer col_index; // Index for the current column of the matrix being filled
integer resp_row;  // Index for the current row of the response
integer resp_col;  // Index for the current column of the response

always @(posedge clk or negedge rst_n) begin
    if (rst_n) begin
        state <= IDLE;
        busy <= 1'b0;
        valid <= 1'b0;
        resp_val <= 1'b0;
        resp_data <= 64'd0;
    end else begin
        case (state)
            IDLE:
                if (cmd_val && (cmd_opcode == CMD_OPCODE)) begin
                    input_A <= cmd_config_data;
                    // Start filling matrix A
                    row_index <= 0;
                    col_index <= 0;
                    state <= FILLING_A;
                    busy <= 1'b1;
                end
            FILLING_A:
                begin
                    // Fill matrix_A with input data for matrix A
                    matrix_A[row_index][col_index] <= input_A;
                    col_index <= col_index + 1;
                    if (col_index == SIZE) begin
                        col_index <= 0;
                        row_index <= row_index + 1;
                        if (row_index == SIZE) begin
                            // Reset indices for matrix B
                            row_index <= 0;
                            col_index <= 0;
                            // Move to fill matrix B
                            input_B <= cmd_config_data;
                            state <= FILLING_B;
                        end
                    end
                    input_A <= cmd_config_data;
                end
            FILLING_B:
                begin
                    matrix_B[row_index][col_index] <= input_B;
                    col_index <= col_index + 1;
                    if (col_index == SIZE) begin
                        col_index <= 0;
                        row_index <= row_index + 1;
                        if (row_index == SIZE) begin
                          // Start matrix multiplication computation
                          multiplier_start <= 1;
                          state <= RESPONDING;
                          resp_row <= 0; // Initialize response row index
                          resp_col <= 0; // Initialize response column index
                        end
                    end
                    input_B <= cmd_config_data;
                end
            RESPONDING:
                begin
                    if (multiplier_done && resp_rdy) begin
                        // Send the entire result matrix
                        resp_val <= 1'b1;
                        resp_data <= result[resp_row][resp_col];
                        valid <= 1'b1;
                        resp_col <= resp_col + 1;
                        if (resp_col == SIZE) begin
                            resp_col <= 0;
                            resp_row <= resp_row + 1;
                        end
                        // If all elements are sent, transition back to IDLE
                        if ((resp_row == SIZE) && (resp_col == 0)) begin
                            state <= IDLE;
                            busy <= 1'b0;
                        end
                    end
                end
        endcase
    end
end

endmodule