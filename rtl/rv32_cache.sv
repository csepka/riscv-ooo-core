// Blocking direct-mapped, one-word lines. Write-through, no write allocation.
// No coherence or instruction synchronization: instruction memory is immutable.
module rv32_cache #(parameter integer LINES=16)(
    input wire clk,reset,
    input wire c_req_valid, output wire c_req_ready,
    input wire [31:0] c_req_addr, input wire c_req_write,
    input wire [31:0] c_req_wdata, input wire [3:0] c_req_wmask,
    output reg c_rsp_valid,c_rsp_error,output reg [31:0] c_rsp_data,
    output wire m_req_valid,input wire m_req_ready,
    output wire [31:0] m_req_addr,output wire m_req_write,
    output wire [31:0] m_req_wdata,output wire [3:0] m_req_wmask,
    input wire m_rsp_valid,m_rsp_error,input wire [31:0] m_rsp_data,
    output reg [31:0] read_hits,read_misses,write_requests
);
    localparam integer IW=$clog2(LINES);
    localparam integer TW=30-IW;
    localparam [1:0] IDLE=0,LOOKUP=1,SEND=2,WAIT_RSP=3;
    reg [1:0] state;
    reg line_valid[0:LINES-1];
    reg [TW-1:0] line_tag[0:LINES-1];
    reg [31:0] line_data[0:LINES-1];
    reg [31:0] address,write_data; reg write_enable; reg [3:0] byte_mask;
    wire [IW-1:0] index=address[IW+1:2];
    wire [TW-1:0] tag=address[31:IW+2];
    wire hit=line_valid[index] && line_tag[index]==tag;
    assign c_req_ready=state==IDLE;
    assign m_req_valid=state==SEND;
    assign m_req_addr=address;assign m_req_write=write_enable;
    assign m_req_wdata=write_data;assign m_req_wmask=byte_mask;
    integer k;
    always @(posedge clk) begin
        if(reset) begin
            state<=IDLE;address<=0;write_data<=0;write_enable<=0;byte_mask<=0;
            c_rsp_valid<=0;c_rsp_error<=0;c_rsp_data<=0;
            read_hits<=0;read_misses<=0;write_requests<=0;
            for(k=0;k<LINES;k=k+1) begin line_valid[k]<=0;line_tag[k]<=0;line_data[k]<=0;end
        end else begin
            c_rsp_valid<=0;
            case(state)
                IDLE: if(c_req_valid) begin
                    address<=c_req_addr;write_enable<=c_req_write;write_data<=c_req_wdata;byte_mask<=c_req_wmask;state<=LOOKUP;
                end
                LOOKUP: begin
                    if(!write_enable && hit) begin
                        c_rsp_valid<=1;c_rsp_error<=0;c_rsp_data<=line_data[index];read_hits<=read_hits+1'b1;state<=IDLE;
                    end else begin
                        state<=SEND;
                        if(write_enable) write_requests<=write_requests+1'b1;
                        else read_misses<=read_misses+1'b1;
                    end
                end
                SEND: if(m_req_ready) state<=WAIT_RSP;
                WAIT_RSP: if(m_rsp_valid) begin
                    c_rsp_valid<=1;c_rsp_error<=m_rsp_error;c_rsp_data<=m_rsp_data;state<=IDLE;
                    if(!m_rsp_error) begin
                        if(!write_enable) begin line_valid[index]<=1;line_tag[index]<=tag;line_data[index]<=m_rsp_data;end
                        else if(hit) begin
                            for(k=0;k<4;k=k+1) if(byte_mask[k]) line_data[index][k*8+:8]<=write_data[k*8+:8];
                        end
                    end
                end
            endcase
        end
    end
endmodule
