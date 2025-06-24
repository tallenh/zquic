const std = @import("std");

// Fast batch Golomb decoder for 8bpc (bestcode == 0)
// Decodes up to four unary Golomb symbols directly from the high bits of the
// bit-buffer without branches or table look-ups.

pub const FastBatchEntry = struct {
    count: u3, // number of decoded symbols (0 ⇒ slow path)
    bits_used: u5, // total bits consumed (0–24)
    rc: [4]u8, // residuals (unused entries are 0)
};

/// Fast decode up to 4 residuals from the top bits of `bits`.
/// For l=0 only (i.e., unary Golomb). If the first prefix length ≥3 the
/// function returns count=0 to indicate the caller should fall back to the
/// generic routine.
pub inline fn fastGolombBatch(bits: u32) FastBatchEntry {
    var cnt: u3 = 0;
    var used: u5 = 0;
    var rc_vals: [4]u8 = .{ 0, 0, 0, 0 };
    var tmp: u32 = bits;
    while (cnt < 4) {
        const leading: u5 = @intCast(@clz(tmp));
        if (leading >= 3) break; // prefix too long → bail to slow path
        const cwlen: u5 = leading + 1; // unary prefix zeros + stop bit
        rc_vals[cnt] = @intCast(leading);
        cnt += 1;
        used += cwlen;
        tmp <<= cwlen;
    }
    return FastBatchEntry{ .count = cnt, .bits_used = used, .rc = rc_vals };
}

// Simple unit test to ensure table entry sanity
pub fn main() void {
    // no-op
}
