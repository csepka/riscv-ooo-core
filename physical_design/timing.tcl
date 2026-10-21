# Requires an installed OpenSTA, mapped netlist, and its exact matching Liberty.
# Not executed in this environment; no parasitic model or physical delay claim.
if {![info exists ::env(LIBERTY)]} { error "Set LIBERTY to the mapped cell library" }
read_liberty $::env(LIBERTY)
read_verilog build/mapped.v
link_design synthesized_core
read_sdc physical_design/constraints.sdc
check_setup
report_checks -path_delay max -format full_clock_expanded
report_checks -path_delay min -format full_clock_expanded
report_worst_slack -max
report_worst_slack -min
report_tns
