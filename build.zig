const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the main library
    const quic_lib = b.addStaticLibrary(.{
        .name = "quic",
        .root_source_file = b.path("src/quic.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Install the library
    b.installArtifact(quic_lib);

    // Create a module for easy consumption by other projects
    _ = b.addModule("quic", .{
        .root_source_file = b.path("src/quic.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Create a test executable for development and testing
    const test_exe = b.addExecutable(.{
        .name = "quic-test",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    test_exe.root_module.addImport("quic", quic_lib.root_module);
    b.installArtifact(test_exe);

    // Add run step for the test executable
    const run_cmd = b.addRunArtifact(test_exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the test application");
    run_step.dependOn(&run_cmd.step);

    // Unit tests
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/quic.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // Integration tests
    const integration_tests = b.addTest(.{
        .root_source_file = b.path("src/integration_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_integration_tests = b.addRunArtifact(integration_tests);

    const integration_test_step = b.step("test-integration", "Run integration tests against JavaScript reference");
    integration_test_step.dependOn(&run_integration_tests.step);

    // Benchmark step (for performance testing)
    const bench_exe = b.addExecutable(.{
        .name = "quic-bench",
        .root_source_file = b.path("src/bench.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });

    bench_exe.root_module.addImport("quic", quic_lib.root_module);
    b.installArtifact(bench_exe);

    const run_bench = b.addRunArtifact(bench_exe);
    const bench_step = b.step("bench", "Run benchmarks");
    bench_step.dependOn(&run_bench.step);

    // File decoder executable for processing QUIC binary files
    const decoder_exe = b.addExecutable(.{
        .name = "quic-decoder",
        .root_source_file = b.path("src/file_decoder.zig"),
        .target = target,
        .optimize = optimize,
    });

    decoder_exe.root_module.addImport("quic", quic_lib.root_module);
    b.installArtifact(decoder_exe);

    const run_decoder = b.addRunArtifact(decoder_exe);
    const decoder_step = b.step("decode", "Run the QUIC file decoder");
    decoder_step.dependOn(&run_decoder.step);
}
