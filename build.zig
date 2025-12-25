const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zscene_module = b.createModule(.{
        .root_source_file = b.path("src/zscene.zig"),

        .target = target,
        .optimize = optimize,

        // This application is single threaded (as VapourSynth handles the threading for us)
        // so might as well mark it so in case we ever import data
        // structures that *might* have thread safety built in,
        // in which case setting this value will optimize out any threading
        // or locking constructs.
        .single_threaded = true,

        .strip = optimize == .ReleaseFast,
    });

    const lib = b.addLibrary(.{
        .name = "zscene",
        .root_module = zscene_module,

        // Improve build times by giving an upper bound to memory,
        // thus enabling multi-threaded builds.
        .max_rss = 1024 * 1024 * 1024 * 2, // 2GB

        .linkage = .dynamic,
    });

    const vapoursynth_dep = b.dependency("vapoursynth", .{
        .target = target,
        .optimize = optimize,
    });

    lib.root_module.addImport("vapoursynth", vapoursynth_dep.module("vapoursynth"));
    lib.linkLibC(); // Necessary to use the C memory allocator.

    // Add check step for quick n easy build checking without
    // emitting binary output.
    //
    // Allows ZLS to provide better inline errors.
    //
    // https://zigtools.org/zls/guides/build-on-save/
    const check = b.step("check", "Check if zsmooth compiles");
    check.dependOn(&lib.step);

    b.installArtifact(lib);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_module = zscene_module,
    });

    lib_unit_tests.root_module.addImport("vapoursynth", vapoursynth_dep.module("vapoursynth"));
    lib_unit_tests.linkLibC();
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
