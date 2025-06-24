# Optimization Plan for quic.zig

## Notes
- quic.zig is an image decoding library in Zig.
- Current performance is about 3x slower than LZ and GLZ.
- Goal: Optimize for speed without changing output.
- Initial bottleneck analysis complete: inner pixel loops, dynamic allocation, and bounds checks are main issues.
- User approved implementing low-risk optimizations: pointer arithmetic, unchecked access, preallocation, inlining helpers, and memory prefetch.
- All first-pass optimizations implemented: unchecked access, pointer arithmetic, preallocation, inlining, memory prefetch. CorrelateRow dynamic allocation solved via preallocation.
- Benchmark: ~17% performance improvement over previous version.
- Next step: Investigate and implement deeper optimizations (multi-symbol Golomb decoding, SIMD, etc.).
- Multi-symbol Golomb batch decoder LUT, struct, and wrapper implemented and wired into build; compilation and tests passing.
- Integration of batch decoder caused a runtime segfault (likely due to unchecked access or index error in pixel decode path); needs debugging before further benchmarking.

## Task List
- [x] Review current code structure and logic in quic.zig
- [x] Identify performance bottlenecks (e.g., via profiling or code inspection)
- [x] Propose and implement code optimizations
  - [x] Convert inner loops to pointer arithmetic and unchecked access
  - [x] Pre-compute per-pixel indexes once per pixel
  - [x] Inline small helpers and drop optionals
  - [x] Replace dynamic ArrayList in CorrelateRow with pre-allocated buffer
  - [x] Add memory prefetch for prev_row accesses
- [x] Benchmark optimized code against LZ and GLZ
- [ ] Validate that output remains unchanged
- [ ] Investigate and implement deeper optimizations (multi-symbol Golomb, SIMD, etc.)
  - [x] Implement multi-symbol Golomb batch decoder (LUT, struct, wrapper)
  - [x] Integrate batch decoder into pixel decode path
  - [ ] Debug and fix segfault in batch decoder integration
  - [ ] Benchmark and validate output after batch decode integration
  - [ ] Implement SIMD path for pixel loop (optional)

## Current Goal
Benchmark and implement deeper optimizations