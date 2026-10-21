// Source-use decoding only. Legality and execution live in rv32_execute.
module rv32_decode(input wire [31:0] insn,
    output wire [4:0] rs1, rs2, rd,
    output reg use1, use2, writes_rd, is_mem);
    assign rs1=insn[19:15]; assign rs2=insn[24:20]; assign rd=insn[11:7];
    always @* begin
        use1=0; use2=0; writes_rd=0; is_mem=0;
        case (insn[6:0])
            7'h37,7'h17,7'h6f: writes_rd=1;
            7'h67,7'h13: begin use1=1; writes_rd=1; end
            7'h33: begin use1=1; use2=1; writes_rd=1; end
            7'h63: begin use1=1; use2=1; end
            7'h03: begin use1=1; writes_rd=1; is_mem=1; end
            7'h23: begin use1=1; use2=1; is_mem=1; end
            default: begin end
        endcase
    end
endmodule
