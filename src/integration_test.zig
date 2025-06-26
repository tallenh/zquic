const std = @import("std");
const testing = std.testing;
const quic = @import("quic.zig");

test "decoder produces identical output to JavaScript reference" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize QUIC library
    try quic.init();

    // Read the test data file
    const test_data = std.fs.cwd().readFileAlloc(allocator, "test_data/quic_image_0.bin", 10 * 1024 * 1024) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("⚠️  Test file 'test_data/quic_image_0.bin' not found, skipping integration test\n", .{});
            return;
        },
        else => return err,
    };
    defer allocator.free(test_data);

    // Create and run Zig decoder
    var decoder = try quic.QuicEncoder.init(allocator);
    defer decoder.deinit();
    decoder.initChannelPointers();

    // Parse header
    const parse_success = try decoder.quicDecodeBegin(test_data);
    try testing.expect(parse_success);

    // Decode the image
    const zig_result = try decoder.simpleQuicDecode(allocator);
    defer if (zig_result) |data| allocator.free(data);

    try testing.expect(zig_result != null);
    const zig_data = zig_result.?;

    // Run JavaScript decoder to generate reference
    var js_process = std.process.Child.init(&[_][]const u8{ "node", "test_js.js" }, allocator);
    js_process.stdout_behavior = .Pipe;
    js_process.stderr_behavior = .Pipe;

    try js_process.spawn();

    // Wait for JavaScript process to complete
    const js_result = try js_process.wait();

    if (js_result != .Exited or js_result.Exited != 0) {
        std.debug.print("⚠️  JavaScript reference decoder failed, skipping comparison\n", .{});
        return;
    }

    // Read JavaScript reference output
    const js_data = std.fs.cwd().readFileAlloc(allocator, "reference_output.ppm.raw", 50 * 1024 * 1024) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("⚠️  JavaScript reference output not found, skipping comparison\n", .{});
            return;
        },
        else => return err,
    };
    defer allocator.free(js_data);

    // Compare the outputs byte-by-byte
    std.debug.print("Comparing Zig vs JavaScript output...\n", .{});
    std.debug.print("  Zig output size: {} bytes\n", .{zig_data.len});
    std.debug.print("  JS output size:  {} bytes\n", .{js_data.len});

    // Check sizes match
    try testing.expectEqual(js_data.len, zig_data.len);

    // Check content matches
    var differences: u32 = 0;
    var first_diff_pos: ?usize = null;

    for (zig_data, js_data, 0..) |zig_byte, js_byte, i| {
        if (zig_byte != js_byte) {
            differences += 1;
            if (first_diff_pos == null) {
                first_diff_pos = i;
                std.debug.print("  First difference at byte {}: Zig=0x{X:02}, JS=0x{X:02}\n", .{ i, zig_byte, js_byte });
            }
        }
    }

    if (differences == 0) {
        std.debug.print("✅ Perfect match! Outputs are identical ({} bytes)\n", .{zig_data.len});
    } else {
        std.debug.print("❌ Found {} differences out of {} bytes\n", .{ differences, zig_data.len });
        const accuracy = ((zig_data.len - differences) * 100) / zig_data.len;
        std.debug.print("   Accuracy: {}%\n", .{accuracy});
    }

    // Cleanup reference output file
    std.fs.cwd().deleteFile("reference_output.ppm.raw") catch {};
    
    // Assert perfect match
    try testing.expectEqual(@as(u32, 0), differences);
}

test "decoder handles invalid input gracefully" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try quic.init();

    var decoder = try quic.QuicEncoder.init(allocator);
    defer decoder.deinit();
    decoder.initChannelPointers();

    // Test with empty data
    const empty_data: []const u8 = "";
    if (decoder.quicDecodeBegin(empty_data)) |result| {
        try testing.expect(!result); // Should return false for invalid data
    } else |_| {
        // Error is expected for empty data
    }

    // Test with invalid header data
    const invalid_data = [_]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF };
    if (decoder.quicDecodeBegin(&invalid_data)) |result| {
        try testing.expect(!result); // Should return false for invalid data
    } else |_| {
        // Error is expected for invalid data
    }
}

test "decoder preserves image dimensions and format" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try quic.init();

    // Read test data if available
    const test_data = std.fs.cwd().readFileAlloc(allocator, "test_data/quic_image_0.bin", 10 * 1024 * 1024) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("⚠️  Test file 'test_data/quic_image_0.bin' not found, skipping dimension test\n", .{});
            return;
        },
        else => return err,
    };
    defer allocator.free(test_data);

    var decoder = try quic.QuicEncoder.init(allocator);
    defer decoder.deinit();
    decoder.initChannelPointers();

    // Parse header and check expected dimensions
    const parse_success = try decoder.quicDecodeBegin(test_data);
    try testing.expect(parse_success);

    // Expected values for our test file (quic_image_0.bin)
    try testing.expectEqual(@as(u32, 2048), decoder.width);
    try testing.expectEqual(@as(u32, 1152), decoder.height);

    // The test file quic_image_0.bin is RGB32
    try testing.expectEqual(quic.Constants.QUIC_IMAGE_TYPE_RGB32, decoder.image_type);

    const decoded_data = try decoder.simpleQuicDecode(allocator);
    defer if (decoded_data) |data| allocator.free(data);

    try testing.expect(decoded_data != null);

    // Check output size matches expected pixel count
    const bytes_per_pixel: u32 = switch (decoder.image_type) {
        quic.Constants.QUIC_IMAGE_TYPE_RGB24 => 3,
        quic.Constants.QUIC_IMAGE_TYPE_RGB32, quic.Constants.QUIC_IMAGE_TYPE_RGBA => 4,
        else => 3, // Default fallback
    };
    const expected_bytes = decoder.width * decoder.height * bytes_per_pixel;
    try testing.expectEqual(expected_bytes, decoded_data.?.len);
}
