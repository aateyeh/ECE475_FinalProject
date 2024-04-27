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

// Opcode of interest
parameter CMD_OPCODE = 6'b000000;

// States of FSM
typedef enum logic [1:0] {
    IDLE,
    COMPUTING,
    RESPONDING
} State;

// Internal signals
reg [1:0] state;
reg [63:0] input;
reg [63:0] output;
reg valid;

always @(posedge clk or negedge rst_n) begin
    // reset
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
                    state <= COMPUTING;
                    input <= cmd_config_data;
                    busy <= 1'b1;
                end
            COMPUTING:
                begin
                    // REPLACE WITH ACTUAL ACCELERATOR
                    output <= $sqrt(input);
                    valid <= 1'b1;
                    state <= RESPONDING;
                end
            RESPONDING:
                if (resp_rdy) begin
                    resp_val <= 1'b1;
                    resp_data <= output;
                    valid <= 1'b0;
                    state <= IDLE;
                    busy <= 1'b0;
                end
        endcase
    end
end

assign resp_val = valid;
assign resp_data = output;

endmodule