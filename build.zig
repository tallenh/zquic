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

    // Integration tests
    const integration_tests = b.addTest(.{
        .root_source_file = b.path("src/integration_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_integration_tests = b.addRunArtifact(integration_tests);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_integration_tests.step);

    const integration_test_step = b.step("test-integration", "Run integration tests against JavaScript reference");
    integration_test_step.dependOn(&run_integration_tests.step);

    // Benchmark step (for performance testing)
    const bench_exe = b.addExecutable(.{
        .name = "quic-bench",
        .root_source_file = b.path("benchmarks/bench.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });

    bench_exe.root_module.addImport("quic", quic_lib.root_module);
    b.installArtifact(bench_exe);

    const run_bench = b.addRunArtifact(bench_exe);
    const bench_step = b.step("bench", "Run benchmarks");
    bench_step.dependOn(&run_bench.step);

    // Performance benchmark with real SPICE data
    const perf_bench_exe = b.addExecutable(.{
        .name = "quic-benchmark",
        .root_source_file = b.path("benchmarks/benchmark.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });

    perf_bench_exe.root_module.addImport("quic", quic_lib.root_module);
    b.installArtifact(perf_bench_exe);

    const run_perf_bench = b.addRunArtifact(perf_bench_exe);
    const perf_bench_step = b.step("benchmark", "Run performance benchmark with real SPICE data");
    perf_bench_step.dependOn(&run_perf_bench.step);

    // Benchmark executables
    const zig_bench_exe = b.addExecutable(.{
        .name = "benchmark_zig",
        .root_source_file = b.path("benchmarks/benchmark_zig.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });
    zig_bench_exe.root_module.addImport("quic", quic_lib.root_module);

    // Build C benchmark
    const build_c_bench = b.addSystemCommand(&.{
        "gcc", "-O3", "-o", "benchmarks/benchmark_c", 
        "benchmarks/benchmark_c.c",
        "-Ispice-common/common",
        "-Lspice-common/build/common",
        "-lspice-common-client",
        "-lspice-common",
        "-I/opt/homebrew/Cellar/pixman/0.46.0/include/pixman-1",
        "-L/opt/homebrew/Cellar/pixman/0.46.0/lib",
        "-lpixman-1",
        "-I/opt/homebrew/Cellar/glib/2.84.2/include/glib-2.0",
        "-I/opt/homebrew/Cellar/glib/2.84.2/lib/glib-2.0/include",
        "-L/opt/homebrew/Cellar/glib/2.84.2/lib",
        "-lglib-2.0",
    });

    // Run Zig benchmark
    const run_zig_bench = b.addRunArtifact(zig_bench_exe);
    const zig_bench_step = b.step("bench-zig", "Run Zig benchmark");
    zig_bench_step.dependOn(&run_zig_bench.step);

    // Run C benchmark
    const run_c_bench = b.addSystemCommand(&.{ "./benchmarks/benchmark_c" });
    run_c_bench.step.dependOn(&build_c_bench.step);
    const c_bench_step = b.step("bench-c", "Build and run C benchmark");
    c_bench_step.dependOn(&run_c_bench.step);

    // Run all benchmarks (builds and runs both)
    const bench_all_step = b.step("bench-all", "Build and run all benchmarks (Zig vs C)");
    bench_all_step.dependOn(&run_zig_bench.step);
    bench_all_step.dependOn(&run_c_bench.step);

}
