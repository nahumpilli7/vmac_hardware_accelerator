# 🚀 Four-Lane INT16 Vector Multiply-Accumulate Hardware Accelerator
[![RTL simulation](https://github.com/nahumpilli7/vmac_hardware_accelerator/actions/workflows/rtl-sim.yml/badge.svg)](https://github.com/nahumpilli7/vmac_hardware_accelerator/actions/workflows/rtl-sim.yml)

**Pipelined RTL | Verilog, Vivado, ready/valid streaming, Zynq IP packaging**

## 🧩 Overview  
This project implements four parallel multiply-accumulate lanes in handwritten Verilog. Each lane computes `y = mask ? c : (a × b + c)` using 16-bit operands and a 32-bit addend/result, with selectable signed or unsigned arithmetic and modulo-2³² overflow behavior.

The core uses a two-stage elastic ready/valid pipeline. Its `a_vec` and `b_vec` operand buses are 64 bits each (4 × 16), while `c_vec` and `y_vec` are 128 bits each (4 × 32). At 200 MHz, the four lanes provide **0.8 GMAC/s**, or **1.6 GOPS** when a multiply and an addition are counted as separate operations.

The retained Vivado synthesis report for the standalone `top_fpga` demonstration wrapper shows **57 LUTs, 23 flip-flops, and 4 DSP48E1 blocks total (one DSP per lane)**. The committed Xilinx IP configuration files also show that the core was packaged into a Zynq block-design experiment containing AXI DMA and Processing System IP. The block-design export, accelerator adapter, and host software were not retained, so this repository does not claim a reproducible end-to-end DMA system.

> **Custom-silicon counterpart:** this project is the complex-datapath and SoC-integration piece. For the full custom physical-implementation flow — a complete RTL-to-GDSII ASIC built on a hand-made standard-cell library (transistor schematics → hand-drawn layout → DRC/LVS → SPICE characterization → synthesis, P&R, and signoff), see the [Synchronous Memory Controller ASIC](https://github.com/nahumpilli7/synchronous-memory-controller-asic).

![Block Diagram](docs/block_diagram.png)
![Schematic1](docs/rtl_schematic_core.png)
![schematic2](docs/rtl_schematic_top.png)

---

## ⚙️ Key Features
- **Four Parallel Lanes:** Four independent INT16 × INT16 multiply-add operations per accepted vector.
- **Elastic Two-Stage Pipeline:** Ready/valid back-pressure with an initiation interval of one cycle when unstalled.
- **Signed and Unsigned Modes:** Runtime-selectable interpretation with deterministic 32-bit wraparound.
- **Per-Lane Masking:** A masked lane bypasses multiplication and returns its `c` input.
- **DSP-Efficient Mapping:** The retained Vivado report shows four DSP48E1 blocks total—one per lane.

---

## 🧠 Design Highlights
- Fully pipelined datapath with a plain, reusable ready/valid streaming interface.
- Self-checking regression with an independent arithmetic reference model.
- Directed corner cases plus sustained randomized traffic and two-sided back-pressure.
- Automated open-source simulation in GitHub Actions; run the same regression locally with `make sim`.
- Retained Vivado synthesis and timing evidence for the standalone FPGA demonstration top.

---

## 🧮 Performance Summary
| Metric | Result |
|:--|:--|
| Frequency | 200 MHz |
| Throughput | 0.8 GMAC/s; 1.6 GOPS counting multiply + add separately |
| Pipeline | 2 stages; initiation interval 1 when unstalled |
| Setup Slack | +2.606 ns WNS at a 5 ns period |
| Resource Utilization | 57 LUTs, 23 FFs, 4 DSP48E1 total (`top_fpga`) |
| Interface Widths | 64-bit A/B operands; 128-bit C/result |

---

### ⏱️ Design Timing Summary

All user-specified timing constraints are met.

| Type | Worst Slack | Failing Endpoints |
|------|--------------|-------------------|
| **Setup (WNS)** | 2.606 ns | 0 |
| **Hold (WHS)** | 0.098 ns | 0 |
| **Pulse Width (WPWS)** | 3.500 ns | 0 |

---

## 🧰 Tools & Technologies
- **Language:** Verilog
- **EDA Tools:** Vivado and Icarus Verilog (OSS CAD Suite)
- **Target:** Xilinx Zynq-7000 (`xc7z020` in the retained synthesis report)
- **Validation:** Self-checking RTL simulation and retained Vivado synthesis/timing artifacts
- **Version Control:** Git & GitHub  

---

## ✅ Validation & Testing
- **Directed arithmetic:** Unsigned, signed, mask, zero, and wraparound corner cases.
- **Streaming stress:** Sustained randomized input traffic with randomized input and output back-pressure.
- **Self-checking scoreboard:** Every accepted transaction is compared in order against an independent reference model.
- **Continuous integration:** `make sim` runs on every push and pull request using a pinned OSS CAD Suite release.
- **Synthesis evidence:** The retained Vivado report and timing summary document the standalone FPGA demonstration build.

See [RTL verification results](results/rtl-verification.md) for the exact test scope, commands, and evidence boundaries.

---

## 🧩 Future Enhancements
- Extend to **radix-based division / multiplication units** for RISC-V vector processors.  
- Add **parameterized precision support** (INT8/INT16/FP32).  
- Integrate **software-configurable accumulation modes** via AXI-Lite.  
- Explore **ASIC porting and TinyML benchmarking** for further performance scaling.  

---

## 👤 Author
**Nahum Pilli**  
📍 Richardson, TX  
🔗 [LinkedIn](https://linkedin.com/in/nahum-pilli-9b7495230) | 📧 nahumpilli@gmail.com  
