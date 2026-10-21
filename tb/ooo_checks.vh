    // Testbench-only structural and sequence invariants. Never synthesized.
    integer check_i, check_j, live_count, distance_i, distance_tag;
    integer seq[0:DEPTH-1],alloc_seq=0,expected_seq=0;
    integer simultaneous=0,wraps=0,dual_complete=0,fetch_flush_pending=0,fetch_flush_blocked=0,full_seen=0,md_flush_busy=0,md_dual=0,triple_complete=0;
    integer rs_sum=0,rs_max=0,rs_now=0,md_cycles=0,md_results=0,ooo_events=0,head_wait=0,empty_cycles=0,issue_idle=0;
    always @(posedge clk) begin
        if(reset) begin
            alloc_seq=0;expected_seq=0;rs_sum=0;rs_max=0;md_cycles=0;md_results=0;ooo_events=0;head_wait=0;empty_cycles=0;issue_idle=0;
            for(check_i=0;check_i<DEPTH;check_i=check_i+1) seq[check_i]=-1;
        end else begin
            if(DEPTH!=16 && DEPTH!=32) $fatal(1,"unsupported ROB depth");
            if(dut.count>DEPTH) $fatal(1,"ROB overflow");
            if(dut.arch[0]!=0 || dut.map_valid[0]) $fatal(1,"x0 corruption");
            live_count=0;rs_now=0;
            for(check_i=0;check_i<DEPTH;check_i=check_i+1) begin
                distance_i=(check_i-int'(dut.head)+DEPTH)%DEPTH;
                if(dut.valid[check_i]) live_count=live_count+1;
                if(dut.valid[check_i] && !dut.issued[check_i] && !dut.done[check_i]) rs_now=rs_now+1;
                if(dut.valid[check_i] != (distance_i<int'(dut.count))) $fatal(1,"ROB hole/lost allocation");
                if(dut.valid[check_i] && !dut.ready1[check_i]) begin
                    distance_tag=(int'(dut.tag1[check_i])-int'(dut.head)+DEPTH)%DEPTH;
                    if(!dut.valid[dut.tag1[check_i]] || distance_tag>=distance_i || !dut.writes[dut.tag1[check_i]]) $fatal(1,"source1 stale tag");
                end
                if(dut.valid[check_i] && !dut.ready2[check_i]) begin
                    distance_tag=(int'(dut.tag2[check_i])-int'(dut.head)+DEPTH)%DEPTH;
                    if(!dut.valid[dut.tag2[check_i]] || distance_tag>=distance_i || !dut.writes[dut.tag2[check_i]]) $fatal(1,"source2 stale tag");
                end
            end
            if(live_count!=dut.count) $fatal(1,"ROB count mismatch");
            for(check_j=1;check_j<32;check_j=check_j+1) begin
                if(dut.map_valid[check_j]) begin
                    if(!dut.valid[dut.map_tag[check_j]] || dut.dest[dut.map_tag[check_j]]!=check_j || !dut.writes[dut.map_tag[check_j]]) $fatal(1,"invalid rename map");
                    for(check_i=0;check_i<DEPTH;check_i=check_i+1)
                        if(dut.valid[check_i] && dut.writes[check_i] && dut.dest[check_i]==check_j && seq[check_i]>seq[dut.map_tag[check_j]]) $fatal(1,"rename map not youngest");
                end
            end
            if(dut.retire_fire) begin
                if(seq[dut.head]!=expected_seq) $fatal(1,"out of order/double retirement");
                expected_seq=expected_seq+1;
            end
            if(dut.alu_fire && (!dut.valid[dut.issue_tag] || dut.issued[dut.issue_tag] || dut.done[dut.issue_tag])) $fatal(1,"invalid/double execution");
            if(dut.flush && dut.mem_pending) $fatal(1,"flush with outstanding data request");
            if(dut.mem_complete && (!dut.valid[dut.head] || !dut.issued[dut.head])) $fatal(1,"stale memory completion");
            rs_sum=rs_sum+rs_now;if(rs_now>rs_max) rs_max=rs_now;
            if(!dut.md_ready) md_cycles=md_cycles+1;
            if(dut.count==0) empty_cycles=empty_cycles+1;
            if(dut.count!=0 && (!dut.ready1[dut.head] || !dut.ready2[dut.head])) head_wait=head_wait+1;
            if(!dut.alu_fire) issue_idle=issue_idle+1;
            if(dut.alu_fire && dut.issue_tag!=dut.head && !dut.done[dut.head]) ooo_events=ooo_events+1;
            if(dut.md_complete) begin
                md_results=md_results+1;
                if(!dut.valid[dut.md_tag] || !dut.issued[dut.md_tag] || dut.done[dut.md_tag]) $fatal(1,"stale/duplicate M completion");
                $fdisplay(fd,"E %0d %08x",cycle,dut.pc[dut.md_tag]);
                if(dut.md_tag!=dut.head && !dut.done[dut.head]) ooo_events=ooo_events+1;
            end
            if(dut.flush && !dut.md_ready) md_flush_busy=md_flush_busy+1;
            if(dut.md_complete && dut.alu_fire) md_dual=md_dual+1;
            if(dut.md_complete && dut.alu_fire && dut.mem_complete) triple_complete=triple_complete+1;
            if(dut.dispatch) $fdisplay(fd,"A %0d %08x",cycle,dut.fp);
            if(dut.flush && !dut.exception[dut.head]) $fdisplay(fd,"F %0d %08x",cycle,dut.next_pc[dut.head]);
            if(dut.dispatch && dut.retire_fire) simultaneous=simultaneous+1;
            if(dut.dispatch && dut.tail==DEPTH-1) wraps=wraps+1;
            if(dut.alu_fire && dut.mem_complete) dual_complete=dual_complete+1;
            if(dut.flush && dut.fetch.pending) fetch_flush_pending=fetch_flush_pending+1;
            if(dut.flush && dut.fetch.req_valid && !cir) fetch_flush_blocked=fetch_flush_blocked+1;
            if(full) full_seen=full_seen+1;
            if(dut.flush) expected_seq=alloc_seq;
            if(dut.dispatch) begin seq[dut.tail]=alloc_seq;alloc_seq=alloc_seq+1;end
        end
    end
    final begin
        $display("COVER simultaneous=%0d wraps=%0d dual_complete=%0d fetch_pending_flush=%0d fetch_blocked_flush=%0d full=%0d md_flush_busy=%0d md_alu_complete=%0d triple_complete=%0d",simultaneous,wraps,dual_complete,fetch_flush_pending,fetch_flush_blocked,full_seen,md_flush_busy,md_dual,triple_complete);
    end
