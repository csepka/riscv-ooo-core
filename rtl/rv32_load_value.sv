module rv32_load_value(input wire [31:0] word_data, input wire [1:0] offset,
    input wire [2:0] funct3, output reg [31:0] value);
    reg [31:0] shifted;
    always @* begin
        shifted=word_data>>{offset,3'b0};
        case(funct3)
            0: value={{24{shifted[7]}},shifted[7:0]};
            1: value={{16{shifted[15]}},shifted[15:0]};
            4: value={24'b0,shifted[7:0]};
            5: value={16'b0,shifted[15:0]};
            default: value=shifted;
        endcase
    end
endmodule
