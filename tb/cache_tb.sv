`timescale 1ns/1ps
module cache_tb;
    parameter integer LINES=16;
    reg clk=0,reset=1;
    always #5 clk=~clk;
    reg cv=0,cw=0;wire cr,rv,re,mv,mw;reg mr=0,mrv=0,mre=0;
    reg [31:0] ca=0,cd=0,mrd=0;reg [3:0] cm=0;
    wire [31:0] rd,ma,md,hits,misses,writes;wire [3:0] mm;
    rv32_cache #(.LINES(LINES)) dut(clk,reset,cv,cr,ca,cw,cd,cm,rv,re,rd,mv,mr,ma,mw,md,mm,mrv,mre,mrd,hits,misses,writes);
    reg [31:0] backing[0:255],reference_mem[0:255];
    reg [31:0] rng=32'h12345678,pa,pd;reg pw;reg [3:0] pm;
    integer timer=-1,k,j,passed=0,cycles=0;
    reg held=0;reg [68:0] held_payload;
    always @(posedge clk) if(!reset) begin
        if(held && (!mv || {ma,mw,md,mm}!=held_payload)) $fatal(1,"unstable cache miss request");
        held=mv&&!mr;held_payload={ma,mw,md,mm};
        if(mv&&mr) begin
            if(timer>=0) $fatal(1,"cache multiple outstanding");
            pa=ma;pd=md;pw=mw;pm=mm;timer=2+int'(rng[7:4]);
        end
    end
    always @(negedge clk) begin
        cycles=cycles+1;if(cycles>100000) $fatal(1,"cache timeout");
        rng=rng^(rng<<13);rng=rng^(rng>>17);rng=rng^(rng<<5);
        mr=rng[0] && timer<0;mrv=0;
        if(timer==0) begin
            mrv=1;mre=pa>=1024;mrd=0;
            if(!mre) begin
                for(j=0;j<4;j=j+1) if(pw&&pm[j]) backing[pa/4][8*j+:8]=pd[8*j+:8];
                mrd=backing[pa/4];
            end
            timer=-1;
        end else if(timer>0) timer=timer-1;
    end
    task automatic transaction(input [31:0] address,input wr,input [31:0] data,input [3:0] mask);
        reg [31:0] expected;integer b;
        begin
            @(negedge clk);cv=1;ca=address;cw=wr;cd=data;cm=mask;
            do @(posedge clk); while(!cr);
            @(negedge clk);cv=0;
            do @(negedge clk); while(!rv);
            if(re!=(address>=1024)) $fatal(1,"cache error mismatch");
            if(address<1024) begin
                if(wr) for(b=0;b<4;b=b+1) if(mask[b]) reference_mem[address/4][8*b+:8]=data[8*b+:8];
                expected=reference_mem[address/4];
                if(!wr && rd!==expected) $fatal(1,"cache read mismatch addr=%h got=%h exp=%h",address,rd,expected);
            end
            passed=passed+1;
        end
    endtask
    initial begin
        for(k=0;k<256;k=k+1) begin backing[k]=k;reference_mem[k]=k;end
        repeat(3) @(negedge clk);reset=0;
        transaction(0,0,0,0);transaction(0,0,0,0);
        transaction(0,1,32'hdeadbeef,4'b0101);transaction(0,0,0,0);
        transaction(LINES*4,0,0,0);transaction(0,0,0,0);
        transaction(1024,0,0,0);transaction(1024,1,1,15);
        for(k=0;k<1000;k=k+1) transaction({22'b0,rng[7:0],2'b0},rng[8],rng^32'hbaadf00d,rng[12:9]);
        // Reset invalidates previously filled lines; backing contents persist.
        @(negedge clk);reset=1;repeat(2) @(negedge clk);reset=0;
        transaction(0,0,0,0);
        if(misses!=1 || hits!=0) $fatal(1,"cache reset did not invalidate");
        for(k=0;k<256;k=k+1) if(backing[k]!==reference_mem[k]) $fatal(1,"cache write mismatch");
        $display("PASS cache lines=%0d transactions=%0d",LINES,passed);$finish;
    end
endmodule
