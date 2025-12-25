const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Format = enum(u8) {
    scene_json = 0, // AV Scene Json
    qpfile = 1, // QP file format (frame numbers with 'K' for keyframes)
};

/// av-scenechange json format
const AvSceneChangeJson = struct {
    scene_changes: []u32,
    frame_count: u32,
    speed: f32,
};

pub const SceneData = struct {
    scenes: []u32,
    frame_count: ?u32,

    const Self = @This();

    fn init(scenes: []u32, frame_count: ?u32) SceneData {
        return .{
            .scenes = scenes,
            .frame_count = frame_count,
        };
    }

    fn deinit(self: *Self, allocator: Allocator) void {
        allocator.free(self.scenes);

        self.scenes = undefined;
        self.frame_count = 0;
    }
};

fn readAvSceneJson(allocator: Allocator, file: std.fs.File, err: *[:0]u8) !SceneData {
    var buffer: [1024]u8 = undefined;
    var reader = file.reader(&buffer);

    var json_reader = std.json.Reader.init(allocator, &reader.interface);
    var diagnostics = std.json.Diagnostics{};
    json_reader.enableDiagnostics(&diagnostics);
    defer json_reader.deinit();

    const json = std.json.parseFromTokenSource(AvSceneChangeJson, allocator, &json_reader, .{}) catch |e| {
        err.* = try std.fmt.allocPrintSentinel(allocator, "ReadScenes: Unable to parse json - error parsing line {d}, column {d}", //
            .{ diagnostics.getLine(), diagnostics.getColumn() }, 0);

        return e;
    };
    defer json.deinit();

    return SceneData.init(json.value.scene_changes, json.value.frame_count);
}

pub fn readScenes(allocator: Allocator, path: []const u8, format: Format, err: *[:0]u8) !SceneData {
    const file = std.fs.cwd().openFile(path, .{ .mode = .read_only }) catch |e| {
        err.* = try std.fmt.allocPrintSentinel(allocator, "ReadScenes: Unable to open file {s}", .{path}, 0);
        return e;
    };
    defer file.close();

    return switch (format) {
        .scene_json =>  readAvSceneJson(allocator, file, err),
        else => unreachable,
    };
}
