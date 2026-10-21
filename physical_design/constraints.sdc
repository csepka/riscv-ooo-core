# Example integration budget only. This is NOT an achieved clock frequency.
create_clock -name core_clk -period 20.0 [get_ports clk]
set_clock_uncertainty 0.2 [get_clocks core_clk]
set_input_delay 2.0 -clock core_clk [get_ports {reset i_req_ready i_rsp_valid i_rsp_error i_rsp_data* d_req_ready d_rsp_valid d_rsp_error d_rsp_data*}]
set_output_delay 2.0 -clock core_clk [all_outputs]
