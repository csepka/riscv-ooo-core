module rv32_execute(
    input wire [31:0] pc, insn, a, b,
    output reg [31:0] value, next_pc, addr, wdata,
    output reg [3:0] wmask,
    output reg store, trap,
    output reg [3:0] cause
);
    reg [31:0] imm_i, imm_s, imm_b, imm_j, rhs;
    reg take_branch;
    reg [2:0] f;
    always @* begin
        f=insn[14:12];
        imm_i={{20{insn[31]}},insn[31:20]};
        imm_s={{20{insn[31]}},insn[31:25],insn[11:7]};
        imm_b={{19{insn[31]}},insn[31],insn[7],insn[30:25],insn[11:8],1'b0};
        imm_j={{11{insn[31]}},insn[31],insn[19:12],insn[20],insn[30:21],1'b0};
        rhs=insn[6:0]==7'h13 ? imm_i : b;
        value=0; next_pc=pc+4; addr=0; wdata=0; wmask=0;
        store=0; trap=0; cause=0; take_branch=0;
        case(insn[6:0])
            7'h37: value={insn[31:12],12'b0};
            7'h17: value=pc+{insn[31:12],12'b0};
            7'h6f: begin value=pc+4; next_pc=pc+imm_j; end
            7'h67: begin
                value=pc+4; next_pc=(a+imm_i)&32'hfffffffe;
                if(f!=0) begin trap=1; cause=2; end
            end
            7'h63: begin
                case(f)
                    0: take_branch=a==b;
                    1: take_branch=a!=b;
                    4: take_branch=$signed(a)<$signed(b);
                    5: take_branch=$signed(a)>=$signed(b);
                    6: take_branch=a<b;
                    7: take_branch=a>=b;
                    default: begin trap=1; cause=2; end
                endcase
                if(take_branch) next_pc=pc+imm_b;
            end
            7'h13,7'h33: begin
                case(f)
                    0: value=(insn[6:0]==7'h33 && insn[30]) ? a-rhs : a+rhs;
                    1: value=a<<rhs[4:0];
                    2: value={31'b0,($signed(a)<$signed(rhs))};
                    3: value={31'b0,(a<rhs)};
                    4: value=a^rhs;
                    5: value=insn[30] ? $unsigned($signed(a)>>>rhs[4:0]) : a>>rhs[4:0];
                    6: value=a|rhs;
                    7: value=a&rhs;
                endcase
                if(insn[6:0]==7'h33) begin
                    if(insn[31:25]!=0 && !(insn[31:25]==7'h20 && (f==0 || f==5))) begin trap=1; cause=2; end
                end else if((f==1 && insn[31:25]!=0) || (f==5 && insn[31:25]!=0 && insn[31:25]!=7'h20)) begin trap=1; cause=2; end
            end
            7'h03,7'h23: begin
                store=insn[6:0]==7'h23; addr=a+(store ? imm_s : imm_i);
                wdata=b<<{addr[1:0],3'b0};
                case(f)
                    0,4: wmask=4'b0001<<addr[1:0];
                    1,5: wmask=4'b0011<<addr[1:0];
                    2: wmask=4'b1111;
                    default: begin trap=1; cause=2; end
                endcase
                if(store && f>2) begin trap=1; cause=2; end
                if(!trap && (((f==1 || f==5) && addr[0]) || (f==2 && addr[1:0]!=0))) begin
                    trap=1; cause=store ? 6 : 4;
                end
                if(!store) begin wmask=0; wdata=0; end
            end
            7'h0f: if(f!=0) begin trap=1; cause=2; end
            7'h73: begin
                trap=1;
                if(insn==32'h00000073) cause=11;
                else if(insn==32'h00100073) cause=3;
                else cause=2;
            end
            default: begin trap=1; cause=2; end
        endcase
        if(!trap && next_pc[1:0]!=0) begin trap=1; cause=0; end
    end
endmodule

