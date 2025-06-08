const std = @import("std");
const quic = @import("quic");

pub fn main() !void {
    try quic.init();

    const iterations = 1000000;

    // Benchmark ceilLog2
    const start_time = std.time.nanoTimestamp();

    var sum: u32 = 0;
    for (0..iterations) |i| {
        sum += quic.ceilLog2(@intCast(i % 1000 + 1));
    }

    const end_time = std.time.nanoTimestamp();
    const duration = end_time - start_time;

    std.debug.print("Benchmark Results:\n", .{});
    std.debug.print("ceilLog2 {} iterations: {} ns ({} ns/iteration)\n", .{ iterations, duration, @divTrunc(duration, iterations) });
    std.debug.print("Sum (to prevent optimization): {}\n", .{sum});

    // Benchmark cntLZeroes
    const start_time2 = std.time.nanoTimestamp();

    var sum2: u32 = 0;
    for (0..iterations) |i| {
        sum2 += quic.cntLZeroes(@intCast(i % 256));
    }

    const end_time2 = std.time.nanoTimestamp();
    const duration2 = end_time2 - start_time2;

    std.debug.print("cntLZeroes {} iterations: {} ns ({} ns/iteration)\n", .{ iterations, duration2, @divTrunc(duration2, iterations) });
    std.debug.print("Sum (to prevent optimization): {}\n", .{sum2});
}
