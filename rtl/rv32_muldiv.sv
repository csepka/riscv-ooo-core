// Iterative RV32M unit: 32 shift/add or restoring-divide steps, one result pulse.
// Flush synchronously cancels a speculative operation and its completion.
module rv32_muldiv(input wire clk,reset,flush,start,
    output wire ready,input wire [2:0] funct3,input wire [31:0] a,b,
    output reg done,output reg [31:0] value);
    reg busy;reg [5:0] step;
    reg [2:0] operation;
    reg negate_product,negate_quotient,negate_remainder,divide_zero;
    reg [31:0] original_a,multiplier,quotient,divisor;
    reg [63:0] multiplicand,product;
    reg [32:0] remainder;
    wire signed_a=(funct3==1 || funct3==2 || funct3==4 || funct3==6) && a[31];
    wire signed_b=(funct3==1 || funct3==4 || funct3==6) && b[31];
    wire [31:0] magnitude_a=signed_a ? (~a+1'b1) : a;
    wire [31:0] magnitude_b=signed_b ? (~b+1'b1) : b;
    wire [63:0] product_step=product+(multiplier[0] ? multiplicand : 64'b0);
    wire [63:0] corrected_product=negate_product ? (~product_step+1'b1) : product_step;
    wire [32:0] shifted_remainder={remainder[31:0],quotient[31]};
    wire subtract_divisor=shifted_remainder>={1'b0,divisor};
    wire [32:0] remainder_step=subtract_divisor ? shifted_remainder-{1'b0,divisor} : shifted_remainder;
    wire [31:0] quotient_step={quotient[30:0],subtract_divisor};
    wire [31:0] corrected_quotient=negate_quotient ? (~quotient_step+1'b1) : quotient_step;
    wire [31:0] corrected_remainder=negate_remainder ? (~remainder_step[31:0]+1'b1) : remainder_step[31:0];
    wire unused_remainder_high=remainder[32];
    assign ready=!busy;
    always @(posedge clk) begin
        if(reset || flush) begin
            busy<=0;done<=0;value<=0;step<=0;operation<=0;
            negate_product<=0;negate_quotient<=0;negate_remainder<=0;divide_zero<=0;
            original_a<=0;multiplier<=0;quotient<=0;divisor<=0;multiplicand<=0;product<=0;remainder<=0;
        end else begin
            done<=0;
            if(start && ready) begin
                busy<=1;step<=0;operation<=funct3;original_a<=a;
                negate_product<=signed_a^signed_b;negate_quotient<=signed_a^signed_b;negate_remainder<=signed_a;
                divide_zero<=b==0;multiplier<=magnitude_b;multiplicand<={32'b0,magnitude_a};product<=0;
                quotient<=magnitude_a;divisor<=magnitude_b;remainder<=0;
            end else if(busy) begin
                step<=step+1'b1;
                if(operation<4) begin
                    product<=product_step;multiplicand<=multiplicand<<1;multiplier<=multiplier>>1;
                    if(step==31) value<=operation==0 ? corrected_product[31:0] : corrected_product[63:32];
                end else begin
                    quotient<=quotient_step;remainder<=remainder_step;
                    if(step==31) begin
                        if(divide_zero) value<=operation[1] ? original_a : 32'hffffffff;
                        else value<=operation[1] ? corrected_remainder : corrected_quotient;
                    end
                end
                if(step==31) begin busy<=0;done<=1;end
            end
        end
    end
endmodule
