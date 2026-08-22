#!/usr/bin/env bash
set -euo pipefail
mkdir -p build
iverilog -g2012 -Wall -s mac_lane_tb -o build/mac_lane_tb.vvp src/mac_lane.v tb/mac_lane_tb.v
vvp build/mac_lane_tb.vvp
iverilog -g2012 -Wall -s mac_tb -o build/mac_tb.vvp src/mac_lane.v src/mac4x16_top.v tb/mac_tb.v
vvp build/mac_tb.vvp | tee build/mac_tb.log
grep -q '^ALL TESTS PASSED$' build/mac_tb.log
