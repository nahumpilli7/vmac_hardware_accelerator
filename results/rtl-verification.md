# RTL Verification Results

## Automated regression

The repository regression compiles and runs two testbenches with Icarus Verilog:

```sh
make sim
```

The primary self-checking testbench, `tb/mac_tb.v`, uses an independent arithmetic reference model and an in-order scoreboard. It covers directed signed, unsigned, masked, zero, and overflow-wrap cases, followed by 2,000 cycles of sustained randomized traffic with randomized source valid and sink ready behavior.

For the retained deterministic seed, the regression accepts and checks 1,297 transactions with zero mismatches:

```text
SUMMARY: ACCEPTED=1297 CHECKED=1297 FAIL=0
ALL TESTS PASSED
```

The testbench also checks that the pipeline drains completely and fails on queue overflow, unexpected output, data mismatch, or drain timeout. The GitHub Actions workflow runs this same command on every push and pull request.

## Evidence boundaries

- The regression verifies the committed four-lane RTL core and its ready/valid behavior; it does not verify a Zynq DMA subsystem.
- The retained Vivado utilization report applies to the standalone `top_fpga` demonstration wrapper.
- The committed `.xci` files show that a Zynq block-design experiment existed, but the block-design export, interface adapter, and host software are not retained here.
