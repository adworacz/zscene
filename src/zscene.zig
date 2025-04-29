const vapoursynth = @import("vapoursynth");
const vs = vapoursynth.vapoursynth4;

const read = @import("read.zig");

const version = @import("version.zig").version;

export fn VapourSynthPluginInit2(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.configPlugin.?("com.adub.zscene", "zscene", "Scene Change related functions for Vapoursynth", vs.makeVersion(version.major, version.minor), vs.VAPOURSYNTH_API_VERSION, 0, plugin);

    read.registerFunction(plugin, vsapi);
}
