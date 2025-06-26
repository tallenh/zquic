const std = @import("std");

// Optimized packed pixel structures for better memory layout and cache utilization
// These structures match the C implementation's memory layout

// RGB32 pixel - 4 bytes packed
pub const RGB32Pixel = packed struct {
    b: u8,
    g: u8,
    r: u8,
    pad: u8,

    pub inline fn fromBytes(bytes: *const [4]u8) RGB32Pixel {
        return @bitCast(bytes.*);
    }

    pub inline fn toBytes(self: RGB32Pixel) [4]u8 {
        return @bitCast(self);
    }

    pub inline fn fromComponents(r: u8, g: u8, b: u8) RGB32Pixel {
        return RGB32Pixel{ .r = r, .g = g, .b = b, .pad = 0 };
    }
};

// RGB24 pixel - 3 bytes packed
pub const RGB24Pixel = packed struct {
    b: u8,
    g: u8,
    r: u8,

    pub inline fn fromBytes(bytes: *const [3]u8) RGB24Pixel {
        return @bitCast(bytes.*);
    }

    pub inline fn toBytes(self: RGB24Pixel) [3]u8 {
        return @bitCast(self);
    }

    pub inline fn fromComponents(r: u8, g: u8, b: u8) RGB24Pixel {
        return RGB24Pixel{ .r = r, .g = g, .b = b };
    }
};

// RGBA pixel - 4 bytes packed
pub const RGBAPixel = packed struct {
    b: u8,
    g: u8,
    r: u8,
    a: u8,

    pub inline fn fromBytes(bytes: *const [4]u8) RGBAPixel {
        return @bitCast(bytes.*);
    }

    pub inline fn toBytes(self: RGBAPixel) [4]u8 {
        return @bitCast(self);
    }
};

// Gray pixel - 1 byte
pub const GrayPixel = packed struct {
    value: u8,

    pub inline fn fromByte(byte: u8) GrayPixel {
        return GrayPixel{ .value = byte };
    }

    pub inline fn toByte(self: GrayPixel) u8 {
        return self.value;
    }
};

// Helper functions for pixel manipulation
pub inline fn packRGB32(r: u8, g: u8, b: u8) u32 {
    return (@as(u32, b) << 0) | (@as(u32, g) << 8) | (@as(u32, r) << 16);
}

pub inline fn packRGB24(r: u8, g: u8, b: u8) u24 {
    return (@as(u24, b) << 0) | (@as(u24, g) << 8) | (@as(u24, r) << 16);
}

// Vectorized pixel operations for SIMD optimization
pub const PixelVector = struct {
    // Process 4 RGB32 pixels at once (16 bytes)
    pub inline fn processRGB32x4(pixels: *[4]RGB32Pixel) @Vector(16, u8) {
        const bytes = @as(*const [16]u8, @ptrCast(pixels));
        return bytes.*;
    }

    // Process 4 RGB24 pixels at once (12 bytes)
    pub inline fn processRGB24x4(pixels: *[4]RGB24Pixel) @Vector(12, u8) {
        const bytes = @as(*const [12]u8, @ptrCast(pixels));
        return bytes.*;
    }
};

// Optimized pixel copy functions
pub inline fn copyRGB32Pixels(dst: [*]RGB32Pixel, src: [*]const RGB32Pixel, count: usize) void {
    @memcpy(@as([*]u8, @ptrCast(dst))[0..count * 4], @as([*]const u8, @ptrCast(src))[0..count * 4]);
}

pub inline fn copyRGB24Pixels(dst: [*]RGB24Pixel, src: [*]const RGB24Pixel, count: usize) void {
    @memcpy(@as([*]u8, @ptrCast(dst))[0..count * 3], @as([*]const u8, @ptrCast(src))[0..count * 3]);
}