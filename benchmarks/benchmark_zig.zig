const std = @import("std");
const quic = @import("quic");

const BenchmarkResults = struct {
    implementation: []const u8,
    iterations: u32,
    file_size: u32,
    output_size: u32,
    image_width: u32,
    image_height: u32,
    image_type: u32,
    times: struct {
        min: u64,
        max: u64,
        median: u64,
        average: u64,
    },
    throughput_mbps: f64,
};

fn benchmarkDecode(allocator: std.mem.Allocator, filename: []const u8, iterations: u32) !void {
    std.debug.print("Zig Benchmark: {s}\n", .{filename});
    std.debug.print("Iterations: {}\n", .{iterations});
    
    // Read the binary file
    const binary_data = try std.fs.cwd().readFileAlloc(allocator, filename, 100 * 1024 * 1024);
    defer allocator.free(binary_data);
    
    std.debug.print("File size: {} bytes\n", .{binary_data.len});
    
    // Initialize QUIC
    try quic.init();
    
    // Create decoder
    var decoder = try quic.QuicEncoder.init(allocator);
    defer decoder.deinit();
    decoder.initChannelPointers();
    
    // Parse header once to get image info
    const parse_success = try decoder.quicDecodeBegin(binary_data);
    if (!parse_success) {
        std.debug.print("Failed to parse QUIC header\n", .{});
        return;
    }
    
    std.debug.print("Image: {}x{}, type: {}\n", .{decoder.width, decoder.height, decoder.image_type});
    
    // Warm up runs to eliminate any startup overhead
    std.debug.print("Warming up...\n", .{});
    for (0..10) |_| {
        var warm_decoder = try quic.QuicEncoder.init(allocator);
        defer warm_decoder.deinit();
        warm_decoder.initChannelPointers();
        
        _ = try warm_decoder.quicDecodeBegin(binary_data);
        const warm_result = try warm_decoder.simpleQuicDecode(allocator);
        if (warm_result) |data| {
            allocator.free(data);
        } else {
            std.debug.print("Decode failed during warmup\n", .{});
            return;
        }
    }
    
    // Benchmark runs
    std.debug.print("Running benchmark...\n", .{});
    var times = try allocator.alloc(u64, iterations);
    defer allocator.free(times);
    
    var total_bytes: u32 = 0;
    
    for (0..iterations) |i| {
        var bench_decoder = try quic.QuicEncoder.init(allocator);
        defer bench_decoder.deinit();
        bench_decoder.initChannelPointers();
        
        const start_time = std.time.nanoTimestamp();
        
        _ = try bench_decoder.quicDecodeBegin(binary_data);
        const result = try bench_decoder.simpleQuicDecode(allocator);
        
        const end_time = std.time.nanoTimestamp();
        const elapsed_ns = @as(u64, @intCast(end_time - start_time));
        times[i] = elapsed_ns;
        
        if (result) |data| {
            if (i == 0) {
                total_bytes = @intCast(data.len);
                std.debug.print("Output: {} bytes\n", .{data.len});
            }
            allocator.free(data);
        } else {
            std.debug.print("Decode failed on iteration {}\n", .{i});
            return;
        }
    }
    
    // Calculate statistics
    std.mem.sort(u64, times, {}, std.sort.asc(u64));
    
    const min_time = times[0];
    const max_time = times[times.len - 1];
    const median_time = times[times.len / 2];
    
    var sum: u64 = 0;
    for (times) |time| {
        sum += time;
    }
    const avg_time = sum / iterations;
    
    // Convert nanoseconds to milliseconds for readability
    const toMs = struct {
        fn call(ns: u64) f64 {
            return @as(f64, @floatFromInt(ns)) / 1_000_000.0;
        }
    }.call;
    
    std.debug.print("\n=== Zig Results ===\n", .{});
    std.debug.print("Min time:    {d:.3} ms\n", .{toMs(min_time)});
    std.debug.print("Max time:    {d:.3} ms\n", .{toMs(max_time)});
    std.debug.print("Median time: {d:.3} ms\n", .{toMs(median_time)});
    std.debug.print("Avg time:    {d:.3} ms\n", .{toMs(avg_time)});
    
    // Calculate throughput (MB/s)
    const throughput_mbps = (@as(f64, @floatFromInt(total_bytes)) * @as(f64, @floatFromInt(iterations))) / 
                           (@as(f64, @floatFromInt(avg_time)) * @as(f64, @floatFromInt(iterations)) / 1_000_000_000.0) / 
                           (1024.0 * 1024.0);
    std.debug.print("Throughput:  {d:.2} MB/s\n", .{throughput_mbps});
    
    // Results are already printed to console above
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try benchmarkDecode(allocator, "test_data/quic_image_0.bin", 100);
}