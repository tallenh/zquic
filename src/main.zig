const std = @import("std");
const quic = @import("quic");

pub fn main() !void {
    // Initialize the library
    try quic.init();

    std.debug.print("QUIC library initialized successfully!\n", .{});
    std.debug.print("Supported image types:\n", .{});
    std.debug.print("  - GRAY (BPC: {})\n", .{quic.quicImageBpc(quic.Constants.QUIC_IMAGE_TYPE_GRAY)});
    std.debug.print("  - RGB16 (BPC: {})\n", .{quic.quicImageBpc(quic.Constants.QUIC_IMAGE_TYPE_RGB16)});
    std.debug.print("  - RGB24 (BPC: {})\n", .{quic.quicImageBpc(quic.Constants.QUIC_IMAGE_TYPE_RGB24)});
    std.debug.print("  - RGB32 (BPC: {})\n", .{quic.quicImageBpc(quic.Constants.QUIC_IMAGE_TYPE_RGB32)});
    std.debug.print("  - RGBA (BPC: {})\n", .{quic.quicImageBpc(quic.Constants.QUIC_IMAGE_TYPE_RGBA)});

    // Test some basic functions
    std.debug.print("\nTesting ceilLog2 function:\n", .{});
    std.debug.print("  ceilLog2(1) = {}\n", .{quic.ceilLog2(1)});
    std.debug.print("  ceilLog2(2) = {}\n", .{quic.ceilLog2(2)});
    std.debug.print("  ceilLog2(8) = {}\n", .{quic.ceilLog2(8)});
    std.debug.print("  ceilLog2(16) = {}\n", .{quic.ceilLog2(16)});

    std.debug.print("\nTesting cntLZeroes function:\n", .{});
    std.debug.print("  cntLZeroes(0x01) = {}\n", .{quic.cntLZeroes(0x01)});
    std.debug.print("  cntLZeroes(0x80) = {}\n", .{quic.cntLZeroes(0x80)});
    std.debug.print("  cntLZeroes(0xFF) = {}\n", .{quic.cntLZeroes(0xFF)});

    std.debug.print("\nQUIC library port is ready for further development!\n", .{});
}
