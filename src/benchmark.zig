const std = @import("std");
const quic = @import("quic.zig");

const BENCHMARK_ITERATIONS = 100;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("🚀 QUIC Decoder Benchmark\n", .{});
    std.debug.print("========================\n\n", .{});

    // Initialize QUIC library
    try quic.init();

    // Load test data
    const test_data = std.fs.cwd().readFileAlloc(allocator, "quic_data.bin", 10 * 1024 * 1024) catch |err| {
        std.debug.print("❌ Error: Could not load quic_data.bin: {}\n", .{err});
        std.debug.print("   Make sure you have the test file in the current directory.\n", .{});
        return;
    };
    defer allocator.free(test_data);

    std.debug.print("📄 Test file: {} bytes\n", .{test_data.len});

    // Single decode to get image info and verify functionality
    std.debug.print("\n🔍 Single decode test...\n", .{});

    var test_decoder = try quic.QuicEncoder.init(allocator);
    defer test_decoder.deinit();
    test_decoder.initChannelPointers();

    const parse_success = try test_decoder.quicDecodeBegin(test_data);
    if (!parse_success) {
        std.debug.print("❌ Error: Failed to parse QUIC header\n", .{});
        return;
    }

    const test_result = try test_decoder.simpleQuicDecode(allocator);
    if (test_result) |decoded_data| {
        defer allocator.free(decoded_data);

        std.debug.print("✅ Image: {}x{} (type {})\n", .{ test_decoder.width, test_decoder.height, test_decoder.image_type });
        std.debug.print("✅ Output: {} bytes\n", .{decoded_data.len});

        const pixel_count = test_decoder.width * test_decoder.height;
        const bytes_per_pixel = decoded_data.len / pixel_count;
        std.debug.print("✅ Format: {} bytes per pixel\n", .{bytes_per_pixel});
    } else {
        std.debug.print("❌ Error: Decode returned null\n", .{});
        return;
    }

    std.debug.print("\n⏱️  Running {} decode iterations...\n", .{BENCHMARK_ITERATIONS});

    // Benchmark: Multiple iterations with timing
    var total_decode_time: u64 = 0;
    var total_parse_time: u64 = 0;
    var total_output_bytes: u64 = 0;
    var successful_decodes: u32 = 0;

    for (0..BENCHMARK_ITERATIONS) |i| {
        // Create fresh decoder for each iteration
        var decoder = try quic.QuicEncoder.init(allocator);
        defer decoder.deinit();
        decoder.initChannelPointers();

        // Measure parse time
        const parse_start = std.time.nanoTimestamp();
        const parse_ok = try decoder.quicDecodeBegin(test_data);
        const parse_end = std.time.nanoTimestamp();
        total_parse_time += @intCast(parse_end - parse_start);

        if (!parse_ok) {
            std.debug.print("❌ Parse failed on iteration {}\n", .{i});
            continue;
        }

        // Measure decode time
        const decode_start = std.time.nanoTimestamp();
        const result = try decoder.simpleQuicDecode(allocator);
        const decode_end = std.time.nanoTimestamp();
        total_decode_time += @intCast(decode_end - decode_start);

        if (result) |decoded_data| {
            defer allocator.free(decoded_data);
            total_output_bytes += decoded_data.len;
            successful_decodes += 1;
        }

        // Progress indicator
        if (i % 10 == 0 and i > 0) {
            std.debug.print("  Completed {} iterations...\n", .{i});
        }
    }

    // Calculate and display results
    if (successful_decodes == 0) {
        std.debug.print("❌ No successful decodes!\n", .{});
        return;
    }

    std.debug.print("\n📊 Benchmark Results\n", .{});
    std.debug.print("==================\n", .{});
    std.debug.print("Successful decodes: {}/{}\n", .{ successful_decodes, BENCHMARK_ITERATIONS });

    const avg_parse_time_ns = total_parse_time / successful_decodes;
    const avg_decode_time_ns = total_decode_time / successful_decodes;
    const avg_total_time_ns = avg_parse_time_ns + avg_decode_time_ns;

    std.debug.print("\n⏱️  Average Timing:\n", .{});
    std.debug.print("  Parse time:  {:.3} ms\n", .{@as(f64, @floatFromInt(avg_parse_time_ns)) / 1_000_000.0});
    std.debug.print("  Decode time: {:.3} ms\n", .{@as(f64, @floatFromInt(avg_decode_time_ns)) / 1_000_000.0});
    std.debug.print("  Total time:  {:.3} ms\n", .{@as(f64, @floatFromInt(avg_total_time_ns)) / 1_000_000.0});

    // Performance metrics
    const avg_output_bytes = total_output_bytes / successful_decodes;
    const throughput_mbps = (@as(f64, @floatFromInt(avg_output_bytes)) / @as(f64, @floatFromInt(avg_decode_time_ns))) * 1000.0;
    const frames_per_second = 1_000_000_000.0 / @as(f64, @floatFromInt(avg_total_time_ns));

    std.debug.print("\n🚀 Performance Metrics:\n", .{});
    std.debug.print("  Throughput:  {:.1} MB/s\n", .{throughput_mbps});
    std.debug.print("  Frame rate:  {:.1} FPS\n", .{frames_per_second});

    // Calculate pixel processing rate
    const pixel_count = test_decoder.width * test_decoder.height;
    const pixels_per_second = @as(f64, @floatFromInt(pixel_count)) * frames_per_second;
    std.debug.print("  Pixel rate:  {:.1} Mpixels/s\n", .{pixels_per_second / 1_000_000.0});

    // Memory usage estimate
    std.debug.print("\n💾 Memory Usage:\n", .{});
    std.debug.print("  Output per frame: {} KB\n", .{avg_output_bytes / 1024});
    std.debug.print("  Decoder overhead: {} bytes\n", .{@sizeOf(quic.QuicEncoder)});

    std.debug.print("\n✅ Benchmark complete!\n", .{});
    std.debug.print("💡 Save these numbers before optimizing!\n", .{});
}
