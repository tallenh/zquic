const std = @import("std");

// Optimized Golomb decoding with lookup tables
// This provides faster decoding for common cases

// Result type for Golomb decoding
pub const GolombResult = struct {
    rc: u32,
    codewordlen: u32,
};

pub const GolombTables = struct {
    // Lookup table for fast Golomb code length calculation
    // Index by first 8 bits of input, gives length for common codes
    pub const len_lut: [256]u8 = init: {
        var table: [256]u8 = undefined;
        for (0..256) |i| {
            // Count leading zeros in byte
            var val = @as(u8, @intCast(i));
            var len: u8 = 0;
            while (val < 128 and len < 8) : (val <<= 1) {
                len += 1;
            }
            table[i] = len;
        }
        break :init table;
    };

    // Fast Golomb decoding for 8bpc with lookup optimization
    pub inline fn golombDecode8bpcFast(n_bits: u32, word: u32) GolombResult {
        @setRuntimeSafety(false);
        
        // Fast path for common small values
        const first_byte = @as(u8, @intCast(word >> 24));
        if (first_byte >= 128) {
            // Most common case: single bit prefix
            const shift_amount: u5 = @intCast(32 - n_bits - 1);
            const mask = (@as(u32, 1) << @intCast(n_bits)) - 1;
            const val = (word >> shift_amount) & mask;
            return .{ .rc = val, .codewordlen = n_bits + 1 };
        }
        
        // Use lookup table for prefix length
        const prefix_len = len_lut[first_byte];
        
        if (prefix_len > n_bits) {
            // Long prefix - use standard decoding
            return golombDecode8bpcStandard(n_bits, word);
        }
        
        const suffix_len = n_bits - prefix_len;
        const suffix_mask = (@as(u32, 1) << @intCast(suffix_len)) - 1;
        const shift_amount2: u5 = @intCast(32 - prefix_len - suffix_len - 1);
        const suffix = (word >> shift_amount2) & suffix_mask;
        
        const rc = (prefix_len << @intCast(suffix_len)) | suffix;
        const codewordlen = prefix_len + suffix_len + 1;
        
        return .{ .rc = rc, .codewordlen = codewordlen };
    }

    // Standard Golomb decoding for edge cases
    fn golombDecode8bpcStandard(n_bits: u32, word: u32) GolombResult {
        @setRuntimeSafety(false);
        
        // Count leading zeros using @clz
        const leading_zeros = @clz(word);
        
        if (leading_zeros > n_bits) {
            // Overflow case
            const codewordlen = n_bits + 1;
            const rc = word >> @intCast(32 - codewordlen);
            return .{ .rc = rc, .codewordlen = codewordlen };
        }
        
        const suffix_len = n_bits - leading_zeros;
        const suffix_mask = (@as(u32, 1) << @intCast(suffix_len)) - 1;
        const shift_amount3: u5 = @intCast(32 - leading_zeros - suffix_len - 1);
        const suffix = (word >> shift_amount3) & suffix_mask;
        
        const rc = (leading_zeros << @intCast(suffix_len)) | suffix;
        const codewordlen = leading_zeros + suffix_len + 1;
        
        return .{ .rc = rc, .codewordlen = codewordlen };
    }

    // Batch Golomb decoding for multiple values
    pub fn golombDecodeBatch(comptime count: u32, n_bits: u32, words: [count]u32) [count]GolombResult {
        var results: [count]GolombResult = undefined;
        
        // Unroll for better performance
        inline for (0..count) |i| {
            results[i] = golombDecode8bpcFast(n_bits, words[i]);
        }
        
        return results;
    }
};

// Helper function to integrate with existing code
pub inline fn golombDecoding8bpcOptimized(n_bits: u32, word: u32) GolombResult {
    return GolombTables.golombDecode8bpcFast(n_bits, word);
}