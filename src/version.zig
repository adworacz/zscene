const std = @import("std");

// Expose a version that's easily consumable throughout the project.
pub const version = std.SemanticVersion{ .major = 0, .minor = 1, .patch = 0 };
