module rv32_baseline(
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
    output wire debug_redirect);
    reg [31:0] regs[0:31];
    wire fv, fe; wire [31:0] fp, fi;
    wire [4:0] rs1, rs2, rd;
    wire u1,u2,wr,mem;
    wire [31:0] val,npc,addr,wd;
    wire [3:0] mask,cause;
    wire store,trap;
    reg [1:0] state;
    reg [31:0] m_pc,m_insn,m_addr,m_data;
    reg [3:0] m_mask;
    reg m_store;
    wire [31:0] load_val;
    wire accepting=fv && state==0 && !halted;
    wire redir=accepting && !mem && !trap && !fe && npc!=fp+4;
    rv32_fetch fetch(clk,reset,halted,redir,npc,i_req_valid,i_req_ready,i_req_addr,
        i_rsp_valid,i_rsp_error,i_rsp_data,fv,accepting,fp,fi,fe);
    rv32_decode dec(fi,rs1,rs2,rd,u1,u2,wr,mem);
    rv32_execute ex(fp,fi,regs[rs1],regs[rs2],val,npc,addr,wd,mask,store,trap,cause);
    rv32_load_value lv(d_rsp_data,m_addr[1:0],m_insn[14:12],load_val);
    assign d_req_valid=state==1;
    assign d_req_addr={m_addr[31:2],2'b0};
    assign d_req_write=m_store; assign d_req_wdata=m_data; assign d_req_wmask=m_mask;
    assign exec_valid=accepting; assign exec_pc=fp;
    assign debug_occupancy={30'b0,state}; assign debug_full=0;
    assign debug_mem_wait=state!=0; assign debug_redirect=redir;
    integer k;
    always @(posedge clk) begin
        if(reset) begin
            for(k=0;k<32;k=k+1) regs[k]<=0;
            state<=0; halted<=0; retire_valid<=0; retire_pc<=0; retire_insn<=0;
            retire_rd<=0; retire_value<=0; retire_mem<=0; retire_addr<=0;
            retire_data<=0; retire_mask<=0; retire_trap<=0; retire_cause<=0;
            m_pc<=0;m_insn<=0;m_addr<=0;m_data<=0;m_mask<=0;m_store<=0;
        end else begin
            retire_valid<=0;
            if(accepting) begin
                if(mem && !trap && !fe) begin
                    state<=1; m_pc<=fp; m_insn<=fi; m_addr<=addr;
                    m_data<=wd; m_mask<=mask; m_store<=store;
                end else begin
                    retire_valid<=1; retire_pc<=fp; retire_insn<=fi;
                    retire_rd<=(wr && rd!=0 && !trap && !fe) ? rd : 5'b0;
                    retire_value<=(wr && rd!=0 && !trap && !fe) ? val : 32'b0;
                    retire_mem<=0; retire_addr<=0; retire_data<=0; retire_mask<=0;
                    retire_trap<=trap||fe; retire_cause<=fe ? 4'd1 : cause;
                    if(wr && rd!=0 && !trap && !fe) regs[rd]<=val;
                    if(trap||fe) halted<=1;
                end
            end
            if(state==1 && d_req_ready) state<=2;
            if(state==2 && d_rsp_valid) begin
                state<=0; retire_valid<=1; retire_pc<=m_pc; retire_insn<=m_insn;
                retire_rd<=(!m_store && !d_rsp_error) ? m_insn[11:7] : 5'b0;
                retire_value<=(!m_store && !d_rsp_error && m_insn[11:7]!=0) ? load_val : 32'b0;
                retire_mem<=!d_rsp_error; retire_addr<=d_rsp_error ? 32'b0 : m_addr;
                retire_data<=d_rsp_error ? 32'b0 : m_data; retire_mask<=d_rsp_error ? 4'b0 : m_mask;
                retire_trap<=d_rsp_error; retire_cause<=d_rsp_error ? (m_store ? 4'd7 : 4'd5) : 4'b0;
                if(!m_store && !d_rsp_error && m_insn[11:7]!=0) regs[m_insn[11:7]]<=load_val;
                if(d_rsp_error) halted<=1;
            end
            regs[0]<=0;
        end
    end
endmodule
