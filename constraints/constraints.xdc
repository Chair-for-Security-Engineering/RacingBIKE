create_clock -period 8.80 -name clk -waveform {0.000 4.40} [get_ports clk]

set_property IOSTANDARD LVCMOS33 [get_ports {resetn}]
set_property IOSTANDARD LVCMOS33 [get_ports {start}]
set_property IOSTANDARD LVCMOS33 [get_ports {busy}]
set_property IOSTANDARD LVCMOS33 [get_ports {done}]

set_property IOSTANDARD LVCMOS33 [get_ports {instruction[*]}]

set_property IOSTANDARD LVCMOS33 [get_ports {rand_valid}]
set_property IOSTANDARD LVCMOS33 [get_ports {rand_request}]
set_property IOSTANDARD LVCMOS33 [get_ports {rand_din[*]}]

set_property IOSTANDARD LVCMOS33 [get_ports {din_ready}]
set_property IOSTANDARD LVCMOS33 [get_ports {din_load[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {din_done[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {din_addr[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {din[*]}]

set_property IOSTANDARD LVCMOS33 [get_ports {request_data[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {request_done[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dout_valid[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dout_addr[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dout[*]}]

