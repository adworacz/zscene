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

const ReadScenesData = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,
    vi: *const vs.VideoInfo,

    // The modes for each plane we will process.
    modes: [3]u5,
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

        const process = [_]bool{
            d.modes[0] > 0,
            d.modes[1] > 0,
            d.modes[2] > 0,
        };
        // const dst = vscmn.newVideoFrame(&process, src_frame, d.vi, core, vsapi);

        var plane_src = [_]?*const vs.Frame{
            if (process[0]) null else src_frame,
            if (process[1]) null else src_frame,
            if (process[2]) null else src_frame,
        };
        const planes = [_]c_int{ 0, 1, 2 };

        const dst = vsapi.?.newVideoFrame2.?(&d.vi.format, d.vi.width, d.vi.height, @ptrCast(&plane_src), @ptrCast(&planes), src_frame, core);

        return dst;
    }

    return null;
}

export fn readScenesFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = core;
    const d: *ReadScenesData = @ptrCast(@alignCast(instance_data));
    vsapi.?.freeNode.?(d.node);
    allocator.destroy(d);
}

export fn readScenesCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = user_data;
    var d: ReadScenesData = undefined;

    // TODO: Add error handling.
    var err: vs.MapPropertyError = undefined;

    d.node = vsapi.?.mapGetNode.?(in, "clip", 0, &err).?;
    d.vi = vsapi.?.getVideoInfo.?(d.node);

    const data: *ReadScenesData = allocator.create(ReadScenesData) catch unreachable;
    data.* = d;

    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.StrictSpatial,
        },
    };

    // const getFrame = switch (d.vi.format.bytesPerSample) {
    //     1 => &ReadScenes(u8).getFrame,
    //     2 => if (d.vi.format.sampleType == vs.SampleType.Integer) &ReadScenes(u16).getFrame else &ReadScenes(f16).getFrame,
    //     4 => &ReadScenes(f32).getFrame,
    //     else => unreachable,
    // };
    // const getFrame = getFrame;

    vsapi.?.createVideoFilter.?(out, "ReadScenes", d.vi, getFrame, readScenesFree, fm.Parallel, &deps, deps.len, data, core);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("ReadScenes", "clip:vnode;mode:int[]", "clip:vnode;", readScenesCreate, null, plugin);
}
