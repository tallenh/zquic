# QUIC Decoder Benchmarks

This directory contains benchmarks comparing different QUIC decoder implementations.

## Files

- `benchmark` - Compiled Zig benchmark executable (built via `zig build benchmark`)
- `benchmark_c` - Compiled C benchmark executable using SPICE library
- `benchmark_zig.zig` - Standalone Zig benchmark (can be compiled directly)
- `benchmark_c.c` - C benchmark source using actual SPICE QUIC implementation
- `benchmark_js.js` - JavaScript benchmark for reference implementation
- `bench.zig` - Simple microbenchmarks for specific functions
- `benchmark.zig` - Main performance benchmark (built via build system)

## Running Benchmarks

### Using the build system (recommended):
```bash
# From project root
zig build bench-zig   # Run Zig benchmark only
zig build bench-c     # Build and run C benchmark only
zig build bench-all   # Run both benchmarks for comparison
zig build benchmark   # Run detailed performance benchmark
zig build bench      # Run microbenchmarks
```

The build system automatically:
- Rebuilds benchmarks when the QUIC decoder is updated
- Handles all compilation flags and library paths
- Runs benchmarks with consistent settings

### Running standalone benchmarks:
```bash
# From project root (required for test data files)
./benchmarks/benchmark      # Run Zig benchmark
./benchmarks/benchmark_c    # Run C benchmark
node benchmarks/benchmark_js.js  # Run JavaScript benchmark
```

### Building standalone benchmark:
```bash
# From benchmarks directory
zig build-exe benchmark_zig.zig -O ReleaseFast
```

## Results

Current performance comparison (1920x1080 RGB32 image):
- Zig: ~1800 MB/s (4.4ms)
- C: ~613 MB/s (12.9ms)  
- JavaScript: ~11 MB/s (871ms)

The optimized Zig implementation is approximately 2.9x faster than the C implementation.