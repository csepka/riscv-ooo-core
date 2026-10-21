`timescale 1ns/1ps
module core_tb;
    parameter integer DEPTH=16;
    parameter integer CACHE=0;
    parameter integer FAST_FETCH=1;
    reg clk=0,reset=1;
    always #5 clk=~clk;
    wire iv,dv,dw; reg ir,dr,irv=0,drv=0,ie=0,de=0;
    wire [31:0] ia,da,dd; wire [3:0] dm;
    reg [31:0] id=0, data=0;
    wire halt,rv,rm,rt,ev,full,mwait,redirect;
    wire [31:0] rp,ri,rval,ra,rdt,ep,occ;
    wire [4:0] rr; wire [3:0] rmask,rc;
    wire civ, cir, cirv, cie, cdv, cdr, cdrv, cde, cdw;
    wire [31:0] cia,cid,cda,cdd,cddata;wire [3:0] cdm;
    wire [31:0] ihits,imisses,dhits,dmisses,cache_writes;
    generate if(CACHE!=0) begin: cached
        wire unused_iwrite;wire [31:0] unused_iwdata,unused_iwrites;wire [3:0] unused_iwmask;
        rv32_cache icache(clk,reset,civ,cir,cia,1'b0,32'b0,4'b0,cirv,cie,cid,
            iv,ir,ia,unused_iwrite,unused_iwdata,unused_iwmask,irv,ie,id,ihits,imisses,unused_iwrites);
        rv32_cache dcache(clk,reset,cdv,cdr,cda,cdw,cdd,cdm,cdrv,cde,cddata,
            dv,dr,da,dw,dd,dm,drv,de,data,dhits,dmisses,cache_writes);
    end else begin: uncached
        assign iv=civ;assign cir=ir;assign ia=cia;assign cirv=irv;assign cie=ie;assign cid=id;
        assign dv=cdv;assign cdr=dr;assign da=cda;assign dw=cdw;assign dd=cdd;assign dm=cdm;
        assign cdrv=drv;assign cde=de;assign cddata=data;
        assign ihits=0;assign imisses=0;assign dhits=0;assign dmisses=0;assign cache_writes=0;
    end endgenerate
`ifdef BASELINE
    rv32_baseline #(.FAST_FETCH(FAST_FETCH)) dut(
`else
    rv32_ooo #(.ROB_DEPTH(DEPTH),.FAST_FETCH(FAST_FETCH)) dut(
`endif
        .clk(clk),.reset(reset),.i_req_valid(civ),.i_req_ready(cir),.i_req_addr(cia),
        .i_rsp_valid(cirv),.i_rsp_error(cie),.i_rsp_data(cid),
        .d_req_valid(cdv),.d_req_ready(cdr),.d_req_addr(cda),.d_req_write(cdw),.d_req_wdata(cdd),.d_req_wmask(cdm),
        .d_rsp_valid(cdrv),.d_rsp_error(cde),.d_rsp_data(cddata),.halted(halt),
        .retire_valid(rv),.retire_pc(rp),.retire_insn(ri),.retire_rd(rr),.retire_value(rval),
        .retire_mem(rm),.retire_addr(ra),.retire_data(rdt),.retire_mask(rmask),.retire_trap(rt),.retire_cause(rc),
        .exec_valid(ev),.exec_pc(ep),.debug_occupancy(occ),.debug_full(full),.debug_mem_wait(mwait),.debug_redirect(redirect));
    reg [31:0] imem[0:8191];
    reg [7:0] mem[0:4095];
    integer nwords, latency, ilatency, seed, limit, ifault, reset_at;
    integer reset_countdown=0, epoch_start=0;
    integer cycle=0, epoch=0, itimer=-1,dtimer=-1;
    reg [31:0] ipa,dpa,dpd; reg dpw; reg [3:0] dpm;
    reg [31:0] rng,delay_rng;
    string program_path, trace_path;
    integer fd,k,retired=0,occ_sum=0,occ_max=0,full_cycles=0,mem_cycles=0,execs=0,redirects=0;
    integer core_data_start=0,data_latency_sum=0,data_requests=0;
    reg held_i=0,held_d=0; reg [31:0] old_ia,old_da,old_dd; reg old_dw; reg [3:0] old_dm;
    initial begin
        if(!$value$plusargs("program=%s",program_path)) $fatal(1,"program missing");
        if(!$value$plusargs("trace=%s",trace_path)) trace_path="build/trace.txt";
        if(!$value$plusargs("words=%d",nwords)) nwords=8192;
        if(!$value$plusargs("latency=%d",latency)) latency=8;
        if(!$value$plusargs("ilatency=%d",ilatency)) ilatency=0;
        if(!$value$plusargs("seed=%d",seed)) seed=1;
        if(!$value$plusargs("limit=%d",limit)) limit=200000;
        if(!$value$plusargs("ifault=%d",ifault)) ifault=-1;
        if(!$value$plusargs("reset_at=%d",reset_at)) reset_at=-1;
        for(k=0;k<8192;k=k+1) imem[k]=32'h00100073;
        $readmemh(program_path,imem,0,nwords-1);
        fd=$fopen(trace_path,"w"); rng=seed;delay_rng=seed;
        repeat(3) @(negedge clk);
        reset=0;
    end
    // Drive/record on falling edges, avoiding races with RTL state transitions.
    always @(negedge clk) begin
        if(reset) begin
            ir=0;dr=0;irv=0;drv=0;itimer=-1;dtimer=-1;
            held_i=0;held_d=0;delay_rng=seed;data_requests=0;data_latency_sum=0;core_data_start=0;
            for(k=0;k<4096;k=k+1) mem[k]=0;
            if(reset_countdown>0) begin
                reset_countdown=reset_countdown-1;
                if(reset_countdown==0) begin reset=0;epoch_start=cycle;end
            end
        end else begin
            cycle=cycle+1;
            if(cycle>limit) $fatal(1,"timeout/deadlock");
            if(rv) begin
                $fdisplay(fd,"R %0d %08x %08x %0d %08x %0d %08x %08x %x %0d %0d",cycle,rp,ri,rr,rval,rm,ra,rdt,rmask,rt,rc);
                retired=retired+1;
            end
            occ_sum=occ_sum+occ; if(occ>occ_max) occ_max=occ;
            if(full) full_cycles=full_cycles+1;
            if(mwait) mem_cycles=mem_cycles+1;
            if(redirect) redirects=redirects+1;
            if(halt) begin
                for(k=0;k<4096;k=k+1) if(mem[k]!=0) $fdisplay(fd,"D %0d %02x",k,mem[k]);
                $fdisplay(fd,"M %0d %0d %0d %0d %0d %0d %0d %0d",cycle-epoch_start,retired,occ_sum,occ_max,full_cycles,mem_cycles,execs,redirects);
                `ifndef BASELINE
                $fdisplay(fd,"Q rs_sum=%0d rs_max=%0d md_busy_cycles=%0d md_completions=%0d ooo_events=%0d head_operand_wait=%0d empty_cycles=%0d alu_idle_cycles=%0d",rs_sum,rs_max,md_cycles,md_results,ooo_events,head_wait,empty_cycles,issue_idle);
`endif
                $fdisplay(fd,"L %0d %0d",data_requests,data_latency_sum);
                $fdisplay(fd,"C %0d %0d %0d %0d %0d",ihits,imisses,dhits,dmisses,cache_writes);
                $fclose(fd); $display("PASS cycles=%0d retired=%0d",cycle,retired); $finish;
            end
            rng=rng^(rng<<13);rng=rng^(rng>>17);rng=rng^(rng<<5);
            ir=(itimer<0) && rng[0]; dr=(dtimer<0) && rng[1];
            irv=0;drv=0;
            if(itimer==0) begin
                irv=1; ie=(ipa/4>=nwords || ipa==ifault); id=ie ? 0 : imem[ipa/4]; itimer=-1;
            end else if(itimer>0) itimer=itimer-1;
            if(dtimer==0) begin
                drv=1;de=dpa>=4096;data=0;
                if(!de) begin
                    for(k=0;k<4;k=k+1) begin
                        if(dpw && dpm[k]) mem[dpa+k]=dpd[k*8+:8];
                        data[k*8+:8]=mem[dpa+k];
                    end
                end
                dtimer=-1;
            end else if(dtimer>0) dtimer=dtimer-1;
            if(cycle==reset_at) begin
                reset=1; epoch=epoch+1; $fdisplay(fd,"RESET %0d",cycle);
                retired=0;occ_sum=0;occ_max=0;full_cycles=0;mem_cycles=0;execs=0;redirects=0;
                reset_countdown=3;
            end
        end
    end
    always @(posedge clk) if(!reset) begin
        if(held_i && (!iv || ia!=old_ia)) $fatal(1,"instruction request changed under backpressure");
        if(held_d && (!dv || da!=old_da || dd!=old_dd || dw!=old_dw || dm!=old_dm)) $fatal(1,"data request changed under backpressure");
        if(cdv&&cdr) begin core_data_start=cycle;data_requests=data_requests+1;end
        if(cdrv) data_latency_sum=data_latency_sum+cycle-core_data_start;
        held_i=iv&&!ir;old_ia=ia;held_d=dv&&!dr;old_da=da;old_dd=dd;old_dw=dw;old_dm=dm;
        if(iv&&ir) begin
            if(itimer>=0) $fatal(1,"multiple instruction requests");
            ipa=ia;itimer=ilatency;
        end
        if(dv&&dr) begin
            if(dtimer>=0) $fatal(1,"multiple data requests");
            dpa=da;dpd=dd;dpm=dm;dpw=dw;dtimer=latency+int'(delay_rng[7:4]);
            delay_rng=delay_rng^(delay_rng<<13);delay_rng=delay_rng^(delay_rng>>17);delay_rng=delay_rng^(delay_rng<<5);
        end
        if(ev) begin $fdisplay(fd,"E %0d %08x",cycle,ep);execs=execs+1; end
    end
`ifndef BASELINE
`include "tb/ooo_checks.vh"
`endif
endmodule
