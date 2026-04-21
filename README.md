# FIRCore
Hardware-Accelerated 64-Tap FIR Filter: A high-performance SystemVerilog implementation of a 16-bit Finite Impulse Response (FIR) filter featuring a dedicated MAC unit, programmable coefficient memory (CMEM), and a robust asynchronous FIFO for clock domain crossing (10 kHz to 100 MHz)

---

# FIR Filter Hardware Accelerator (fircore)

## Overview
This repository contains a high-performance, parameterizable **Finite Impulse Response (FIR) Filter** architecture implemented in SystemVerilog. The system is designed as a hardware accelerator that offloads complex DSP computations from a general-purpose processor, utilizing a dedicated multiply-accumulate (MAC) unit and a custom control FSM.

### Key Technical Highlights:
* **Multi-Clock Domain Architecture:** Implements a robust FIFO bridge to synchronize data between a low-speed input domain (10 kHz) and a high-speed processing domain (100 MHz).
* **Advanced Datapath Design:** Features a 64-tap register chain and a synchronous Coefficient Memory (CMEM) for flexible filter configuration.
* **Custom FSM Control:** Orchestrates a complex calculation loop including data loading, MAC execution, and result validation.
* **Fixed-Point Arithmetic:** Utilizes Q-format (Q7.9) precision for signal processing accuracy.

---

## Architecture & Modules

### 1. Clock Domain Crossing (CDC) - `fircoreFIFO`
To handle the transition between the slow data source and the fast filter core, I implemented a **Toggle-Synchronizer based FIFO**.
* Uses a 3-stage synchronization chain to eliminate metastability.
* Implements edge detection logic to pulse "new data" flags across clock boundaries.

### 2. Computational Core - `fircoreALU` & `multiply`
The heart of the system is a high-performance Arithmetic Logic Unit.
* **Sequential Multiplier:** A state-machine-based multiplier that performs 16-bit signed multiplication over multiple clock cycles to optimize timing slack.
* **Accumulator:** A 33-bit signed accumulator that prevents overflow during the summation of 64 distinct taps.
* **Bit-Shifting/Scaling:** Automatically scales the 32-bit internal product back to a 16-bit Q-format output.

### 3. Memory & Storage - `fircoreREG` & `fircoreCMEM`
* **Tap Chain:** A generative 64-stage shift register that holds the history of input samples.
* **Coefficient Memory:** A programmable memory block allowing users to update filter coefficients (Low-pass, High-pass, etc.) on-the-fly without re-synthesizing the hardware.

### 4. Controller - `fircoreFSM`
A 6-state Moore Machine that manages the lifecycle of a single sample calculation:
1.  **Idle/Clear:** Resets the accumulator for a new sample.
2.  **Load:** Fetches the specific Tap ($x[n]$) and Coefficient ($c[k]$).
3.  **Execute:** Triggers the sequential multiplier.
4.  **Wait:** Synchronizes with the ALU's `Done` signal.
5.  **Loop:** Iterates through all 64 taps before asserting `valid_out`.

---

## Technical Skills Demonstrated
* **Languages:** SystemVerilog, Verilog.
* **Hardware Design:** RTL Design, Finite State Machines (FSM), Datapath/Controller separation.
* **Digital Signal Processing:** FIR Filter structures, Fixed-point arithmetic, MAC units.
* **Verification:** Developed a comprehensive testbench (`tb_fircore`) with mock data streaming, CMEM programming, and clock generation.
* **Tools:** Expertise in timing synchronization and handling metastability in hardware.

---

## How to Run
### Simulation
1.  Load `design.sv` and `testbench.sv` into your simulator (e.g., ModelSim, Vivado, or Icarus Verilog).
2.  Run the simulation for at least 2ms to observe the processing of the 10-sample burst.
3.  Monitor the `CONSUMER` logs in the console to verify output validity and data accuracy.

### File Structure
* `design.sv`: Contains the RTL implementation of the FIR core, ALU, FIFO, and Memory.
* `testbench.sv`: System-level verification environment with dual-clock generation and data drivers.

---

## Future Enhancements
* Implement a circular buffer in the `REG` module to reduce the power consumption associated with shifting the entire 64-register chain.
* Add support for AXI-Stream interfaces for standard industry integration.

