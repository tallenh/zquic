# Optimization Plan for quic.zig

## Overview
This document outlines the optimization strategy for the QUIC image decoder implementation in Zig.

## Current Status
- Base implementation complete and functional
- Passes all compatibility tests with JavaScript reference implementation
- Performance benchmarks vs SPICE C implementation:
  - **C (SPICE)**: 13.1ms average (602.12 MB/s)
  - **Zig**: 22.2ms average (357.07 MB/s)
  - **C is 1.69x faster**
- Already achieved 6% improvement with @clz optimization
- ~17% performance improvement from initial optimizations (pointer arithmetic, unchecked access, preallocation)

## Optimization Targets (Updated from C Analysis)

### HIGH IMPACT (Implement First)
1. **Memory Layout & Structure Packing**
   - Use packed structures for pixels (RGB32, RGB24, RGBA)
   - Align data structures to cache line boundaries
   - Enable SIMD vectorization opportunities

2. **I/O Buffer Management**
   - Switch from byte-based to 32-bit word-based I/O
   - Direct memory-mapped buffer access
   - Platform-specific endianness handling

3. **Loop Unrolling & Vectorization**
   - Manual 4x/8x loop unrolling in hot paths
   - Use Zig's @Vector types for SIMD operations
   - Process multiple pixels simultaneously

### MEDIUM-HIGH IMPACT
4. **Direct Memory Access**
   - Replace array indexing with pointer arithmetic in hot paths
   - Skip bounds checking with @setRuntimeSafety(false)
   - Prefetch next row data

5. **Bucket Access Optimization**
   - Direct pointer access to buckets
   - Skip null checks in hot paths
   - Cache frequently accessed buckets

### MEDIUM IMPACT
6. **Inline Function Optimization**
   - Mark all hot-path functions as inline
   - Use comptime for aggressive inlining
   - Already using @setRuntimeSafety(false)

7. **Branch Prediction Hints**
   - Use @setCold(true) for error paths
   - Optimize for common case paths
   - Reduce branch mispredictions

8. **Precomputed Tables**
   - Golomb code lookup tables
   - Bit pattern tables
   - Cache frequently computed values

## Expected Performance Gains
- **Conservative**: 25-30% improvement
- **Optimistic**: 40-50% improvement  
- **Best case** (with full SIMD): 60-70% improvement

## Task List
- [x] Review current code structure and logic in quic.zig
- [x] Identify performance bottlenecks (e.g., via profiling or code inspection)
- [x] Propose and implement code optimizations
  - [x] Convert inner loops to pointer arithmetic and unchecked access
  - [x] Pre-compute per-pixel indexes once per pixel
  - [x] Inline small helpers and drop optionals
  - [x] Replace dynamic ArrayList in CorrelateRow with pre-allocated buffer
  - [x] Add memory prefetch for prev_row accesses
- [x] Benchmark optimized code against C implementation
- [ ] Implement HIGH IMPACT optimizations
  - [ ] Memory layout & structure packing
  - [ ] I/O buffer management (32-bit words)
  - [ ] Loop unrolling & vectorization
- [ ] Validate that output remains unchanged after each optimization
- [ ] Implement MEDIUM-HIGH IMPACT optimizations
- [ ] Final benchmarking and performance validation

## Previous Work
- Multi-symbol Golomb batch decoder implemented but caused segfault
- Need to debug and fix before further integration
- Initial optimizations achieved ~17% improvement

## Implementation Priority
1. Immediate: Memory layout, I/O optimization, loop vectorization
2. Short-term: Direct memory access, bucket optimization
3. Long-term: Branch prediction, precomputed tables

## Benchmarking Strategy
- Compare against JavaScript reference implementation ✓
- Compare against C implementation from SPICE ✓
- Focus on decode speed for 1920x1080 RGB32 images ✓
- Track memory usage and allocation patterns
- Measure impact of each optimization independently