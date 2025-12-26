const std = @import("std");
const vapoursynth = @import("vapoursynth");

const Format = @import("format.zig").Format;
const readScenes = @import("format.zig").readScenes;

const vs = vapoursynth.vapoursynth4;
const vsh = vapoursynth.vshelper;

const ar = vs.ActivationReason;
const rp = vs.RequestPattern;
const fm = vs.FilterMode;
const st = vs.SampleType;
const ZAPI = vapoursynth.ZAPI;

const allocator = std.heap.c_allocator;

const FramesSet = std.array_hash_map.AutoArrayHashMapUnmanaged(u32, void);

const ReadScenesData = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,
    vi: *const vs.VideoInfo,

    frames_set: FramesSet,
};

fn getFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) ?*const vs.Frame {
    // Assign frame_data to nothing to stop compiler complaints
    _ = frame_data;
    const zapi = ZAPI.init(vsapi, core, frame_ctx);
    const d: *ReadScenesData = @ptrCast(@alignCast(instance_data));

    if (activation_reason == ar.Initial) {
        zapi.requestFrameFilter(n, d.node);
    } else if (activation_reason == ar.AllFramesReady) {
        const src_frame = zapi.initZFrame(d.node, n);
        defer src_frame.deinit();

        const dst = src_frame.copyFrame();
        const props = dst.getPropertiesRW();

        props.setInt("_SceneChangePrev", @intFromBool(d.frames_set.contains(@intCast(n))), .Replace);
        props.setInt("_SceneChangeNext", @intFromBool(d.frames_set.contains(@intCast(n + 1))), .Replace);

        return dst.frame;
    }

    return null;
}

export fn readScenesFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) void {
    _ = core;
    const d: *ReadScenesData = @ptrCast(@alignCast(instance_data));
    vsapi.?.freeNode.?(d.node);

    d.frames_set.deinit(allocator);
    d.frames_set = undefined;

    allocator.destroy(d);
}

const ScenesJson = struct {
    scene_changes: []u32,
    frame_count: u32,
    speed: f32,
};

export fn readScenesCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) void {
    _ = user_data;
    var d: ReadScenesData = undefined;

    const zapi = ZAPI.init(vsapi, core, null);
    const map_in = zapi.initZMap(in);
    const map_out = zapi.initZMap(out);

    d.node, d.vi = map_in.getNodeVi("clip").?;

    const path = map_in.getData("path", 0) orelse unreachable;
    const format: Format = @enumFromInt(map_in.getInt(u8, "format") orelse 0);

    var err: [:0]u8 = undefined;
    var scene_data = readScenes(allocator, path, format, &err) catch {
        map_out.setError(err);
        zapi.freeNode(d.node);
        return;
    };
    defer scene_data.deinit(allocator);

    d.frames_set = FramesSet{};
    d.frames_set.ensureTotalCapacity(allocator, scene_data.scenes.len) catch {
        map_out.setError("ReadScenes: Unable to allocate space for frame set.");
        zapi.freeNode(d.node);
        return;
    };

    for (scene_data.scenes) |scene| {
        d.frames_set.putAssumeCapacity(scene, {});
    }

    const data: *ReadScenesData = allocator.create(ReadScenesData) catch unreachable;
    data.* = d;

    const deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.StrictSpatial,
        },
    };

    zapi.createVideoFilter(out, "ReadScenes", d.vi, getFrame, readScenesFree, .Parallel, &deps, data);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("ReadScenes", "clip:vnode;path:data;format:int;", "clip:vnode;", readScenesCreate, null, plugin);
}
