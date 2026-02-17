# MMU-Based Cache Control Architecture for Multi-Core Processors

An advanced Memory Management Unit (MMU) designed in VHDL to manage cache coherence in multi-core environments using the **MESI Protocol** and a **Snooping** architecture[cite: 1, 9, 15]. [cite_start]This project was developed at the **Technical University of Cluj-Napoca**[cite: 4].

## Overview

The system provides a robust framework for managing data exchange between main memory and local caches across three processor cores[cite: 9, 196]. [cite_start]By utilizing a special-purpose MMU, the architecture reduces latency and ensures data consistency through a hardware-level snooping agent[cite: 13, 16].

### Key Features
**Protocol**: Full implementation of the **MESI** (Modified, Exclusive, Shared, Invalid) coherence protocol[cite: 15, 58].
**Architecture**: 3-core system with a shared bus and a centralized Bus Arbiter[cite: 196, 396].
**Coherence**: Bus snooping with an "Abort" mechanism to prevent stale data reads during Modified (M) state conflicts[cite: 16, 21, 22].
**Replacement Policy**: Least Recently Used (LRU) implemented via a physical shift-register array[cite: 153, 157].
**Hardware Ready**: Optimized for the **Basys 3 FPGA** and verified using **Vivado**[cite: 490, 549].

---

## System Architecture

The project consists of several modular VHDL components synchronized to manage memory traffic efficiently[cite: 429].


### Core Components
1.**Cores (CPUs)**: Deterministic traffic generators controlled by an FSM to issue Read/Write requests.
2.**L1 Cache**: Fully associative cache with 16 lines[cite: 37, 196]. [cite_start]Each line includes a 14-bit tag, 2 MESI bits, and 32 bits of data.
3.**Cache Controller**: The "Snooping Agent" that monitors bus traffic and enforces state transitions.
4.**Bus Arbiter**: Resolves contention using a **Fixed Priority Scheme** (Core 0 > Core 1 > Core 2).
5.**Main Memory (RAM)**: Synchronous 1-byte addressable memory with a size of $2^{16}$.

---

## MESI State Machine & Coherence

The system maintains consistency by tracking four distinct states for every cache line[cite: 58]:

| State | Description |
| :--- | :--- |
| **Modified (00)** | Line is dirty and exists only in the current cache. |
| **Exclusive (01)** | Line is clean and exists only in the current cache. |
| **Shared (10)** | Line is clean and may exist in multiple caches. |
| **Invalid (11)** | Line is invalid/empty. |

### The Abort Mechanism
If a core requests data held by another cache in the **Modified** state, the controller asserts `o_bus_abort`. This stops the RAM from serving stale data and forces the owner to "Flush" (write-back) the modified data to RAM first.

---

## Cache Management

### LRU Replacement Policy
To minimize conflict misses, the system uses a physical shift-register array of 16 lines. 
**On a Hit**: The accessed line at index $k$ is saved, lines $0$ to $k-1$ shift down, and the saved line moves to Index 0 (MRU).
**On a Miss**: The entire array shifts down ($j$ moves to $j+1$), and the new data is placed at Index 0.
**Eviction**: If the cache is full, the line at Index 15 is pushed out. If it was "Modified," it is automatically written back to RAM.

---

## Testing & Verification

### Simulation (Vivado)
The design was verified through 9 specific scenarios, including:
  **Cold Read Misses**.
  **Write Invalidations** (Shared $\to$ Modified).
  **Silent Upgrades** (Exclusive $\to$ Modified).
  **Capacity Evictions**.

### Hardware Emulation (Basys 3)
The project includes a hardware testing suite triggered by the FPGA buttons:
**BtnU**: System Reset.
**BtnC**: Step through the test ROM.
**LD15**: Error Indicator (Data Mismatch).
**LD13-LD6**: 8-bit Data Display.

---

## Requirements
**Software**: Xilinx Vivado (2019.1 or newer recommended).
**Hardware**: Basys 3 FPGA (Artix-7).

## Author
**Ovidiu-Alexandru Lates**.
