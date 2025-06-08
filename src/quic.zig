const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

// Constants from the original JavaScript
pub const Constants = struct {
    pub const QUIC_IMAGE_TYPE_INVALID: u32 = 0;
    pub const QUIC_IMAGE_TYPE_GRAY: u32 = 1;
    pub const QUIC_IMAGE_TYPE_RGB16: u32 = 2;
    pub const QUIC_IMAGE_TYPE_RGB24: u32 = 3;
    pub const QUIC_IMAGE_TYPE_RGB32: u32 = 4;
    pub const QUIC_IMAGE_TYPE_RGBA: u32 = 5;
};

// Default values from the JavaScript
const DEF_EVOL: u32 = 3;
const DEF_WMI_MAX: u32 = 6;
const DEF_WMI_NEXT: u32 = 2048;
const DEF_MAX_CLEN: u32 = 26;

// Family structure for encoding/decoding
const Family = struct {
    n_gr_codewords: [8]u32,
    not_gr_cwlen: [8]u32,
    not_gr_prefix_mask: [8]u32,
    not_gr_suffix_len: [8]u32,
    xlat_u2l: [256]u32, // Extended to handle 8-bit values
    xlat_l2u: [256]u32, // Extended to handle 8-bit values
};

// Global lookup tables (translated from JavaScript arrays)
var family_5bpc: Family = undefined;
var family_8bpc: Family = undefined;

// Bit mask lookup table (bppmask from JavaScript)
const BPP_MASK = [33]u32{
    0x00000000, 0x00000001, 0x00000003, 0x00000007, 0x0000000f,
    0x0000001f, 0x0000003f, 0x0000007f, 0x000000ff, 0x000001ff,
    0x000003ff, 0x000007ff, 0x00000fff, 0x00001fff, 0x00003fff,
    0x00007fff, 0x0000ffff, 0x0001ffff, 0x0003ffff, 0x0007ffff,
    0x000fffff, 0x001fffff, 0x003fffff, 0x007fffff, 0x00ffffff,
    0x01ffffff, 0x03ffffff, 0x07ffffff, 0x0fffffff, 0x1fffffff,
    0x3fffffff, 0x7fffffff, 0xffffffff,
};

// Leading zeros lookup table (lzeroes from JavaScript)
const L_ZEROES = [256]u8{
    8, 7, 6, 6, 5, 5, 5, 5, 4, 4, 4, 4, 4, 4, 4, 4, 3, 3, 3, 3, 3, 3, 3, 3, 3,
    3, 3, 3, 3, 3, 3, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0,
};

// J array from JavaScript
const J = [32]u8{
    0, 0, 0, 0, 1,  1,  1,  1,  2,  2,  2, 2, 3, 3, 3, 3, 4, 4, 5, 5, 6, 6,
    7, 7, 8, 9, 10, 11, 12, 13, 14, 15,
};

// Random number table for chaos (tabrand_chaos from JavaScript)
const TABRAND_CHAOS = [256]u32{
    0x02c57542, 0x35427717, 0x2f5a2153, 0x9244f155, 0x7bd26d07, 0x354c6052,
    0x57329b28, 0x2993868e, 0x6cd8808c, 0x147b46e0, 0x99db66af, 0xe32b4cac,
    0x1b671264, 0x9d433486, 0x62a4c192, 0x06089a4b, 0x9e3dce44, 0xdaabee13,
    0x222425ea, 0xa46f331d, 0xcd589250, 0x8bb81d7f, 0xc8b736b9, 0x35948d33,
    0xd7ac7fd0, 0x5fbe2803, 0x2cfbc105, 0x013dbc4e, 0x7a37820f, 0x39f88e9e,
    0xedd58794, 0xc5076689, 0xfcada5a4, 0x64c2f46d, 0xb3ba3243, 0x8974b4f9,
    0x5a05aebd, 0x20afcd00, 0x39e2b008, 0x88a18a45, 0x600bde29, 0xf3971ace,
    0xf37b0a6b, 0x7041495b, 0x70b707ab, 0x06beffbb, 0x4206051f, 0xe13c4ee3,
    0xc1a78327, 0x91aa067c, 0x8295f72a, 0x732917a6, 0x1d871b4d, 0x4048f136,
    0xf1840e7e, 0x6a6048c1, 0x696cb71a, 0x7ff501c3, 0x0fc6310b, 0x57e0f83d,
    0x8cc26e74, 0x11a525a2, 0x946934c7, 0x7cd888f0, 0x8f9d8604, 0x4f86e73b,
    0x04520316, 0xdeeea20c, 0xf1def496, 0x67687288, 0xf540c5b2, 0x22401484,
    0x3478658a, 0xc2385746, 0x01979c2c, 0x5dad73c8, 0x0321f58b, 0xf0fedbee,
    0x92826ddf, 0x284bec73, 0x5b1a1975, 0x03df1e11, 0x20963e01, 0xa17cf12b,
    0x740d776e, 0xa7a6bf3c, 0x01b5cce4, 0x1118aa76, 0xfc6fac0a, 0xce927e9b,
    0x00bf2567, 0x806f216c, 0xbca69056, 0x795bd3e9, 0xc9dc4557, 0x8929b6c2,
    0x789d52ec, 0x3f3fbf40, 0xb9197368, 0xa38c15b5, 0xc3b44fa8, 0xca8333b0,
    0xb7e8d590, 0xbe807feb, 0xbf5f8360, 0xd99e2f5c, 0x372928e1, 0x7c757c4c,
    0x0db5b154, 0xc01ede02, 0x1fc86e78, 0x1f3985be, 0xb4805c77, 0x00c880fa,
    0x974c1b12, 0x35ab0214, 0xb2dc840d, 0x5b00ae37, 0xd313b026, 0xb260969d,
    0x7f4c8879, 0x1734c4d3, 0x49068631, 0xb9f6a021, 0x6b863e6f, 0xcee5debf,
    0x29f8c9fb, 0x53dd6880, 0x72b61223, 0x1f67a9fd, 0x0a0f6993, 0x13e59119,
    0x11cca12e, 0xfe6b6766, 0x16b6effc, 0x97918fc4, 0xc2b8a563, 0x94f2f741,
    0x0bfa8c9a, 0xd1537ae8, 0xc1da349c, 0x873c60ca, 0x95005b85, 0x9b5c080e,
    0xbc8abbd9, 0xe1eab1d2, 0x6dac9070, 0x4ea9ebf1, 0xe0cf30d4, 0x1ef5bd7b,
    0xd161043e, 0x5d2fa2e2, 0xff5d3cae, 0x86ed9f87, 0x2aa1daa1, 0xbd731a34,
    0x9e8f4b22, 0xb1c2c67a, 0xc21758c9, 0xa182215d, 0xccb01948, 0x8d168df7,
    0x04238cfe, 0x368c3dbc, 0x0aeadca5, 0xbad21c24, 0x0a71fee5, 0x9fc5d872,
    0x54c152c6, 0xfc329483, 0x6783384a, 0xeddb3e1c, 0x65f90e30, 0x884ad098,
    0xce81675a, 0x4b372f7d, 0x68bf9a39, 0x43445f1e, 0x40f8d8cb, 0x90d5acb6,
    0x4cd07282, 0x349eeb06, 0x0c9d5332, 0x520b24ef, 0x80020447, 0x67976491,
    0x2f931ca3, 0xfe9b0535, 0xfcd30220, 0x61a9e6cc, 0xa487d8d7, 0x3f7c5dd1,
    0x7d0127c5, 0x48f51d15, 0x60dea871, 0xc9a91cb7, 0x58b53bb3, 0x9d5e0b2d,
    0x624a78b4, 0x30dbee1b, 0x9bdf22e7, 0x1df5c299, 0x2d5643a7, 0xf4dd35ff,
    0x03ca8fd6, 0x53b47ed8, 0x6f2c19aa, 0xfeb0c1f4, 0x49e54438, 0x2f2577e6,
    0xbf876969, 0x72440ea9, 0xfa0bafb8, 0x74f5b3a0, 0x7dd357cd, 0x89ce1358,
    0x6ef2cdda, 0x1e7767f3, 0xa6be9fdb, 0x4f5f88f8, 0xba994a3a, 0x08ca6b65,
    0xe0893818, 0x9e00a16a, 0xf42bfc8f, 0x9972eedc, 0x749c8b51, 0x32c05f5e,
    0xd706805f, 0x6bfbb7cf, 0xd9210a10, 0x31a1db97, 0x923a9559, 0x37a7a1f6,
    0x059f8861, 0xca493e62, 0x65157e81, 0x8f6467dd, 0xab85ff9f, 0x9331aff2,
    0x8616b9f5, 0xedbd5695, 0xee7e29b1, 0x313ac44f, 0xb903112f, 0x432ef649,
    0xdc0a36c0, 0x61cf2bba, 0x81474925, 0xa8b6c7ad, 0xee5931de, 0xb2f8158d,
    0x59fb7409, 0x2e3dfaed, 0x9af25a3f, 0xe1fed4d5,
};

// Best trigger table (besttrigtab from JavaScript)
const BEST_TRIG_TAB = [3][11]u32{
    .{ 550, 900, 800, 700, 500, 350, 300, 200, 180, 180, 160 },
    .{ 110, 550, 900, 800, 550, 400, 350, 250, 140, 160, 140 },
    .{ 100, 120, 550, 900, 700, 500, 400, 300, 220, 250, 160 },
};

// RGB32 pixel layout constants
const RGB32_PIXEL_PAD: u8 = 3;
const RGB32_PIXEL_R: u8 = 2;
const RGB32_PIXEL_G: u8 = 1;
const RGB32_PIXEL_B: u8 = 0;
const RGB32_PIXEL_SIZE: u8 = 4;

// Global variables for initialization state
var need_init: bool = true;
var zero_lut: [256]u8 = undefined;

// Helper functions (translated from JavaScript)

/// Calculate ceiling of log base 2 of a value
pub fn ceilLog2(val: u32) u32 {
    if (val == 1) return 0;

    var result: u32 = 1;
    var v = val - 1;
    while (v >> 1 != 0) {
        v >>= 1;
        result += 1;
    }
    return result;
}

/// Initialize a family structure for a given bits per component and limit
pub fn familyInit(family: *Family, bpc: u32, limit: u32) void {
    // Initialize GR (Golomb-Rice) parameters
    for (0..bpc) |l| {
        var altprefixlen = limit - bpc;
        if (altprefixlen > BPP_MASK[bpc - l]) {
            altprefixlen = BPP_MASK[bpc - l];
        }

        const altcodewords = BPP_MASK[bpc] + 1 - (altprefixlen << @intCast(l));
        family.n_gr_codewords[l] = altprefixlen << @intCast(l);
        family.not_gr_cwlen[l] = altprefixlen + ceilLog2(altcodewords);
        family.not_gr_prefix_mask[l] = BPP_MASK[32 - altprefixlen];
        family.not_gr_suffix_len[l] = ceilLog2(altcodewords);
    }

    // Decorrelation initialization
    const pixelbitmask = BPP_MASK[bpc];
    const pixelbitmaskshr = pixelbitmask >> 1;

    for (0..pixelbitmask + 1) |s| {
        const s_u32 = @as(u32, @intCast(s));
        if (s_u32 <= pixelbitmaskshr) {
            family.xlat_u2l[s] = s_u32 << 1;
        } else {
            family.xlat_u2l[s] = ((pixelbitmask - s_u32) << 1) + 1;
        }
    }

    // Correlation initialization
    for (0..pixelbitmask + 1) |s| {
        const s_u32 = @as(u32, @intCast(s));
        if ((s_u32 & 0x01) != 0) {
            family.xlat_l2u[s] = pixelbitmask - (s_u32 >> 1);
        } else {
            family.xlat_l2u[s] = s_u32 >> 1;
        }
    }
}

/// Get bits per component for image type
pub fn quicImageBpc(image_type: u32) u32 {
    return switch (image_type) {
        Constants.QUIC_IMAGE_TYPE_GRAY => 8,
        Constants.QUIC_IMAGE_TYPE_RGB16 => 5,
        Constants.QUIC_IMAGE_TYPE_RGB24, Constants.QUIC_IMAGE_TYPE_RGB32 => 8,
        Constants.QUIC_IMAGE_TYPE_RGBA => 8,
        else => 0,
    };
}

/// Count leading zeroes in a byte
pub fn cntLZeroes(bits: u8) u8 {
    return L_ZEROES[bits];
}

// TODO: Add more structures and functions for QuicModel, QuicBucket, etc.

/// Initialize the QUIC library
pub fn init() !void {
    if (!need_init) return;

    need_init = false;

    // Initialize families
    familyInit(&family_8bpc, 8, DEF_MAX_CLEN);
    familyInit(&family_5bpc, 5, DEF_MAX_CLEN);

    // Initialize zero lookup table
    var j: u32 = 1;
    var k: u32 = 1;
    var l: u8 = 8;

    for (0..256) |i| {
        zero_lut[i] = l;
        if (k > 0) {
            k -= 1;
        }
        if (k == 0) {
            k = j;
            if (l > 0) {
                l -= 1;
            }
            j *= 2;
        }
    }
}

// Tests
test "ceilLog2" {
    try testing.expect(ceilLog2(1) == 0);
    try testing.expect(ceilLog2(2) == 1);
    try testing.expect(ceilLog2(3) == 2);
    try testing.expect(ceilLog2(4) == 2);
    try testing.expect(ceilLog2(8) == 3);
}

test "quicImageBpc" {
    try testing.expect(quicImageBpc(Constants.QUIC_IMAGE_TYPE_GRAY) == 8);
    try testing.expect(quicImageBpc(Constants.QUIC_IMAGE_TYPE_RGB16) == 5);
    try testing.expect(quicImageBpc(Constants.QUIC_IMAGE_TYPE_RGB24) == 8);
}

test "init" {
    try init();
    // Basic sanity check that initialization completed
    try testing.expect(!need_init);
}
