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

// Golomb coding result structure
const GolombResult = struct {
    codewordlen: u32,
    rc: u32,
};

/// Golomb decoding for 8 bits per component
pub fn golombDecoding8bpc(l: u32, bits: u32) GolombResult {
    var rc: u32 = undefined;
    var cwlen: u32 = undefined;

    if (bits > family_8bpc.not_gr_prefix_mask[l]) {
        const zeroprefix = cntLZeroes(@as(u8, @truncate(bits >> 24)));
        cwlen = zeroprefix + 1 + l;
        rc = (@as(u32, zeroprefix) << @intCast(l)) | ((bits >> @intCast(32 - cwlen)) & BPP_MASK[l]);
    } else {
        cwlen = family_8bpc.not_gr_cwlen[l];
        rc = family_8bpc.n_gr_codewords[l] + ((bits >> @intCast(32 - cwlen)) & BPP_MASK[family_8bpc.not_gr_suffix_len[l]]);
    }

    return GolombResult{ .codewordlen = cwlen, .rc = rc };
}

/// Calculate Golomb code length for 8 bits per component
pub fn golombCodeLen8bpc(n: u32, l: u32) u32 {
    if (n < family_8bpc.n_gr_codewords[l]) {
        return (n >> @intCast(l)) + 1 + l;
    } else {
        return family_8bpc.not_gr_cwlen[l];
    }
}

// Forward declarations for cross-references
const CommonState = struct {
    waitcnt: u32,
    tabrand_seed: u8,
    wm_trigger: u32,
    wmidx: u32,
    wmileft: u32,
    melcstate: u32,
    melclen: u32,
    melcorder: u32,

    fn init() CommonState {
        var state = CommonState{
            .waitcnt = 0,
            .tabrand_seed = 0xff,
            .wm_trigger = 0,
            .wmidx = 0,
            .wmileft = DEF_WMI_NEXT,
            .melcstate = 0,
            .melclen = 0,
            .melcorder = 0,
        };
        state.setWmTrigger();
        return state;
    }

    fn setWmTrigger(self: *CommonState) void {
        var wm = self.wmidx;
        if (wm > 10) {
            wm = 10;
        }

        const evol_idx = DEF_EVOL / 2;
        self.wm_trigger = BEST_TRIG_TAB[evol_idx][wm];
    }

    fn reste(self: *CommonState) void {
        self.waitcnt = 0;
        self.tabrand_seed = 0xff;
        self.wmidx = 0;
        self.wmileft = DEF_WMI_NEXT;

        self.setWmTrigger();

        self.melcstate = 0;
        self.melclen = J[0];
        self.melcorder = @as(u32, 1) << @intCast(self.melclen);
    }

    fn tabrand(self: *CommonState) u32 {
        self.tabrand_seed = self.tabrand_seed +% 1;
        return TABRAND_CHAOS[self.tabrand_seed];
    }
};

// Model structure for QUIC encoding/decoding
const QuicModel = struct {
    levels: u32,
    n_buckets_ptrs: u32,
    n_buckets: u32,
    repfirst: u32,
    firstsize: u32,
    repnext: u32,
    mulsize: u32,

    fn init(bpc: u32) QuicModel {
        var model = QuicModel{
            .levels = @as(u32, 1) << @intCast(bpc),
            .n_buckets_ptrs = 0,
            .n_buckets = 0,
            .repfirst = 0,
            .firstsize = 0,
            .repnext = 0,
            .mulsize = 0,
        };

        // Set parameters based on evol value (using DEF_EVOL = 3)
        const evol_val = DEF_EVOL;
        switch (evol_val) {
            1 => {
                model.repfirst = 3;
                model.firstsize = 1;
                model.repnext = 2;
                model.mulsize = 2;
            },
            3 => {
                model.repfirst = 1;
                model.firstsize = 1;
                model.repnext = 1;
                model.mulsize = 2;
            },
            5 => {
                model.repfirst = 1;
                model.firstsize = 1;
                model.repnext = 1;
                model.mulsize = 4;
            },
            else => {
                // Default case for other evol values
                model.repfirst = 1;
                model.firstsize = 1;
                model.repnext = 1;
                model.mulsize = 2;
            },
        }

        // Calculate bucket structure
        var bend: u32 = 0;
        var repcntr = model.repfirst + 1;
        var bsize = model.firstsize;

        while (true) {
            var bstart: u32 = undefined;
            if (model.n_buckets != 0) {
                bstart = bend + 1;
            } else {
                bstart = 0;
            }

            repcntr -= 1;
            if (repcntr == 0) {
                repcntr = model.repnext;
                bsize *= model.mulsize;
            }

            bend = bstart + bsize - 1;
            if (bend + bsize >= model.levels) {
                bend = model.levels - 1;
            }

            if (model.n_buckets_ptrs == 0) {
                model.n_buckets_ptrs = model.levels;
            }

            model.n_buckets += 1;

            if (bend >= model.levels - 1) break;
        }

        return model;
    }
};

// Bucket structure for model buckets
const QuicBucket = struct {
    counters: [8]u32,
    bestcode: u32,

    fn init() QuicBucket {
        return QuicBucket{
            .counters = [8]u32{ 0, 0, 0, 0, 0, 0, 0, 0 },
            .bestcode = 0,
        };
    }

    fn reste(self: *QuicBucket, bpp: u32) void {
        self.bestcode = bpp;
        self.counters = [8]u32{ 0, 0, 0, 0, 0, 0, 0, 0 };
    }

    fn updateModel8bpc(self: *QuicBucket, state: *CommonState, curval: u32, bpp: u32) void {
        var bestcode = bpp - 1;
        self.counters[bestcode] += golombCodeLen8bpc(curval, bestcode);
        var bestcodelen = self.counters[bestcode];

        var i: i32 = @as(i32, @intCast(bpp)) - 2;
        while (i >= 0) : (i -= 1) {
            const idx = @as(u32, @intCast(i));
            self.counters[idx] += golombCodeLen8bpc(curval, idx);
            const ithcodelen = self.counters[idx];

            if (ithcodelen < bestcodelen) {
                bestcode = idx;
                bestcodelen = ithcodelen;
            }
        }

        self.bestcode = bestcode;

        if (bestcodelen > state.wm_trigger) {
            for (0..bpp) |j| {
                self.counters[j] = self.counters[j] >> 1;
            }
        }
    }
};

// Family statistics structure
const QuicFamilyStat = struct {
    buckets_ptrs: std.ArrayList(?*QuicBucket),
    buckets_buf: std.ArrayList(QuicBucket),

    fn init(allocator: Allocator) QuicFamilyStat {
        return QuicFamilyStat{
            .buckets_ptrs = std.ArrayList(?*QuicBucket).init(allocator),
            .buckets_buf = std.ArrayList(QuicBucket).init(allocator),
        };
    }

    fn deinit(self: *QuicFamilyStat) void {
        self.buckets_ptrs.deinit();
        self.buckets_buf.deinit();
    }

    fn fillModelStructures(self: *QuicFamilyStat, model: *const QuicModel) !bool {
        try self.buckets_ptrs.resize(model.levels);
        try self.buckets_buf.resize(model.n_buckets);

        // Initialize all pointers to null first
        for (0..model.levels) |i| {
            self.buckets_ptrs.items[i] = null;
        }

        var bend: u32 = 0;
        var bnumber: u32 = 0;
        var repcntr = model.repfirst + 1;
        var bsize = model.firstsize;

        while (true) {
            var bstart: u32 = undefined;
            if (bnumber != 0) {
                bstart = bend + 1;
            } else {
                bstart = 0;
            }

            repcntr -= 1;
            if (repcntr == 0) {
                repcntr = model.repnext;
                bsize *= model.mulsize;
            }

            bend = bstart + bsize - 1;
            if (bend + bsize >= model.levels) {
                bend = model.levels - 1;
            }

            self.buckets_buf.items[bnumber] = QuicBucket.init();

            // Ensure we don't go out of bounds
            const end_idx = @min(bend + 1, model.levels);
            for (bstart..end_idx) |i| {
                if (i < model.levels) {
                    self.buckets_ptrs.items[i] = &self.buckets_buf.items[bnumber];
                }
            }

            bnumber += 1;

            if (bend >= model.levels - 1) break;
        }

        return true;
    }
};

// Correlate row structure
const CorrelateRow = struct {
    zero: u32,
    row: std.ArrayList(u32),

    fn init(allocator: Allocator) CorrelateRow {
        return CorrelateRow{
            .zero = 0,
            .row = std.ArrayList(u32).init(allocator),
        };
    }

    fn deinit(self: *CorrelateRow) void {
        self.row.deinit();
    }
};

// Channel structure
const QuicChannel = struct {
    state: CommonState,
    family_stat_8bpc: QuicFamilyStat,
    family_stat_5bpc: QuicFamilyStat,
    correlate_row: CorrelateRow,
    model_8bpc: *const QuicModel,
    model_5bpc: *const QuicModel,
    buckets_ptrs: ?*QuicBucket, // Current bucket pointer

    fn init(allocator: Allocator, model_8bpc: *const QuicModel, model_5bpc: *const QuicModel) QuicChannel {
        return QuicChannel{
            .state = CommonState.init(),
            .family_stat_8bpc = QuicFamilyStat.init(allocator),
            .family_stat_5bpc = QuicFamilyStat.init(allocator),
            .correlate_row = CorrelateRow.init(allocator),
            .model_8bpc = model_8bpc,
            .model_5bpc = model_5bpc,
            .buckets_ptrs = null,
        };
    }

    fn deinit(self: *QuicChannel) void {
        self.family_stat_8bpc.deinit();
        self.family_stat_5bpc.deinit();
        self.correlate_row.deinit();
    }

    fn reste(self: *QuicChannel, bpc: u32) !bool {
        // Reset correlate row
        self.correlate_row.zero = 0;
        self.correlate_row.row.clearAndFree();

        if (bpc == 8) {
            _ = try self.family_stat_8bpc.fillModelStructures(self.model_8bpc);
            // Reset buckets for 8bpc
            for (self.family_stat_8bpc.buckets_buf.items) |*bucket| {
                bucket.reste(7);
            }
            // Note: buckets_ptrs assignment would need to be properly handled
        } else if (bpc == 5) {
            _ = try self.family_stat_5bpc.fillModelStructures(self.model_5bpc);
            // Reset buckets for 5bpc
            for (self.family_stat_5bpc.buckets_buf.items) |*bucket| {
                bucket.reste(4);
            }
            // Note: buckets_ptrs assignment would need to be properly handled
        } else {
            std.debug.print("quic: bad bpc {}\n", .{bpc});
            return false;
        }

        self.state.reste();
        return true;
    }
};

// Main encoder structure
pub const QuicEncoder = struct {
    allocator: Allocator,
    rgb_state: CommonState,
    model_8bpc: QuicModel,
    model_5bpc: QuicModel,
    channels: [4]QuicChannel,

    // Image properties
    image_type: u32,
    width: u32,
    height: u32,

    // I/O state
    io_idx: u32,
    io_available_bits: u32,
    io_word: u32,
    io_next_word: u32,
    io_now: []const u8,
    io_end: u32,
    rows_completed: u32,

    pub fn init(allocator: Allocator) !QuicEncoder {
        var encoder = QuicEncoder{
            .allocator = allocator,
            .rgb_state = CommonState.init(),
            .model_8bpc = QuicModel.init(8),
            .model_5bpc = QuicModel.init(5),
            .channels = undefined,
            .image_type = 0,
            .width = 0,
            .height = 0,
            .io_idx = 0,
            .io_available_bits = 0,
            .io_word = 0,
            .io_next_word = 0,
            .io_now = &[_]u8{},
            .io_end = 0,
            .rows_completed = 0,
        };

        // Initialize channels with null pointers first
        for (0..4) |i| {
            encoder.channels[i] = QuicChannel.init(allocator, undefined, undefined);
        }

        return encoder;
    }

    pub fn initChannelPointers(self: *QuicEncoder) void {
        // Fix the model pointers after the encoder is fully constructed
        for (0..4) |i| {
            self.channels[i].model_8bpc = &self.model_8bpc;
            self.channels[i].model_5bpc = &self.model_5bpc;
        }
    }

    pub fn deinit(self: *QuicEncoder) void {
        for (0..4) |i| {
            self.channels[i].deinit();
        }
    }

    // I/O functions (from JavaScript)

    /// Reset encoder state with new byte stream
    pub fn reste(self: *QuicEncoder, io_ptr: []const u8) bool {
        self.rgb_state.reste();

        self.io_now = io_ptr;
        self.io_end = @intCast(io_ptr.len);
        self.io_idx = 0;
        self.rows_completed = 0;
        return true;
    }

    /// Read a 32-bit word from the byte stream (little-endian)
    pub fn readIoWord(self: *QuicEncoder) !void {
        if (self.io_idx + 4 > self.io_end) {
            return error.OutOfData;
        }

        self.io_next_word = @as(u32, self.io_now[self.io_idx]) |
            (@as(u32, self.io_now[self.io_idx + 1]) << 8) |
            (@as(u32, self.io_now[self.io_idx + 2]) << 16) |
            (@as(u32, self.io_now[self.io_idx + 3]) << 24);
        self.io_idx += 4;
    }

    /// Consume specified number of bits from the bit stream
    pub fn decodeEatbits(self: *QuicEncoder, len: u32) !void {
        self.io_word <<= @intCast(len);

        const delta_signed = @as(i32, @intCast(self.io_available_bits)) - @as(i32, @intCast(len));
        if (delta_signed >= 0) {
            const delta: u32 = @intCast(delta_signed);
            self.io_available_bits = delta;
            self.io_word |= self.io_next_word >> @intCast(self.io_available_bits);
        } else {
            const delta: u32 = @intCast(-delta_signed);
            self.io_word |= self.io_next_word << @intCast(delta);
            try self.readIoWord();
            self.io_available_bits = 32 - delta;
            self.io_word |= self.io_next_word >> @intCast(self.io_available_bits);
        }
    }

    /// Consume 32 bits from the bit stream
    pub fn decodeEat32bits(self: *QuicEncoder) !void {
        try self.decodeEatbits(16);
        try self.decodeEatbits(16);
    }

    /// Reset all channels for specified bits per component
    pub fn resteChannels(self: *QuicEncoder, bpc: u32) !bool {
        for (0..4) |i| {
            if (!(try self.channels[i].reste(bpc))) {
                return false;
            }
        }
        return true;
    }

    /// Parse QUIC header and validate format
    pub fn quicDecodeBegin(self: *QuicEncoder, io_ptr: []const u8) !bool {
        if (!self.reste(io_ptr)) {
            return false;
        }

        self.io_idx = 0;
        try self.readIoWord();
        self.io_word = self.io_next_word;
        self.io_available_bits = 0;

        // Check magic number (QUIC = 0x43495551)
        const magic = self.io_word;
        try self.decodeEat32bits();
        if (magic != 0x43495551) {
            std.debug.print("quic: bad magic 0x{X}\n", .{magic});
            return false;
        }

        // Check version (0x00000000)
        const version = self.io_word;
        try self.decodeEat32bits();
        if (version != 0x00000000) {
            std.debug.print("quic: bad version 0x{X}\n", .{version});
            return false;
        }

        // Read image type
        self.image_type = self.io_word;
        try self.decodeEat32bits();

        // Read width
        self.width = self.io_word;
        try self.decodeEat32bits();

        // Read height
        self.height = self.io_word;
        try self.decodeEat32bits();

        // Get bits per component and reset channels
        const bpc = quicImageBpc(self.image_type);
        if (bpc == 0) {
            std.debug.print("quic: invalid image type {}\n", .{self.image_type});
            return false;
        }

        if (!(try self.resteChannels(bpc))) {
            return false;
        }

        return true;
    }

    // Row decompression functions (from JavaScript)

    /// Decode run length for RLE compression
    pub fn decodeRun(self: *QuicEncoder, state: *CommonState) !u32 {
        var runlen: u32 = 0;

        while (true) {
            const x = (~(self.io_word >> 24)) & 0xff;
            const temp = zero_lut[x];

            var hits: u32 = 1;
            while (hits <= temp) : (hits += 1) {
                runlen += state.melcorder;

                if (state.melcstate < 32) {
                    state.melcstate += 1;
                    state.melclen = J[state.melcstate];
                    state.melcorder = @as(u32, 1) << @intCast(state.melclen);
                }
            }

            if (temp != 8) {
                try self.decodeEatbits(temp + 1);
                break;
            }
            try self.decodeEatbits(8);
        }

        if (state.melclen > 0) {
            runlen += self.io_word >> @intCast(32 - state.melclen);
            try self.decodeEatbits(state.melclen);
        }

        if (state.melcstate > 0) {
            state.melcstate -= 1;
            state.melclen = J[state.melcstate];
            state.melcorder = @as(u32, 1) << @intCast(state.melclen);
        }

        return runlen;
    }

    /// Decompress a segment of the first row for RGB32 format
    pub fn quicRgb32UncompressRow0Seg(self: *QuicEncoder, start_i: u32, cur_row: []u8, end: u32, waitmask: u32, bpc: u32, bpc_mask: u32) !void {
        const n_channels: u32 = 3;
        var i = start_i;
        var stopidx: u32 = undefined;

        if (i == 0) {
            cur_row[RGB32_PIXEL_PAD] = 0;

            var c: u32 = 0;
            while (c < n_channels) : (c += 1) {
                const channel = &self.channels[c];
                const bucket = channel.family_stat_8bpc.buckets_ptrs.items[channel.correlate_row.zero];
                if (bucket) |b| {
                    const golomb_result = golombDecoding8bpc(b.bestcode, self.io_word);
                    try channel.correlate_row.row.append(golomb_result.rc);
                    if (channel.correlate_row.row.items.len == 1) {
                        // This is index 0
                        cur_row[2 - c] = @intCast(family_8bpc.xlat_l2u[golomb_result.rc] & 0xFF);
                    }
                    try self.decodeEatbits(golomb_result.codewordlen);
                }
            }

            if (self.rgb_state.waitcnt > 0) {
                self.rgb_state.waitcnt -= 1;
            } else {
                self.rgb_state.waitcnt = self.rgb_state.tabrand() & waitmask;
                c = 0;
                while (c < n_channels) : (c += 1) {
                    const channel = &self.channels[c];
                    const bucket = channel.family_stat_8bpc.buckets_ptrs.items[channel.correlate_row.zero];
                    if (bucket) |b| {
                        if (channel.correlate_row.row.items.len > 0) {
                            b.updateModel8bpc(&self.rgb_state, channel.correlate_row.row.items[0], bpc);
                        }
                    }
                }
            }
            i += 1;
            stopidx = i + self.rgb_state.waitcnt;
        } else {
            stopidx = i + self.rgb_state.waitcnt;
        }

        while (stopidx < end) {
            while (i <= stopidx) : (i += 1) {
                const pixel_idx = i * RGB32_PIXEL_SIZE;
                cur_row[pixel_idx + RGB32_PIXEL_PAD] = 0;

                var c: u32 = 0;
                while (c < n_channels) : (c += 1) {
                    const channel = &self.channels[c];
                    if (channel.correlate_row.row.items.len > 0) {
                        const prev_val = channel.correlate_row.row.items[i - 1];
                        const bucket = channel.family_stat_8bpc.buckets_ptrs.items[prev_val];
                        if (bucket) |b| {
                            const golomb_result = golombDecoding8bpc(b.bestcode, self.io_word);
                            try channel.correlate_row.row.append(golomb_result.rc);

                            const prev_pixel_idx = (i - 1) * RGB32_PIXEL_SIZE;
                            const decoded_val = family_8bpc.xlat_l2u[golomb_result.rc] + cur_row[prev_pixel_idx + (2 - c)];
                            cur_row[pixel_idx + (2 - c)] = @intCast(decoded_val & bpc_mask);

                            try self.decodeEatbits(golomb_result.codewordlen);
                        }
                    }
                }
            }

            var c: u32 = 0;
            while (c < n_channels) : (c += 1) {
                const channel = &self.channels[c];
                if (channel.correlate_row.row.items.len > stopidx) {
                    const bucket = channel.family_stat_8bpc.buckets_ptrs.items[channel.correlate_row.row.items[stopidx - 1]];
                    if (bucket) |b| {
                        b.updateModel8bpc(&self.rgb_state, channel.correlate_row.row.items[stopidx], bpc);
                    }
                }
            }
            stopidx = i + (self.rgb_state.tabrand() & waitmask);
        }

        while (i < end) : (i += 1) {
            const pixel_idx = i * RGB32_PIXEL_SIZE;
            cur_row[pixel_idx + RGB32_PIXEL_PAD] = 0;

            var c: u32 = 0;
            while (c < n_channels) : (c += 1) {
                const channel = &self.channels[c];
                if (channel.correlate_row.row.items.len > 0) {
                    const prev_val = channel.correlate_row.row.items[i - 1];
                    const bucket = channel.family_stat_8bpc.buckets_ptrs.items[prev_val];
                    if (bucket) |b| {
                        const golomb_result = golombDecoding8bpc(b.bestcode, self.io_word);
                        try channel.correlate_row.row.append(golomb_result.rc);

                        const prev_pixel_idx = (i - 1) * RGB32_PIXEL_SIZE;
                        const decoded_val = family_8bpc.xlat_l2u[golomb_result.rc] + cur_row[prev_pixel_idx + (2 - c)];
                        cur_row[pixel_idx + (2 - c)] = @intCast(decoded_val & bpc_mask);

                        try self.decodeEatbits(golomb_result.codewordlen);
                    }
                }
            }
        }
        self.rgb_state.waitcnt = @intCast(@as(i32, @intCast(stopidx)) - @as(i32, @intCast(end)));
    }

    /// Decompress the first row for RGB32 format
    pub fn quicRgb32UncompressRow0(self: *QuicEncoder, cur_row: []u8) !void {
        const bpc: u32 = 8;
        const bpc_mask: u32 = 0xff;
        var pos: u32 = 0;
        var width = self.width;

        while ((DEF_WMI_MAX > self.rgb_state.wmidx) and (self.rgb_state.wmileft <= width)) {
            if (self.rgb_state.wmileft > 0) {
                try self.quicRgb32UncompressRow0Seg(pos, cur_row, pos + self.rgb_state.wmileft, BPP_MASK[self.rgb_state.wmidx], bpc, bpc_mask);
                pos += self.rgb_state.wmileft;
                width -= self.rgb_state.wmileft;
            }

            self.rgb_state.wmidx += 1;
            self.rgb_state.setWmTrigger();
            self.rgb_state.wmileft = DEF_WMI_NEXT;
        }

        if (width > 0) {
            try self.quicRgb32UncompressRow0Seg(pos, cur_row, pos + width, BPP_MASK[self.rgb_state.wmidx], bpc, bpc_mask);
            if (DEF_WMI_MAX > self.rgb_state.wmidx) {
                self.rgb_state.wmileft -= width;
            }
        }
    }

    /// Simple QUIC decode function for basic testing
    pub fn simpleQuicDecode(self: *QuicEncoder, allocator: Allocator) !?[]u8 {
        // Calculate output buffer size based on image type
        const bytes_per_pixel: u32 = switch (self.image_type) {
            Constants.QUIC_IMAGE_TYPE_GRAY => 1,
            Constants.QUIC_IMAGE_TYPE_RGB16 => 2,
            Constants.QUIC_IMAGE_TYPE_RGB24 => 3,
            Constants.QUIC_IMAGE_TYPE_RGB32, Constants.QUIC_IMAGE_TYPE_RGBA => 4,
            else => return null,
        };

        const buffer_size = self.width * self.height * bytes_per_pixel;
        var output_buffer = try allocator.alloc(u8, buffer_size);

        // For now, just test the first row decompression for RGB32 format
        if (self.image_type == Constants.QUIC_IMAGE_TYPE_RGB32) {
            try self.quicRgb32UncompressRow0(output_buffer[0 .. self.width * 4]);

            // Fill remaining rows with dummy data for now
            for (1..self.height) |row| {
                const row_start = row * self.width * 4;
                const row_end = row_start + self.width * 4;
                if (row_end <= output_buffer.len) {
                    // Copy first row to subsequent rows for testing
                    @memcpy(output_buffer[row_start..row_end], output_buffer[0 .. self.width * 4]);
                }
            }
        } else {
            // For other formats, just fill with a test pattern for now
            for (0..buffer_size) |i| {
                output_buffer[i] = @intCast((i * 123) & 0xFF);
            }
        }

        return output_buffer;
    }
};
