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

module tight_acc_iface(
    input wire clk,
    input wire rst_n,
    // Command interface to receive "instructions" and configurations
    input wire cmd_val,               // New valid command
    output reg busy,                  // Effectively behaves as cmd_rdy
    input wire [5:0] cmd_opcode,      // Command operation code, 64 values
    input wire [63:0] cmd_config_data, // Payload of command if needed

    // Interface to respond to the core after the accelerator has processed data
    output reg resp_val,
    input wire resp_rdy,              // Whether the core is ready to take the data
    output reg [63:0] resp_data,

    // Request interface to memory hierarchy
    input wire mem_req_rdy,           // Whether the network is ready to take the request
    output wire mem_req_val,
    output wire [5:0] mem_req_transid, // Can have up to 64 inflight requests
    output wire [`DCP_PADDR_MASK] mem_req_addr, // Physical memory address

    // Response interface from memory hierarchy (L2 shared cache)
    input wire mem_resp_val,
    input wire [5:0] mem_resp_transid, // Up to 64 outstanding requests
    input wire [`DCP_NOC_RES_DATA_SIZE-1:0] mem_resp_data // Up to 64 Bytes
);

// Command opcodes
parameter CMD_MULT =  6'b000001;  // Command to load matrices and start multiplication
parameter CMD_FILLA = 6'b000010;  // Command to read results
parameter CMD_FILLB = 6'b000011;  // Command to read results
parameter CMD_READ =  6'b000100;  // Command to read results

parameter SIZE = 10;  // Matrix size

reg [63:0] matrix_A [0:9][0:9]; // Matrix A
reg [63:0] matrix_B [0:9][0:9]; // Matrix B
reg [63:0] result [0:9][0:9];   // Result matrix
wire multiplier_start;
wire multiplier_done;

// MatrixMultiplier instantiation
matrixmultiplier multiplier_inst (
    .clk(clk),
    .start(multiplier_start),
    .matrix_A(matrix_A),
    .matrix_B(matrix_B),
    .result(result),
    .done(multiplier_done)
);

integer row_index, col_index;

assign multiplier_start = (cmd_val) && (cmd_opcode == CMD_MULT);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        busy <= 1'b0;
        resp_val <= 1'b0;
        resp_data <= 64'b0;
        row_index <= 10'b0;
        col_index <= 10'b0;
    end 
    else if(cmd_val) begin
        busy <= 1'b1;
        case (cmd_opcode)
            CMD_FILLA:
                if (row_index < SIZE) begin
                    matrix_A[row_index][col_index] <= cmd_config_data;
                    col_index <= col_index + 1;
                    if (col_index == SIZE) begin
                        col_index <= 10'b0;
                        row_index <= row_index + 1;
                    end
                end
            CMD_FILLB: 
                if (row_index < SIZE) begin
                    matrix_B[row_index][col_index] <= cmd_config_data;
                    col_index <= col_index + 1;
                    if (col_index == SIZE) begin
                        col_index <= 10'b0;
                        row_index <= row_index + 1;
                    end
                end
            CMD_MULT:
                col_index <= col_index;
            CMD_READ:
                if (multiplier_done) begin
                    if (resp_rdy) begin
                        resp_val <= 1'b1;
                        resp_data <= result[row_index][col_index];
                        col_index <= col_index + 1;
                        if (col_index == SIZE) begin
                            col_index <= 10'b0;
                            row_index <= row_index + 1;
                        end
                        if (row_index == SIZE) begin
                            resp_val <= 1'b0;
                            busy <= 1'b0;
                        end
                    end
                end
        endcase
    end
end

endmodule

module matrixmultiplier(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] matrix_A [0:9][0:9], 
    input wire [63:0] matrix_B [0:9][0:9], 
    output reg [63:0] result [0:9][0:9],  
    output reg done                          // Signal indicating computation completion
);

reg [63:0] partial_sum [0:9][0:9]; // Partial sum matrix
integer i, j, k;

// Reset done signal and result matrix
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        done <= 0;
        for (i = 0; i < 10; i = i + 1) begin
            for (j = 0; j < 10; j = j + 1) begin
                result[i][j] <= 64'b0;
                partial_sum[i][j] <= 64'b0;
            end
        end
    end else if (start) begin
        done <= 0;
        for (i = 0; i < 10; i = i + 1) begin
            for (j = 0; j < 10; j = j + 1) begin
                partial_sum[i][j] <= 64'b0; // Initialize partial sums
            end
        end
    end else if (!done) begin
        for (i = 0; i < 10; i = i + 1) begin
            for (j = 0; j < 10; j = j + 1) begin
                for (k = 0; k < 10; k = k + 1) begin
                    partial_sum[i][j] <= partial_sum[i][j] + matrix_A[i][k] * matrix_B[k][j];
                end
                result[i][j] <= partial_sum[i][j]; // Assign the computed result
            end
        end
        done <= 1'b1; // Set done after the computation is complete
    end
end

endmodule

