// ROB value renaming, integrated reservation stations, two completion broadcasts.
module rv32_ooo #(parameter integer ROB_DEPTH=16,parameter integer FAST_FETCH=1)(
input wire clk, reset,
    output wire i_req_valid, input wire i_req_ready, output wire [31:0] i_req_addr,
    input wire i_rsp_valid, i_rsp_error, input wire [31:0] i_rsp_data,
    output wire d_req_valid, input wire d_req_ready, output wire [31:0] d_req_addr,
    output wire d_req_write, output wire [31:0] d_req_wdata, output wire [3:0] d_req_wmask,
    input wire d_rsp_valid, d_rsp_error, input wire [31:0] d_rsp_data,
    output reg halted,
    output reg retire_valid, output reg [31:0] retire_pc, retire_insn,
    output reg [4:0] retire_rd, output reg [31:0] retire_value,
    output reg retire_mem, output reg [31:0] retire_addr, retire_data,
    output reg [3:0] retire_mask, output reg retire_trap, output reg [3:0] retire_cause,
    output wire exec_valid, output wire [31:0] exec_pc,
    output wire [31:0] debug_occupancy, output wire debug_full, debug_mem_wait,
    output wire debug_redirect
);
    localparam integer TAG_W=$clog2(ROB_DEPTH);
    localparam integer COUNT_W=TAG_W+1;
    reg [TAG_W-1:0] head,tail;
    reg [COUNT_W-1:0] count;
    reg [31:0] arch[0:31];
    reg map_valid[0:31]; reg [TAG_W-1:0] map_tag[0:31];
    reg valid[0:ROB_DEPTH-1], issued[0:ROB_DEPTH-1], done[0:ROB_DEPTH-1];
    reg [31:0] pc[0:ROB_DEPTH-1],insn[0:ROB_DEPTH-1],result[0:ROB_DEPTH-1],next_pc[0:ROB_DEPTH-1];
    reg [4:0] dest[0:ROB_DEPTH-1];
    reg writes[0:ROB_DEPTH-1],memory_op[0:ROB_DEPTH-1],exception[0:ROB_DEPTH-1];
    reg [3:0] exc_cause[0:ROB_DEPTH-1];
    reg ready1[0:ROB_DEPTH-1],ready2[0:ROB_DEPTH-1];
    reg [31:0] operand1[0:ROB_DEPTH-1],operand2[0:ROB_DEPTH-1];
    reg [TAG_W-1:0] tag1[0:ROB_DEPTH-1],tag2[0:ROB_DEPTH-1];
    reg [31:0] mem_addr[0:ROB_DEPTH-1],mem_data[0:ROB_DEPTH-1];
    reg [3:0] mem_mask[0:ROB_DEPTH-1];
    reg mem_pending;
    wire fv,fe,fu1,fu2,fw,fm; wire [31:0] fp,fi; wire [4:0] fr1,fr2,fd;
    wire retire_fire=count!=0 && valid[head] && done[head] && !halted;
    wire flush=retire_fire && (exception[head] || next_pc[head]!=pc[head]+4);
    wire dispatch=fv && count<COUNT_W'(ROB_DEPTH) && !halted && !flush;
    rv32_fetch #(.FAST_FETCH(FAST_FETCH)) fetch(clk,reset,halted,flush,next_pc[head],i_req_valid,i_req_ready,i_req_addr,
        i_rsp_valid,i_rsp_error,i_rsp_data,fv,dispatch,fp,fi,fe);
    rv32_decode decode(fi,fr1,fr2,fd,fu1,fu2,fw,fm);

    reg md_found;reg [TAG_W-1:0] md_issue_tag;
    reg issue_found; reg [TAG_W-1:0] issue_tag;
    integer scan; reg [TAG_W-1:0] idx;
    always @* begin
        issue_found=0; issue_tag=0; idx=0;md_found=0;md_issue_tag=0;
        for(scan=0;scan<ROB_DEPTH;scan=scan+1) begin
            idx=head+TAG_W'(scan);
            if(!issue_found && valid[idx] && !issued[idx] && !done[idx] &&
               !memory_op[idx] && !(insn[idx][6:0]==7'h33 && insn[idx][31:25]==1) && ready1[idx] && ready2[idx]) begin
                issue_found=1; issue_tag=TAG_W'(idx);
            end
            if(!md_found && valid[idx] && !issued[idx] && !done[idx] &&
               insn[idx][6:0]==7'h33 && insn[idx][31:25]==1 && ready1[idx] && ready2[idx]) begin
                md_found=1;md_issue_tag=idx;
            end
        end
    end
    wire md_ready,md_complete;wire [31:0] md_value;
    reg [TAG_W-1:0] md_tag;
    wire md_start=md_found && md_ready && !flush && !halted;
    rv32_muldiv muldiv(clk,reset,flush,md_start,md_ready,insn[md_issue_tag][14:12],
        operand1[md_issue_tag],operand2[md_issue_tag],md_complete,md_value);
    wire alu_fire=issue_found && !flush && !halted;
    wire [31:0] av,an,unused_aa,unused_ad; wire [3:0] unused_am,ac; wire unused_ast,at;
    rv32_execute alu(pc[issue_tag],insn[issue_tag],operand1[issue_tag],operand2[issue_tag],av,an,unused_aa,unused_ad,unused_am,unused_ast,at,ac);
    wire mem_candidate=count!=0 && valid[head] && memory_op[head] && !issued[head] &&
        !done[head] && ready1[head] && ready2[head] && !mem_pending && !halted && !flush;
    wire [31:0] unused_mv,unused_mn,ma,md; wire [3:0] mm,mc; wire mst,mt;
    rv32_execute mem_ex(pc[head],insn[head],operand1[head],operand2[head],unused_mv,unused_mn,ma,md,mm,mst,mt,mc);
    assign d_req_valid=mem_candidate && !mt;
    assign d_req_addr={ma[31:2],2'b0}; assign d_req_write=mst;
    assign d_req_wdata=md; assign d_req_wmask=mm;
    wire mem_accept=d_req_valid && d_req_ready;
    wire mem_complete=mem_pending && d_rsp_valid;
    wire mem_fault=mem_candidate && mt;
    wire [31:0] load_val;
    rv32_load_value load_decode(d_rsp_data,mem_addr[head][1:0],insn[head][14:12],load_val);
    assign exec_valid=alu_fire; assign exec_pc=pc[issue_tag];
    assign debug_occupancy={{(32-COUNT_W){1'b0}},count};
    assign debug_full=count==COUNT_W'(ROB_DEPTH); assign debug_mem_wait=mem_pending;
    assign debug_redirect=flush && !exception[head];

    reg src1_ready,src2_ready; reg [31:0] src1,src2;
    reg [TAG_W-1:0] src1_tag,src2_tag;
    always @* begin
        src1_ready=1;src2_ready=1;src1=0;src2=0;src1_tag=0;src2_tag=0;
        if(fu1 && fr1!=0) begin
            src1=arch[fr1];
            if(map_valid[fr1]) begin
                src1_tag=map_tag[fr1]; src1_ready=done[src1_tag]; src1=result[src1_tag];
                if(alu_fire && issue_tag==src1_tag) begin src1_ready=1;src1=av;end
                if(mem_complete && head==src1_tag) begin src1_ready=1;src1=load_val;end
                if(md_complete && md_tag==src1_tag) begin src1_ready=1;src1=md_value;end
            end
        end
        if(fu2 && fr2!=0) begin
            src2=arch[fr2];
            if(map_valid[fr2]) begin
                src2_tag=map_tag[fr2]; src2_ready=done[src2_tag]; src2=result[src2_tag];
                if(alu_fire && issue_tag==src2_tag) begin src2_ready=1;src2=av;end
                if(mem_complete && head==src2_tag) begin src2_ready=1;src2=load_val;end
                if(md_complete && md_tag==src2_tag) begin src2_ready=1;src2=md_value;end
            end
        end
    end
    integer k;
    always @(posedge clk) begin
        if(reset) begin
            head<=0;tail<=0;count<=0;mem_pending<=0;halted<=0;md_tag<=0;
            retire_valid<=0;retire_pc<=0;retire_insn<=0;retire_rd<=0;retire_value<=0;
            retire_mem<=0;retire_addr<=0;retire_data<=0;retire_mask<=0;retire_trap<=0;retire_cause<=0;
            for(k=0;k<32;k=k+1) begin arch[k]<=0;map_valid[k]<=0;map_tag[k]<=0;end
            for(k=0;k<ROB_DEPTH;k=k+1) begin
                valid[k]<=0;issued[k]<=0;done[k]<=0;pc[k]<=0;insn[k]<=0;result[k]<=0;next_pc[k]<=0;
                dest[k]<=0;writes[k]<=0;memory_op[k]<=0;exception[k]<=0;exc_cause[k]<=0;
                ready1[k]<=0;ready2[k]<=0;operand1[k]<=0;operand2[k]<=0;tag1[k]<=0;tag2[k]<=0;
                mem_addr[k]<=0;mem_data[k]<=0;mem_mask[k]<=0;
            end
        end else begin
            retire_valid<=retire_fire;
            if(retire_fire) begin
                retire_pc<=pc[head];retire_insn<=insn[head];
                retire_rd<=writes[head] && !exception[head] ? dest[head] : 5'b0;
                retire_value<=writes[head] && dest[head]!=0 && !exception[head] ? result[head] : 32'b0;
                retire_mem<=memory_op[head] && !exception[head];
                retire_addr<=memory_op[head] && !exception[head] ? mem_addr[head] : 32'b0;
                retire_data<=memory_op[head] && !exception[head] ? mem_data[head] : 32'b0;
                retire_mask<=memory_op[head] && !exception[head] ? mem_mask[head] : 4'b0;
                retire_trap<=exception[head];retire_cause<=exc_cause[head];
                if(writes[head] && dest[head]!=0 && !exception[head]) arch[dest[head]]<=result[head];
                if(exception[head]) halted<=1;
            end
            if(flush) begin
                head<=0;tail<=0;count<=0;mem_pending<=0;
                for(k=0;k<ROB_DEPTH;k=k+1) begin valid[k]<=0;issued[k]<=0;done[k]<=0;end
                for(k=0;k<32;k=k+1) map_valid[k]<=0;
            end else begin
                case({dispatch,retire_fire})
                    2'b10: count<=count+1'b1;
                    2'b01: count<=count-1'b1;
                    default: begin end
                endcase
                if(retire_fire) begin
                    valid[head]<=0;head<=head+1'b1;
                    if(writes[head] && map_valid[dest[head]] && map_tag[dest[head]]==head)
                        map_valid[dest[head]]<=0;
                end
                for(k=0;k<ROB_DEPTH;k=k+1) begin
                    if(valid[k]) begin
                        if(!ready1[k]) begin
                            if(alu_fire && tag1[k]==issue_tag) begin ready1[k]<=1;operand1[k]<=av;end
                            if(mem_complete && tag1[k]==head) begin ready1[k]<=1;operand1[k]<=load_val;end
                            if(md_complete && tag1[k]==md_tag) begin ready1[k]<=1;operand1[k]<=md_value;end
                        end
                        if(!ready2[k]) begin
                            if(alu_fire && tag2[k]==issue_tag) begin ready2[k]<=1;operand2[k]<=av;end
                            if(mem_complete && tag2[k]==head) begin ready2[k]<=1;operand2[k]<=load_val;end
                            if(md_complete && tag2[k]==md_tag) begin ready2[k]<=1;operand2[k]<=md_value;end
                        end
                    end
                end
                if(alu_fire) begin
                    issued[issue_tag]<=1;done[issue_tag]<=1;result[issue_tag]<=av;next_pc[issue_tag]<=an;
                    exception[issue_tag]<=at;exc_cause[issue_tag]<=ac;
                end
                if(md_start) begin issued[md_issue_tag]<=1;md_tag<=md_issue_tag;end
                if(md_complete) begin done[md_tag]<=1;result[md_tag]<=md_value;end
                if(mem_accept) begin
                    issued[head]<=1;mem_pending<=1;mem_addr[head]<=ma;mem_data[head]<=md;mem_mask[head]<=mm;
                end
                if(mem_fault) begin
                    issued[head]<=1;done[head]<=1;exception[head]<=1;exc_cause[head]<=mc;
                end
                if(mem_complete) begin
                    mem_pending<=0;done[head]<=1;result[head]<=load_val;
                    exception[head]<=d_rsp_error;
                    exc_cause[head]<=d_rsp_error ? (insn[head][6:0]==7'h23 ? 4'd7 : 4'd5) : 4'b0;
                end
                if(dispatch) begin
                    valid[tail]<=1;issued[tail]<=0;done[tail]<=fe;pc[tail]<=fp;insn[tail]<=fi;
                    dest[tail]<=fd;writes[tail]<=fw && fd!=0;memory_op[tail]<=fm;
                    ready1[tail]<=src1_ready;ready2[tail]<=src2_ready;operand1[tail]<=src1;operand2[tail]<=src2;
                    tag1[tail]<=src1_tag;tag2[tail]<=src2_tag;
                    result[tail]<=0;next_pc[tail]<=fp+4;exception[tail]<=fe;exc_cause[tail]<=fe ? 4'd1 : 4'b0;
                    mem_addr[tail]<=0;mem_data[tail]<=0;mem_mask[tail]<=0;
                    if(fw && fd!=0) begin map_valid[fd]<=1;map_tag[fd]<=tail;end
                    tail<=tail+1'b1;
                end
            end
            arch[0]<=0;map_valid[0]<=0;
        end
    end
endmodule
