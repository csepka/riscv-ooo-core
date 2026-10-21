`timescale 1ns/1ps
module muldiv_tb;
    reg clk=0,reset=1,flush=0,start=0;always #5 clk=~clk;
    reg [2:0] f=0;reg [31:0] a=0,b=0;wire ready,done;wire [31:0] value;
    rv32_muldiv dut(clk,reset,flush,start,ready,f,a,b,done,value);
    reg [31:0] va,vb,expected;integer vf,fd,n,passed=0,t;
    string path;
    initial begin
        if(!$value$plusargs("vectors=%s",path)) $fatal(1,"vectors missing");
        fd=$fopen(path,"r");repeat(3) @(negedge clk);reset=0;
        while(!$feof(fd)) begin
            n=$fscanf(fd,"%h %h %h %h\n",vf,va,vb,expected);
            if(n==4) begin
                @(negedge clk);if(!ready) $fatal(1,"unit not ready");f=vf[2:0];a=va;b=vb;start=1;
                @(negedge clk);start=0;t=0;
                while(!done && t<40) begin @(negedge clk);t=t+1;end
                if(!done || value!==expected || t!=32) $fatal(1,"M mismatch f=%0d a=%h b=%h value=%h expected=%h cycles=%0d",vf,a,b,value,expected,t);
                passed=passed+1;
            end
        end
        // Cancellation must suppress an old completion before tag reuse.
        @(negedge clk);start=1;f=4;a=123;b=7;
        @(negedge clk);start=0;repeat(10) @(negedge clk);flush=1;
        @(negedge clk);flush=0;
        repeat(40) begin @(negedge clk);if(done) $fatal(1,"stale M completion after flush");end
        if(!ready) $fatal(1,"flush failed to free M unit");
        $display("PASS muldiv vectors=%0d cancellation=1",passed);$finish;
    end
endmodule
