// One request and one response buffer. Redirect drains uncancellable stale work.
module rv32_fetch #(parameter integer FAST_FETCH=1)(input wire clk, reset, halt, redirect,
    input wire [31:0] redirect_pc,
    output reg req_valid, input wire req_ready, output reg [31:0] req_addr,
    input wire rsp_valid, rsp_error, input wire [31:0] rsp_data,
    output reg out_valid, input wire out_ready,
    output reg [31:0] out_pc, out_insn, output reg out_error);
    reg pending, discard;
    reg [31:0] next_pc, pending_pc;
    always @(posedge clk) begin
        if(reset) begin
            req_valid<=0; req_addr<=0; pending<=0; discard<=0; next_pc<=0;
            pending_pc<=0; out_valid<=0; out_pc<=0; out_insn<=0; out_error<=0;
        end else begin
            if(out_valid && out_ready) out_valid<=0;
            if(req_valid && req_ready) begin
                req_valid<=0; pending<=1; pending_pc<=req_addr;
            end
            if(pending && rsp_valid) begin
                pending<=0;
                if(!discard && !redirect && !halt) begin
                    out_valid<=1; out_pc<=pending_pc;
                    out_insn<=rsp_error ? 32'b0 : rsp_data; out_error<=rsp_error;
                end
                discard<=0;
            end
            if(!req_valid && !pending && (!out_valid || (FAST_FETCH!=0 && out_ready)) && !halt && !redirect) begin
                req_valid<=1; req_addr<=next_pc; next_pc<=next_pc+4; discard<=0;
            end
            if(redirect) begin
                next_pc<=redirect_pc; out_valid<=0;
                discard<=(req_valid || pending) && !(pending && rsp_valid);
            end
        end
    end
endmodule
