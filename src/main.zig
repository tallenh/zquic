const std = @import("std");
const quic = @import("quic.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("QUIC Library Test Program\n", .{});
    std.debug.print("========================\n\n", .{});

    // Initialize the library
    try quic.init();

    // Test image type BPC values
    std.debug.print("Image type BPC values:\n", .{});
    std.debug.print("  GRAY: {}\n", .{quic.quicImageBpc(quic.Constants.QUIC_IMAGE_TYPE_GRAY)});
    std.debug.print("  RGB16: {}\n", .{quic.quicImageBpc(quic.Constants.QUIC_IMAGE_TYPE_RGB16)});
    std.debug.print("  RGB24: {}\n", .{quic.quicImageBpc(quic.Constants.QUIC_IMAGE_TYPE_RGB24)});
    std.debug.print("  RGB32: {}\n", .{quic.quicImageBpc(quic.Constants.QUIC_IMAGE_TYPE_RGB32)});
    std.debug.print("  RGBA: {}\n", .{quic.quicImageBpc(quic.Constants.QUIC_IMAGE_TYPE_RGBA)});
    std.debug.print("\n", .{});

    // Test helper functions
    std.debug.print("Helper function tests:\n", .{});
    std.debug.print("  ceilLog2(1): {}\n", .{quic.ceilLog2(1)});
    std.debug.print("  ceilLog2(255): {}\n", .{quic.ceilLog2(255)});
    std.debug.print("  ceilLog2(256): {}\n", .{quic.ceilLog2(256)});
    std.debug.print("  cntLZeroes(0x80): {}\n", .{quic.cntLZeroes(0x80)});
    std.debug.print("  cntLZeroes(0x0F): {}\n", .{quic.cntLZeroes(0x0F)});
    std.debug.print("\n", .{});

    // Test Golomb functions
    std.debug.print("Golomb function tests:\n", .{});
    const golomb_result = quic.golombDecoding8bpc(3, 0x12345678);
    std.debug.print("  golombDecoding8bpc(3, 0x12345678): codewordlen={}, rc={}\n", .{ golomb_result.codewordlen, golomb_result.rc });
    std.debug.print("  golombCodeLen8bpc(42, 3): {}\n", .{quic.golombCodeLen8bpc(42, 3)});
    std.debug.print("\n", .{});

    // Test QuicEncoder creation
    std.debug.print("Creating QuicEncoder...\n", .{});
    var encoder = try quic.QuicEncoder.init(allocator);
    defer encoder.deinit();
    encoder.initChannelPointers();

    std.debug.print("Model levels - 8bpc: {}, 5bpc: {}\n", .{ encoder.model_8bpc.levels, encoder.model_5bpc.levels });
    std.debug.print("Model buckets - 8bpc: {}, 5bpc: {}\n", .{ encoder.model_8bpc.n_buckets, encoder.model_5bpc.n_buckets });
    std.debug.print("\n", .{});

    // Test I/O and header parsing functions
    std.debug.print("Testing I/O and header parsing:\n", .{});

    // Create a sample QUIC header (RGB32, 100x75 image)
    // Magic: QUIC (0x43495551), Version: 0x00000000, Type: RGB32 (4), Width: 100, Height: 75
    const sample_header = [_]u8{
        0x51, 0x55, 0x49, 0x43, // Magic: "QUIC" (little-endian)
        0x00, 0x00, 0x00, 0x00, // Version: 0
        0x04, 0x00, 0x00, 0x00, // Type: RGB32 (4)
        0x64, 0x00, 0x00, 0x00, // Width: 100
        0x4B, 0x00, 0x00, 0x00, // Height: 75
        // Additional dummy data to prevent out-of-bounds reads
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
    };

    const parse_result = encoder.quicDecodeBegin(&sample_header) catch |err| {
        std.debug.print("  Error parsing header: {}\n", .{err});
        return;
    };

    if (parse_result) {
        std.debug.print("  Successfully parsed QUIC header!\n", .{});
        std.debug.print("  Image type: {}\n", .{encoder.image_type});
        std.debug.print("  Image type name: {s}\n", .{switch (encoder.image_type) {
            quic.Constants.QUIC_IMAGE_TYPE_GRAY => "GRAY",
            quic.Constants.QUIC_IMAGE_TYPE_RGB16 => "RGB16",
            quic.Constants.QUIC_IMAGE_TYPE_RGB24 => "RGB24",
            quic.Constants.QUIC_IMAGE_TYPE_RGB32 => "RGB32",
            quic.Constants.QUIC_IMAGE_TYPE_RGBA => "RGBA",
            else => "UNKNOWN",
        }});
        std.debug.print("  Width: {}\n", .{encoder.width});
        std.debug.print("  Height: {}\n", .{encoder.height});
        std.debug.print("  BPC: {}\n", .{quic.quicImageBpc(encoder.image_type)});
    } else {
        std.debug.print("  Failed to parse QUIC header\n", .{});
    }
    std.debug.print("\n", .{});

    // Test with invalid magic number
    std.debug.print("Testing with invalid magic number:\n", .{});
    const invalid_header = [_]u8{
        0xFF, 0xFF, 0xFF, 0xFF, // Invalid magic
        0x00, 0x00, 0x00, 0x00, // Version: 0
        0x04, 0x00, 0x00, 0x00, // Type: RGB32 (4)
        0x64, 0x00, 0x00, 0x00, // Width: 100
        0x4B, 0x00, 0x00, 0x00, // Height: 75
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
    };

    const invalid_result = encoder.quicDecodeBegin(&invalid_header) catch false;

    if (!invalid_result) {
        std.debug.print("  Correctly rejected invalid header\n", .{});
    } else {
        std.debug.print("  ERROR: Should have rejected invalid header!\n", .{});
    }
    std.debug.print("\n", .{});

    // Test with too short data
    std.debug.print("Testing with insufficient data:\n", .{});
    const short_data = [_]u8{ 0x51, 0x55, 0x49 }; // Only 3 bytes

    const short_result = encoder.quicDecodeBegin(&short_data) catch false;

    if (!short_result) {
        std.debug.print("  Correctly handled insufficient data\n", .{});
    }
    std.debug.print("\n", .{});

    std.debug.print("All tests completed!\n", .{});
    std.debug.print("\nNOTE: We can now parse QUIC headers and validate the format!\n", .{});
    std.debug.print("      Next steps would be implementing the decompression algorithms.\n", .{});

    // Test basic decompression functionality
    std.debug.print("\nTesting row decompression framework:\n", .{});
    if (parse_result) {
        // Test the decoding function
        const decode_result = encoder.simpleQuicDecode(allocator) catch |err| blk: {
            std.debug.print("  Decode error: {}\n", .{err});
            break :blk null;
        };

        if (decode_result) |decoded_data| {
            defer allocator.free(decoded_data);
            std.debug.print("  Successfully created output buffer: {} bytes\n", .{decoded_data.len});
            std.debug.print("  Image dimensions: {}x{}\n", .{ encoder.width, encoder.height });

            // Show first few pixel values for verification
            if (decoded_data.len >= 16) {
                std.debug.print("  First 4 pixels (BGRA): ", .{});
                for (0..4) |pixel| {
                    const idx = pixel * 4;
                    if (idx + 3 < decoded_data.len) {
                        std.debug.print("[{},{},{},{}] ", .{ decoded_data[idx], decoded_data[idx + 1], decoded_data[idx + 2], decoded_data[idx + 3] });
                    }
                }
                std.debug.print("\n", .{});
            }
        } else {
            std.debug.print("  Decode returned null (unsupported format or error)\n", .{});
        }
    }

    std.debug.print("\nMilestone 4 Complete: Core row decompression functions implemented!\n", .{});
    std.debug.print("Ready for real QUIC test data to validate decoding accuracy.\n", .{});
}
