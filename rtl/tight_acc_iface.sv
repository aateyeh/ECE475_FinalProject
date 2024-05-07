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
    output wire busy,                  // Effectively behaves as cmd_rdy
    input wire [5:0] cmd_opcode,      // Command operation code, 64 values
    input wire [63:0] cmd_config_data, // Payload of command if needed

    // Interface to respond to the core after the accelerator has processed data
    output wire resp_val,
    input wire resp_rdy,              // Whether the core is ready to take the data
    output wire [63:0] resp_data,

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
parameter CMD_INIT =  6'd10;  // Command to read initialize matrix values
parameter CMD_FILLA = 6'd11;  // Command to fill Matrix A 
parameter CMD_FILLB = 6'd12;  // Command to fill Matrix B
parameter CMD_MULT =  6'd25;  // Command to start multiplication
parameter CMD_RESULT =  6'd13;  // Command to read results
parameter CMD_READ = 6'd15;

parameter SIZE = 8;  // Matrix size

reg [63:0] matrix_A [0:7][0:7]; // Matrix A
reg [63:0] matrix_B [0:7][0:7]; // Matrix B
reg [63:0] result [0:7][0:7];   // Result matrix
reg [3:0] rowA_index;
reg [3:0] colA_index;
reg [3:0] rowB_index;
reg [3:0] colB_index;
reg [3:0] rowR_index;
reg [3:0] colR_index;
wire multiplier_start;
wire multiplier_done;

reg [63:0] partial_sum [0:7][0:7]; // Partial sum matrix
integer i, j, k;
integer a, b, c;

// FILL ME
assign busy = 1'b0;
assign mem_req_val = 1'b0;
assign mem_req_transid = 6'b0;
assign mem_req_addr = 40'd0;
// FOO implementation, respond untouched every command
assign resp_val = cmd_val && (cmd_opcode == CMD_RESULT);
assign resp_data = result[4][4];

always @(cmd_opcode) begin
    if(cmd_val) begin
        if(cmd_opcode == CMD_INIT) begin
            rowA_index <= 4'd0;
            colA_index <= 4'd0;
            rowB_index <= 4'd0;
            colB_index <= 4'd0;
            rowR_index <= 4'd0;
            colR_index <= 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    result[i][j] <= 64'd0; //
                    matrix_A[i][j] <= 64'd0;
                    matrix_B[i][j] <= 64'd0;
                    partial_sum[i][j] <= 64'd7;
                end
            end
        end else if(cmd_opcode == CMD_FILLA) begin
            /*matrix_A[rowA_index][colA_index] <= cmd_config_data;
            colA_index <= colA_index + 1;
            if (colA_index == 4'd7) begin
                colA_index <= 4'd0;
                rowA_index <= rowA_index + 1;
            end*/
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    matrix_A[i][j] <= 64'd4;
                end
            end
        end else if (cmd_opcode == CMD_FILLB) begin
            /*matrix_B[rowB_index][colB_index] <= cmd_config_data;
            colB_index <= colB_index + 1;
            if (colB_index == 4'd7) begin
                colB_index <= 4'd0;
                rowB_index <= rowB_index + 1;
            end*/
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    matrix_B[i][j] <= 64'd5;
                end
            end
        end else if (cmd_opcode == CMD_MULT) begin
            for (a = 0; a < 8; a = a + 1) begin
                for (b = 0; b < 8; b = b + 1) begin
                    for (c = 0; c < 8; c = c + 1) begin
                        result[a][b] = result[a][b] + (matrix_A[a][c] * matrix_B[c][b]);
                    end
                end
            end
        end else if (cmd_opcode == CMD_RESULT && resp_rdy) begin
            colR_index <= colR_index + 1;
            if (colR_index == 4'd7) begin
                colR_index <= 4'd0;
                rowR_index <= rowR_index + 1;
            end
        end
    end
end

endmodule
