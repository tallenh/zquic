# ZQuic - QUIC Image Decompression Library for Zig

A high-performance QUIC image decompression library implemented in Zig, supporting RGB32 and RGB24 formats with optimized decompression algorithms.

## Features

✅ **RGB32 Decompression** - Full 4-byte RGBA support  
✅ **RGB24 Decompression** - Optimized 3-byte RGB support  
✅ **High Performance** - Optimized algorithms with template specialization  
✅ **Memory Efficient** - Zero-copy operations where possible  
✅ **Comprehensive Testing** - 8 test cases covering solid colors and patterns  
✅ **Thread Safe** - Stateless decompression functions

## Usage in Your Zig Project

### Method 1: Using Zig Package Manager (Recommended)

1. Add this library as a dependency in your `build.zig.zon`:

```zig
.{
    .name = "your-project",
    .version = "0.1.0",
    .dependencies = .{
        .zquic = .{
            .url = "https://github.com/tallenh/zquic/archive/main.tar.gz",
            .hash = "1220...", // Generated automatically by `zig build`
        },
    },
}
```

2. Add the dependency in your `build.zig`:

```zig
const zquic = b.dependency("zquic", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("quic", zquic.module("quic"));
```

3. Use in your code:

```zig
const std = @import("std");
const quic = @import("quic");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize the QUIC library
    try quic.init();

    // Create a decoder
    var decoder = try quic.QuicEncoder.init(allocator);
    defer decoder.deinit();

    // Initialize channel model pointers (required after construction)
    decoder.initChannelPointers();

    // Option 1: Parse QUIC header from complete data
    const quic_data: []const u8 = /* your QUIC data with header */;
    const parse_success = try decoder.quicDecodeBegin(quic_data);

    if (parse_success) {
        // Decode the image
        if (try decoder.simpleQuicDecode(allocator)) |decoded_pixels| {
            defer allocator.free(decoded_pixels);

            // Use your decoded pixels
            std.debug.print("Decoded {}x{} image with {} bytes\n", .{
                decoder.width,
                decoder.height,
                decoded_pixels.len
            });
        }
    }

    // Option 2: Decode raw compressed data without header
    const raw_compressed_data: []const u8 = /* your raw QUIC compressed data */;
    const headerless_success = try decoder.quicDecodeBeginHeaderless(
        raw_compressed_data,
        4,    // image_type (e.g., 4 = RGB32)
        1920, // width
        1080  // height
    );

    if (headerless_success) {
        // Decode the image (same as above)
        if (try decoder.simpleQuicDecode(allocator)) |decoded_pixels| {
            defer allocator.free(decoded_pixels);
            // Use your decoded pixels...
        }
    }
}
```

### Method 2: Git Submodule (Alternative)

```bash
git submodule add https://github.com/tallenh/zquic.git libs/zquic
```

Then in your `build.zig`:

```zig
const quic_lib = b.addStaticLibrary(.{
    .name = "quic",
    .root_source_file = b.path("libs/zquic/src/quic.zig"),
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("quic", quic_lib.root_module);
```

## API Reference

### Core Functions

- `quic.init()` - Initialize the library (call once)
- `QuicEncoder.init(allocator)` - Create a new decoder instance
- `decoder.initChannelPointers()` - Initialize channel model pointers (required after init)
- `decoder.quicDecodeBegin(data)` - Parse QUIC header and validate format
- `decoder.quicDecodeBeginHeaderless(raw_data, image_type, width, height)` - Decode raw data without header
- `decoder.simpleQuicDecode(allocator)` - Decode the image data

### Supported Formats

- **RGB32** - 4 bytes per pixel (BGRA layout)
- **RGB24** - 3 bytes per pixel (BGR layout)

### Performance

- **Compression Ratios**: 3.8:1 to 8.3:1 depending on image content
- **Optimized Algorithms**: Template specialization for zero-cost abstractions
- **Memory Efficient**: Single-pass decompression with minimal allocations

## Testing

```bash
zig build test              # Run all tests (unit + integration)
zig build test-integration  # Run integration tests only (requires Node.js)
```

The integration test decodes real SPICE data and verifies byte-for-byte compatibility with the JavaScript reference implementation.

## Benchmarking

```bash
zig build bench-zig   # Run Zig benchmark
zig build bench-c     # Build and run C benchmark  
zig build bench-all   # Run both benchmarks for comparison
zig build benchmark   # Run detailed performance analysis
```

### Performance Results

Latest benchmark results (2048x1152 RGB32 image):
- **Zig**: ~1790 MB/s (4.4ms average)
- **C**: ~615 MB/s (12.9ms average)  
- **JavaScript**: ~11 MB/s (871ms average)

The optimized Zig implementation is approximately **2.9x faster** than the C implementation.

## License

MIT License - see LICENSE file for details.
