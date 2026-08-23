# VMAC accelerator — simulation regression
# Requires: Icarus Verilog (iverilog + vvp)
IVERILOG ?= iverilog
VVP      ?= vvp
BUILD    ?= build

RTL := src/mac4x16_top.v src/mac_lane.v
TB  := tb/mac_tb.v

.PHONY: sim clean
sim:
	@mkdir -p $(BUILD)
	$(IVERILOG) -g2012 -s mac_tb -o $(BUILD)/mac_sim $(RTL) $(TB)
	$(VVP) $(BUILD)/mac_sim

clean:
	rm -rf $(BUILD)

