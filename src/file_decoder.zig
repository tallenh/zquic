const std = @import("std");
const quic = @import("quic.zig");
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <input_file.bin> [output_file.ppm]\n", .{args[0]});
        std.debug.print("Decodes a QUIC binary file and saves as PPM image\n", .{});
        return;
    }

    const input_file = args[1];
    const output_file = if (args.len >= 3) args[2] else "decoded_output.ppm";

    std.debug.print("QUIC Binary File Decoder\n", .{});
    std.debug.print("========================\n", .{});
    std.debug.print("Input file: {s}\n", .{input_file});
    std.debug.print("Output file: {s}\n\n", .{output_file});

    // Initialize the QUIC library
    try quic.init();

    // Read the binary file
    const file_data = std.fs.cwd().readFileAlloc(allocator, input_file, 10 * 1024 * 1024) catch |err| {
        std.debug.print("Error reading file '{s}': {}\n", .{ input_file, err });
        return;
    };
    defer allocator.free(file_data);

    std.debug.print("File size: {} bytes\n", .{file_data.len});

    // Create decoder
    var decoder = try quic.QuicEncoder.init(allocator);
    defer decoder.deinit();
    decoder.initChannelPointers();

    // Parse the QUIC header
    const parse_success = decoder.quicDecodeBegin(file_data) catch |err| {
        std.debug.print("❌ Header parse error: {}\n", .{err});
        return;
    };

    if (!parse_success) {
        std.debug.print("❌ Header validation failed\n", .{});
        return;
    }

    const format_name = switch (decoder.image_type) {
        quic.Constants.QUIC_IMAGE_TYPE_GRAY => "GRAY",
        quic.Constants.QUIC_IMAGE_TYPE_RGB16 => "RGB16",
        quic.Constants.QUIC_IMAGE_TYPE_RGB24 => "RGB24",
        quic.Constants.QUIC_IMAGE_TYPE_RGB32 => "RGB32",
        quic.Constants.QUIC_IMAGE_TYPE_RGBA => "RGBA",
        else => "UNKNOWN",
    };

    std.debug.print("✅ Header parsed successfully!\n", .{});
    std.debug.print("   Image type: {} ({s})\n", .{ decoder.image_type, format_name });
    std.debug.print("   Dimensions: {} x {}\n", .{ decoder.width, decoder.height });
    std.debug.print("   BPC: {}\n", .{quic.quicImageBpc(decoder.image_type)});

    // Decode the image
    std.debug.print("\nDecoding image data...\n", .{});
    const decode_result = decoder.simpleQuicDecode(allocator) catch |err| {
        std.debug.print("❌ Decode error: {}\n", .{err});
        return;
    };

    if (decode_result) |decoded_data| {
        defer allocator.free(decoded_data);
        std.debug.print("✅ Decode completed! Buffer size: {} bytes\n", .{decoded_data.len});

        // Save as PPM file
        try savePpm(allocator, output_file, decoded_data, decoder.width, decoder.height, decoder.image_type);

        // Also save raw binary data for inspection
        const raw_output_file = try std.fmt.allocPrint(allocator, "{s}.raw", .{output_file});
        defer allocator.free(raw_output_file);

        try std.fs.cwd().writeFile(.{ .sub_path = raw_output_file, .data = decoded_data });
        std.debug.print("✅ Raw data saved to: {s}\n", .{raw_output_file});

        // Show some pixel statistics
        try showPixelStats(decoded_data, decoder.width, decoder.height, decoder.image_type);
    } else {
        std.debug.print("❌ Decode returned null - no data decoded\n", .{});
    }
}

fn savePpm(_: Allocator, filename: []const u8, data: []const u8, width: u32, height: u32, image_type: u32) !void {
    const file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();

    const writer = file.writer();

    // Write PPM header
    try writer.print("P6\n{} {}\n255\n", .{ width, height });

    const bytes_per_pixel: u32 = switch (image_type) {
        quic.Constants.QUIC_IMAGE_TYPE_RGB24 => 3,
        quic.Constants.QUIC_IMAGE_TYPE_RGB32, quic.Constants.QUIC_IMAGE_TYPE_RGBA => 4,
        else => 3, // Default to 3 for other formats
    };

    // Convert pixel data to RGB format for PPM
    var row: u32 = 0;
    while (row < height) : (row += 1) {
        var col: u32 = 0;
        while (col < width) : (col += 1) {
            const pixel_index = (row * width + col) * bytes_per_pixel;

            if (pixel_index + 2 < data.len) {
                // QUIC data is usually stored as BGR, so we need to swap to RGB for PPM
                const b = data[pixel_index];
                const g = data[pixel_index + 1];
                const r = data[pixel_index + 2];

                try writer.writeByte(r); // Red
                try writer.writeByte(g); // Green
                try writer.writeByte(b); // Blue
            } else {
                // Fill with black if we run out of data
                try writer.writeByte(0);
                try writer.writeByte(0);
                try writer.writeByte(0);
            }
        }
    }

    std.debug.print("✅ PPM file saved to: {s}\n", .{filename});
}

fn showPixelStats(data: []const u8, width: u32, height: u32, image_type: u32) !void {
    const bytes_per_pixel: u32 = switch (image_type) {
        quic.Constants.QUIC_IMAGE_TYPE_RGB24 => 3,
        quic.Constants.QUIC_IMAGE_TYPE_RGB32, quic.Constants.QUIC_IMAGE_TYPE_RGBA => 4,
        else => 3,
    };

    std.debug.print("\n📊 Pixel Statistics:\n", .{});
    std.debug.print("   Expected pixels: {}\n", .{width * height});
    std.debug.print("   Expected bytes: {}\n", .{width * height * bytes_per_pixel});
    std.debug.print("   Actual bytes: {}\n", .{data.len});

    if (data.len >= bytes_per_pixel) {
        std.debug.print("\n🎨 First 10 pixels (BGR format):\n", .{});
        const max_pixels = @min(10, data.len / bytes_per_pixel);

        for (0..max_pixels) |i| {
            const pixel_index = i * bytes_per_pixel;
            const b = data[pixel_index];
            const g = data[pixel_index + 1];
            const r = data[pixel_index + 2];
            std.debug.print("   Pixel {}: BGR({}, {}, {}) -> RGB({}, {}, {})\n", .{ i, b, g, r, r, g, b });
        }
    }

    // Check if image appears to be mostly solid color
    if (data.len >= bytes_per_pixel * 100) { // Only if we have at least 100 pixels
        const first_pixel = data[0..bytes_per_pixel];
        var similar_count: u32 = 0;

        var i: usize = 0;
        while (i < data.len - bytes_per_pixel + 1) : (i += bytes_per_pixel) {
            const pixel = data[i .. i + bytes_per_pixel];
            if (std.mem.eql(u8, first_pixel, pixel)) {
                similar_count += 1;
            }
        }

        const total_pixels = data.len / bytes_per_pixel;
        const similarity_percent = (similar_count * 100) / total_pixels;

        std.debug.print("\n🔍 Image Analysis:\n", .{});
        std.debug.print("   Pixels matching first pixel: {} / {} ({}%)\n", .{ similar_count, total_pixels, similarity_percent });

        if (similarity_percent > 90) {
            std.debug.print("   🎯 Image appears to be mostly solid color\n", .{});
        } else if (similarity_percent > 50) {
            std.debug.print("   🎨 Image has some repeated patterns\n", .{});
        } else {
            std.debug.print("   🌈 Image appears to have varied content\n", .{});
        }
    }
}
