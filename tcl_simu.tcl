open_proj -quiet {C:\Users\Francisco\Desktop\esther_sim/esther_sim.xpr}
#reset_run synth_1 -quiet
#launch_runs synth_1 
#wait_on_run synth_1 
#open_run synth_1 
#report_utilization -hierarchical -file report_file.txt
#report_timing -file report_timing.txt
set_property top trigg_tb [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
#set_property generic {delay_a=300, level_a=0} [current_fileset]  
update_compile_order -fileset sim_1
set_property -name {xsim.simulate.runtime} -value {65us} -objects [current_fileset -simset]
launch_simulation -quiet  
