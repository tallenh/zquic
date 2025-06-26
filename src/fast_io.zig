const std = @import("std");
const builtin = @import("builtin");

// Optimized I/O handling for 32-bit word operations
// Matches C implementation's efficiency

pub const FastIOWord = struct {
    // Current 32-bit word being processed
    word: u32,
    // Number of available bits in current word
    available_bits: u32,
    // Buffer position as 32-bit words
    word_pos: usize,
    // Word buffer
    words: []const u32,

    const native_endian = builtin.target.cpu.arch.endian();

    pub fn init(buffer: []const u8) FastIOWord {
        // Convert byte buffer to word buffer
        const word_count = buffer.len / 4;
        const words = @as([*]const u32, @ptrCast(@alignCast(buffer.ptr)))[0..word_count];
        
        return FastIOWord{
            .word = 0,
            .available_bits = 0,
            .word_pos = 0,
            .words = words,
        };
    }

    // Read next 32-bit word with platform-optimized endianness conversion
    pub inline fn readNextWord(self: *FastIOWord) !void {
        @setRuntimeSafety(false);
        
        if (self.word_pos >= self.words.len) {
            return error.EndOfStream;
        }
        
        // Direct word read with endianness handling - QUIC uses little-endian
        const raw_word = self.words[self.word_pos];
        self.word = raw_word; // QUIC data is already in little-endian format
            
        self.word_pos += 1;
        self.available_bits = 32;
    }

    // Consume bits from current word
    pub inline fn eatBits(self: *FastIOWord, bits: u5) !void {
        @setRuntimeSafety(false);
        
        if (bits > self.available_bits) {
            // Need to read next word
            const remaining_bits = bits - @as(u5, @intCast(self.available_bits));
            self.word <<= @intCast(self.available_bits);
            try self.readNextWord();
            self.word <<= remaining_bits;
            self.available_bits = 32 - @as(u32, remaining_bits);
        } else {
            self.word <<= bits;
            self.available_bits -= bits;
        }
    }

    // Get bits without consuming
    pub inline fn peekBits(self: *FastIOWord, bits: u5) u32 {
        @setRuntimeSafety(false);
        return self.word >> @intCast(32 - bits);
    }

    // Combined peek and eat for common pattern
    pub inline fn getBits(self: *FastIOWord, bits: u5) !u32 {
        @setRuntimeSafety(false);
        const value = self.peekBits(bits);
        try self.eatBits(bits);
        return value;
    }
};

// Batch I/O operations for better throughput
pub const BatchIO = struct {
    const native_endian = builtin.target.cpu.arch.endian();
    
    // Process multiple words at once
    pub inline fn readWords(dst: []u32, src: []const u8) void {
        @setRuntimeSafety(false);
        
        const word_count = @min(dst.len, src.len / 4);
        const src_words = @as([*]const u32, @ptrCast(@alignCast(src.ptr)))[0..word_count];
        
        if (native_endian == .little) {
            @memcpy(dst[0..word_count], src_words);
        } else {
            for (0..word_count) |i| {
                dst[i] = @byteSwap(src_words[i]);
            }
        }
    }

    // Write multiple words at once
    pub inline fn writeWords(dst: []u8, src: []const u32) void {
        @setRuntimeSafety(false);
        
        const word_count = @min(src.len, dst.len / 4);
        const dst_words = @as([*]u32, @ptrCast(@alignCast(dst.ptr)))[0..word_count];
        
        if (native_endian == .little) {
            @memcpy(dst_words, src[0..word_count]);
        } else {
            for (0..word_count) |i| {
                dst_words[i] = @byteSwap(src[i]);
            }
        }
    }
};

// Aligned buffer utilities
pub fn alignedAlloc(allocator: std.mem.Allocator, comptime T: type, count: usize) ![]align(64) T {
    return try allocator.alignedAlloc(T, 64, count);
}

pub fn ensureAlignment(buffer: []u8) []align(8) u8 {
    const aligned_ptr: [*]align(8) u8 = @alignCast(@ptrCast(buffer.ptr));
    return aligned_ptr[0..buffer.len];
}