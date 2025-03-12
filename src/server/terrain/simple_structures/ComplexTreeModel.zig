const std = @import("std");

const main = @import("root");
const random = main.random;
const ZonElement = main.ZonElement;
const terrain = main.server.terrain;
const CaveMap = terrain.CaveMap;

const vec = main.vec;
const Vec3d = vec.Vec3d;
const Vec3f = vec.Vec3f;
const Vec3i = vec.Vec3i;

const NeverFailingAllocator = main.heap.NeverFailingAllocator;

const ComplexTreeModel = @This();

pub const id = "cubyz:complex_tree";
pub const generationMode = .floor;

leafBlock: main.blocks.Block,
woodBlock: main.blocks.Block,
topWoodBlock: main.blocks.Block,
stemLength: f32,
longBranchLength: f32,
shortBranchLength: f32,
span: f32,
forky: f32,
variance: f32,
spacing: f32,
// trunk height, verticality, variance, base branch interval
leafBunchWidth: f32,
leafBunchThickness: f32,
leafyDepth: f32, // "leafy margin"?

pub fn loadModel(arenaAllocator: NeverFailingAllocator, parameters: ZonElement) *ComplexTreeModel {
    const self = arenaAllocator.create(ComplexTreeModel);
    self.* = .{
        .leafBlock = main.blocks.parseBlock(parameters.get([]const u8, "leaves", "cubyz:oak_leaves")),
        .woodBlock = main.blocks.parseBlock(parameters.get([]const u8, "log", "cubyz:oak_log")),
        .topWoodBlock = main.blocks.parseBlock(parameters.get([]const u8, "top", "cubyz:oak_top")),
        .stemLength = parameters.get(f32, "stem_length", 5),
        .longBranchLength = parameters.get(f32, "long_branch_length", 5),
        .shortBranchLength = parameters.get(f32, "long_branch_length", 3),
        .span = parameters.get(f32, "span", 20),
        .forky = parameters.get(f32, "forky", 2),
        .variance = parameters.get(f32, "variance", 2),
        .spacing = parameters.get(f32, "spacing", 2),
        .leafBunchWidth = parameters.get(f32, "leaf_bunch_width", 5),
        .leafBunchThickness = parameters.get(f32, "leaf_bunch_depth", 2),
        .leafyDepth = parameters.get(f32, "leafy_depth", 10),
    };
    return self;
}

const Branch = struct {
    previous: *Branch,
    pos: Vec3f,
    hasLeaves: bool,
    rendered: bool,
};

fn hypotSq3(x: anytype, y: anytype, z: anytype) @TypeOf(x) {
    return x*x + y*y + z*z;
}

pub fn generateBranch(branchA: *Branch, branchB: *Branch, chunk: *main.chunk.ServerChunk, block: main.blocks.Block) void {
    // ChatGPT :(
    const af: Vec3i = @intFromFloat(branchA.pos);
    const bf: Vec3i = @intFromFloat(branchB.pos);
    const a = .{ .x = af[0], .y = af[1], .z = af[2] };
    const b = .{ .x = bf[0], .y = bf[1], .z = bf[2] };
    var x = a.x;
    var y = a.y;
    var z = a.z;
    const dx: i32 = @intCast(@abs(b.x - a.x));
    const dy: i32 = @intCast(@abs(b.y - a.y));
    const dz: i32 = @intCast(@abs(b.z - a.z));
    const sx: i32 = if (a.x < b.x) 1 else -1;
    const sy: i32 = if (a.y < b.y) 1 else -1;
    const sz: i32 = if (a.z < b.z) 1 else -1;
    var err1: i32 = undefined;
    var err2: i32 = undefined;
    if (dx >= dy and dx >= dz) {
        err1 = 2 * dy - dx;
        err2 = 2 * dz - dx;
        for (0..@intCast(dx + 1)) |_| {
            if (chunk.liesInChunk(x, y, z)) {
                chunk.updateBlockIfDegradable(x, y, z, block);
            }
            if (err1 > 0) {
                y += sy;
                err1 -= 2 * dx;
            }
            if (err2 > 0) {
                z += sz;
                err2 -= 2 * dx;
            }
            err1 += 2 * dy;
            err2 += 2 * dz;
            x += sx;
        }
    } else if (dy >= dx and dy >= dz) {
        err1 = 2 * dx - dy;
        err2 = 2 * dz - dy;
        for (0..@intCast(dy + 1)) |_| {
            if (chunk.liesInChunk(x, y, z)) {
                chunk.updateBlockIfDegradable(x, y, z, block);
            }
            if (err1 > 0) {
                x += sx;
                err1 -= 2 * dy;
            }
            if (err2 > 0) {
                z += sz;
                err2 -= 2 * dy;
            }
            err1 += 2 * dx;
            err2 += 2 * dz;
            y += sy;
        }
    } else {
        err1 = 2 * dx - dz;
        err2 = 2 * dy - dz;
        for (0..@intCast(dz + 1)) |_| {
            if (chunk.liesInChunk(x, y, z)) {
                chunk.updateBlockIfDegradable(x, y, z, block);
            }
            if (err1 > 0) {
                x += sx;
                err1 -= 2 * dz;
            }
            if (err2 > 0) {
                y += sy;
                err2 -= 2 * dz;
            }
            err1 += 2 * dx;
            err2 += 2 * dy;
            z += sz;
        }
    }
}

// TODO: chunk has voxelSize to worry about
pub fn generate(self: *ComplexTreeModel, x: i32, y: i32, z: i32, chunk: *main.chunk.ServerChunk, _: CaveMap.CaveMapView, seed: *u64, _: bool) void {
    // init branches
    // begin 1 branch vertically
    // 1 + forky n^2
    // n = (span
    var branchDepth: u32 = 1; // "number of branches deep"
    var branchSpan: f32 = 0;
    while (branchSpan < self.span) {
        const delta = self.span - branchSpan;
        if (self.longBranchLength < delta) {
            branchSpan += self.longBranchLength;
        } else if (self.shortBranchLength < delta) {
            branchSpan += self.shortBranchLength;
        } else { break; }
        branchDepth += 1;
    }
    // TODO: ceil forky is overestimated
    // TODO: check this remains true with diff types of branches
    const maxBranches = 1 + 2 * (1 + branchDepth) + @as(u32, @intFromFloat(@ceil(self.forky))) * branchDepth*branchDepth;
    const branches = main.stackAllocator.alloc(Branch, maxBranches);
    defer main.stackAllocator.free(branches);
    branches[0] = .{
        .previous = &branches[0],
        .pos = @floatFromInt(Vec3i{x, y, z}),
        .hasLeaves = false,
        .rendered = true,
    };
    branches[1] = .{
        .previous = &branches[0],
        .pos = @as(Vec3f, @floatFromInt(Vec3i{x, y, z})) + Vec3f{0, 0, self.stemLength},
        .hasLeaves = false,
        .rendered = false,
    };
    defer main.stackAllocator.free(branches);
    // extend/fork/prune branches until leafy depth is reach_able_
    var currentSpan: f32 = 0;
    const nonLeafySpan = self.span - self.leafyDepth;
    var currentBranch: usize = 2;
    var layerStart: usize = 1;
    var layerEnd: usize = 2;
    // make big branches that don't quite get to the leafy margins
    const radius: f32 = self.variance;
    const radius3 = @as(Vec3f, @splat(radius));
    while (currentSpan < nonLeafySpan) {
        var newEnd = layerEnd;
        for (branches[layerStart..layerEnd], 0..) |bud, i| {
            const prev = bud.previous;
            const pDelta = main.vec.normalize(bud.pos - prev.pos) * @as(Vec3f, @splat(self.longBranchLength));
            branches[newEnd] = Branch{
                .previous = &branches[i],
                .pos = bud.pos + pDelta + random.nextFloatVector(3, seed) * @as(Vec3f, @splat(radius*2)) - radius3,
                .hasLeaves = false,
                .rendered = false,
            };
            newEnd += 1;
        }
        const extensions = layerEnd-layerStart;
        const forks: u32 = @intFromFloat(self.forky - 1); // * @as(f32, @floatFromInt(extensions)));
        // randomly add some more branches to the previous layer into this layer
        for (0..forks) |_| {
            // TODO nextIntBounded doesn't like usize
            const i = random.nextInt(u32, seed)%extensions + layerStart;
            const bud = branches[i];
            const prev = bud.previous;
            const pDelta = main.vec.normalize(bud.pos - prev.pos) * @as(Vec3f, @splat(self.longBranchLength));
            branches[newEnd] = Branch{
                .previous = &branches[i],
                .pos = bud.pos + pDelta + random.nextFloatVector(3, seed) * @as(Vec3f, @splat(radius*2)) - radius3,
                .hasLeaves = false,
                .rendered = false,
            };
            newEnd += 1;
        }
        // check and remove overlaps
        for (layerEnd..newEnd) |i| {
            const bud = branches[i];
            var j = i+1;
            while (j < newEnd) : (j += 1) {
                const other = branches[j];
                if (vec.lengthSquare(bud.pos-other.pos) > self.spacing*self.spacing) continue;
                for ((j+1)..newEnd) |k| {
                    branches[k-1] = branches[k];
                }
                newEnd -= 1;
                break;
            }
        }
        layerStart = layerEnd;
        layerEnd = newEnd;
        currentSpan += self.longBranchLength;
    }
    // purely extend+fork minor branches until leafy margin
    // alternatively fork or leaf in leafy margin
    while (currentSpan < self.span) {
        var newEnd = layerEnd;
        var leafChance: f32 = 0.0;
        var forkChance: f32 = 1.0;
        // if it is possible to squeeze in another branch
        if (currentSpan >= self.span - self.leafyDepth - self.shortBranchLength) {
            leafChance = 0.0;
            forkChance = 1.0;
        }
        if (currentSpan >= self.span - self.leafyDepth) {
            forkChance = 1.0;
            leafChance = 1.0;
        }

        const extensions = layerEnd-layerStart;
        const forks: usize = extensions + @as(usize, @intFromFloat(self.forky * forkChance)); // * @as(f32, @floatFromInt(extensions)));
        for (0..forks) |_| {
            const i = random.nextInt(u32, seed)%extensions + layerStart;
            const bud = branches[i];
            const prev = bud.previous;
            const pDelta = main.vec.normalize(bud.pos - prev.pos) * @as(Vec3f, @splat(self.shortBranchLength));
            branches[newEnd] = Branch{
                .previous = &branches[i],
                .pos = bud.pos + pDelta + random.nextFloatVector(3, seed) * @as(Vec3f, @splat(radius*2)) - radius3,
                .hasLeaves = random.nextFloat(seed) < leafChance,
                .rendered = false,
            };
            newEnd += 1;
        }
        // don't worry about overlaps here
        layerStart = layerEnd;
        layerEnd = newEnd;
        currentSpan += self.shortBranchLength;
    }

    currentBranch = layerEnd-1;
    for (branches[0..layerEnd], 0..) |branch, i| {
        if (!branch.hasLeaves) continue;
        const p = branch.previous.*.pos;
        const o = branch.pos;
        const w = self.leafBunchWidth;
        const iw: i32 = @intFromFloat(@ceil(w));
        const d = vec.normalize(Vec3f{0, 0, -2} + vec.normalize(p - o)) * @as(Vec3f, @splat(self.leafBunchThickness));

        const ox: i32 = @intFromFloat(o[0]);
        const oy: i32 = @intFromFloat(o[1]);
        const oz: i32 = @intFromFloat(o[2]);

        var xp = ox-iw;
        while(xp <= ox+iw) : (xp += chunk.super.pos.voxelSize) {
            var yp = oy-iw;
            while(yp <= oy+iw) : (yp += chunk.super.pos.voxelSize) {
                var zp = oz-iw;
                while(zp <= oz+iw) : (zp += chunk.super.pos.voxelSize) {
                    if (!chunk.liesInChunk(xp, yp, zp)) continue;
                    const r1 = hypotSq3(xp - ox, yp - oy, zp - oz);
                    const r2: f32 = hypotSq3(@as(f32, @floatFromInt(xp - ox)) - d[1], @as(f32, @floatFromInt(yp - oy)) - d[1], @as(f32, @floatFromInt(zp - oz)) - d[2]);
                    if (!(r1 < iw*iw and !(r2 < w*w))) continue;
                    chunk.updateBlockIfDegradable(xp, yp, zp, self.leafBlock);
                }
            }
        }
        var previous = &branches[i];
        while (previous != &branches[0]) : (previous = previous.*.previous) {
            if (previous.rendered) break;
            previous.rendered = true;
            // std.debug.print("start {} {} {}\n", .{previous.x, previous.y, previous.z});
            // std.debug.print("stop {} {} {}\n", .{previous.*.previous.x, previous.*.previous.y, previous.*.previous.z});
            generateBranch(previous.*.previous, previous, chunk, self.woodBlock);
        }
    }
}

