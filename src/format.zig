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

    pub fn deinit(self: *Self, allocator: Allocator) void {
        allocator.free(self.scenes);

        self.scenes = undefined;
        self.frame_count = 0;
    }
};

fn readAvSceneJson(allocator: Allocator, reader: *std.Io.Reader, err: *[:0]u8) !SceneData {
    var json_reader = std.json.Reader.init(allocator, reader);
    var diagnostics = std.json.Diagnostics{};
    json_reader.enableDiagnostics(&diagnostics);
    defer json_reader.deinit();

    const json = std.json.parseFromTokenSource(AvSceneChangeJson, allocator, &json_reader, .{}) catch |e| {
        err.* = try std.fmt.allocPrintSentinel(allocator, "ReadScenes: Unable to parse json - error parsing line {d}, column {d}", //
            .{ diagnostics.getLine(), diagnostics.getColumn() }, 0);

        return e;
    };
    defer json.deinit();

    return SceneData.init(try allocator.dupe(u32, json.value.scene_changes), json.value.frame_count);
}

fn readQpFile(allocator: Allocator, reader: *std.Io.Reader, err: *[:0]u8) !SceneData {
    var scenes = try std.array_list.Aligned(u32, null).initCapacity(allocator, 100);
    defer scenes.deinit(allocator);

    // Ensure that the first frame is always marked as a scene change,
    // since it is, but qpfile writers might omit it.
    try scenes.append(allocator, 0);

    // Line numbers in a file start from '1', not zero.
    var line_num: u32 = 1;
    while (try reader.takeDelimiter('\n')) |line| : (line_num += 1) {
        var line_iter = std.mem.tokenizeScalar(u8, line, ' ');

        var frame_num: u32 = undefined;
        var frame_type: u8 = undefined;
        var elem_count: u8 = 0;
        while (line_iter.next()) |token| : (elem_count += 1) {
            // We handle files without a listed frame type (just a frame number)
            // by defaulting the frame type to 'K'.
            // This will be overridden in the switch below if a real frame type is specified.
            frame_type = 'K';

            switch (elem_count) {
                0 => {
                    // frame number is the first token
                    frame_num = std.fmt.parseUnsigned(u32, token, 10) catch |e| {
                        err.* = try std.fmt.allocPrintSentinel(allocator, "ReadScenes: Unable to parse line {d} of the scene file", .{line_num}, 0);
                        return e;
                    };
                },
                1 => {
                    // frame type is the second token
                    if (token.len != 1) {
                        // the frame type should be a single character
                        err.* = try std.fmt.allocPrintSentinel(allocator, "ReadScenes: Frame type {s} on line {d} is not a single character", .{ token, line_num }, 0);
                        return error.InvalidFrameType;
                    }
                    frame_type = token[0];
                },
                else => {
                    // Extra data is on the line
                    break;
                },
            }
        }

        if (frame_type == 'K' or frame_type == 'I') {
            try scenes.append(allocator, frame_num);
        }
    }

    return SceneData.init(try scenes.toOwnedSlice(allocator), null);
}

pub fn readScenes(allocator: Allocator, path: []const u8, format: Format, err: *[:0]u8) !SceneData {
    const file = std.fs.cwd().openFile(path, .{ .mode = .read_only }) catch |e| {
        err.* = try std.fmt.allocPrintSentinel(allocator, "ReadScenes: Unable to open file {s}", .{path}, 0);
        return e;
    };
    defer file.close();

    var buffer: [1024]u8 = undefined;
    var file_reader = file.reader(&buffer);
    const reader = &file_reader.interface;

    return switch (format) {
        .scene_json => readAvSceneJson(allocator, reader, err),
        .qpfile => readQpFile(allocator, reader, err),
    };
}

test readScenes {
    const allocator = std.testing.allocator;

    const qpfile = "src/test_scenes.qpfile";
    const qpfile_no_frametype = "src/test_scenes_no_frametype.qpfile";
    const jsonfile = "src/test_scenes.json";

    const expected_scenes = [_]u32{ 0, 1, 2, 4 };

    var err: [:0]u8 = undefined;

    var scene_data: SceneData = undefined;

    scene_data = try readScenes(allocator, qpfile, .qpfile, &err);
    try std.testing.expectEqualDeep(&expected_scenes, scene_data.scenes);
    scene_data.deinit(allocator);

    scene_data = try readScenes(allocator, qpfile_no_frametype, .qpfile, &err);
    try std.testing.expectEqualDeep(&expected_scenes, scene_data.scenes);
    scene_data.deinit(allocator);

    scene_data = try readScenes(allocator, jsonfile, .scene_json, &err);
    try std.testing.expectEqualDeep(&expected_scenes, scene_data.scenes);
    try std.testing.expectEqual(5, scene_data.frame_count);
    scene_data.deinit(allocator);
}
