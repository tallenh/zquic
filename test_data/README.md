# Test Data

This directory contains test images and data files for the QUIC decoder.

## Files

### Main Test Image
- `quic_image_0.bin` - 1920x1080 RGB32 QUIC compressed image (234KB)
  - Used by benchmarks and integration tests
  - Contains a real SPICE QUIC compressed image with header

### Small Test Vectors
- `encoded_10x10_*.hex` - Small 10x10 RGB32 test images in hex format
  - `black` - All black pixels
  - `white` - All white pixels  
  - `red` - All red pixels
  - `blue` - All blue pixels
  - `green` - All green pixels
  - `custom` - Custom test pattern
  - `rgb_pattern` - RGB test pattern

These small test vectors are useful for:
- Unit testing specific decoder functionality
- Debugging decoder issues
- Verifying color channel handling

## Usage

All test files should be accessed with the `test_data/` prefix:
```zig
const data = try std.fs.cwd().readFileAlloc(allocator, "test_data/quic_image_0.bin", size);
```

## Format Notes

- `.bin` files contain raw QUIC compressed data with headers
- `.hex` files contain hex-encoded compressed data (2 chars per byte)
- All RGB32 images use BGRA byte order with 0 padding byte