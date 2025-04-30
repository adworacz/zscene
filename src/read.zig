const std = @import("std");
const vapoursynth = @import("vapoursynth");
const testing = @import("std").testing;

const vs = vapoursynth.vapoursynth4;
const vsh = vapoursynth.vshelper;

const ar = vs.ActivationReason;
const rp = vs.RequestPattern;
const fm = vs.FilterMode;
const st = vs.SampleType;

// https://ziglang.org/documentation/master/#Choosing-an-Allocator
//
// Using the C allocator since we're passing pointers to allocated memory between Zig and C code,
// specifically the filter data between the Create and GetFrame functions.
const allocator = std.heap.c_allocator;

const FramesSet = std.array_hash_map.AutoArrayHashMapUnmanaged(u32, void);

const ReadScenesData = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,
    vi: *const vs.VideoInfo,

    frames_set: FramesSet,
};

fn getFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) ?*const vs.Frame {
    // Assign frame_data to nothing to stop compiler complaints
    _ = frame_data;

    const d: *ReadScenesData = @ptrCast(@alignCast(instance_data));

    if (activation_reason == ar.Initial) {
        vsapi.?.requestFrameFilter.?(n, d.node, frame_ctx);
    } else if (activation_reason == ar.AllFramesReady) {
        const src_frame = vsapi.?.getFrameFilter.?(n, d.node, frame_ctx);
        defer vsapi.?.freeFrame.?(src_frame);

        const dst = vsapi.?.copyFrame.?(src_frame, core);
        const props = vsapi.?.getFramePropertiesRW.?(dst);

        _ = vsapi.?.mapSetInt.?(props, "_SceneChangePrev", @intFromBool(d.frames_set.contains(@intCast(n))), vs.MapAppendMode.Replace);
        _ = vsapi.?.mapSetInt.?(props, "_SceneChangeNext", @intFromBool(d.frames_set.contains(@intCast(n+1))), vs.MapAppendMode.Replace);

        return dst;
    }

    return null;
}

export fn readScenesFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = core;
    const d: *ReadScenesData = @ptrCast(@alignCast(instance_data));
    vsapi.?.freeNode.?(d.node);

    d.frames_set.deinit(allocator);
    d.frames_set = undefined;

    allocator.destroy(d);
}

const ScenesJson = struct{
    scene_changes: []u32,
    frame_count: u32,
    speed: f32,
};

export fn readScenesCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = user_data;
    var d: ReadScenesData = undefined;

    // TODO: Add error handling.
    var err: vs.MapPropertyError = undefined;

    d.node = vsapi.?.mapGetNode.?(in, "clip", 0, &err).?;
    d.vi = vsapi.?.getVideoInfo.?(d.node);

    const path_len: usize = @intCast(vsapi.?.mapGetDataSize.?(in, "path", 0, &err));
    const path = vsapi.?.mapGetData.?(in, "path", 0, &err)[0..path_len];

    const file = std.fs.cwd().openFile(path, .{ .mode = .read_only }) catch {
        vsapi.?.mapSetError.?(out, "ReadScenes: Unable to read the provided scene file.");
        vsapi.?.freeNode.?(d.node);
        return;
    };
    defer file.close();

    const reader = file.reader();

    var json_reader = std.json.reader(allocator, reader);
    defer json_reader.deinit();
    
    const json = std.json.parseFromTokenSource(ScenesJson, allocator, &json_reader, .{}) catch {
        vsapi.?.mapSetError.?(out, "ReadScenes: Unable to parse the scene json data.");
        vsapi.?.freeNode.?(d.node);
        return;
    };
    defer json.deinit();

    const scenes = json.value.scene_changes;

    d.frames_set = FramesSet{};
    d.frames_set.ensureTotalCapacity(allocator, scenes.len) catch {
        vsapi.?.mapSetError.?(out, "ReadScenes: Unable to allocate space for frame set.");
        vsapi.?.freeNode.?(d.node);
        return;
    };

    for (scenes) |scene| {
        d.frames_set.put(allocator, scene, {}) catch unreachable;
    }

    const data: *ReadScenesData = allocator.create(ReadScenesData) catch unreachable;
    data.* = d;

    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.StrictSpatial,
        },
    };

    vsapi.?.createVideoFilter.?(out, "ReadScenes", d.vi, getFrame, readScenesFree, fm.Parallel, &deps, deps.len, data, core);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("ReadScenes", "clip:vnode;path:data", "clip:vnode;", readScenesCreate, null, plugin);
}
