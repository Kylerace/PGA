const std = @import("std");
const ascii = std.ascii;
const Allocator = std.mem.Allocator;
const time = std.time;
const Timer = time.Timer;
const Random = std.Random;
const comptimePrint = std.fmt.comptimePrint;
const BoundedArray = std.BoundedArray;
const meta = std.meta;
const debug = std.debug;
const ArrayList = std.ArrayList;

const builtin = @import("builtin");

const glfw = @import("mach-glfw");
const gl = @import("gl");

fn errorCallback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    std.log.err("glfw: {}: {s}\n", .{error_code, description});
}

var procs: gl.ProcTable = undefined;

pub fn HyperTreeElement(comptime _d: usize, comptime D: type) type {
    return struct {
        const Self = @This();
        const d: usize = _d;

        data: D,

    };
}

//TODO: GA integration
pub fn HyperSpace(comptime _d: usize, comptime C: type) type {
    return struct {
        const Self = @This();
        const d: usize = _d;

        is_leaf: bool,
        parent: ?*Self,
        children: [std.math.pow(usize, 2, d)]?*Self,
        coords: [d]f64,
        side_length: f64,
        contents: ArrayList(C),
    };
}

pub fn HyperTree(comptime d: usize) type {
    return struct {
        const Self = @This();
        const Node = HyperSpace(d);

        allocator: Allocator,
        nodes: ArrayList(Node),
    };
}

//idk how to do it in general so for now do only nd pga and only points as contents,
//and then later do nd pga with i-dimensional contents


pub fn PGAPointElement(comptime Alg: type, comptime K: type) type {
    return struct {
        const Self = @This();
        const A = Alg;
        const Point = Alg.Point;

        location: Point,
        /// key that consumers of the hypertree can use to interface with it to update our representation of their proxies
        /// or the other way around
        id: K,
    };
}

pub fn PGAPointElementNode(comptime idx_size: type) type {
    return struct {
        const Self = @This();
        
        next: idx_size,
        /// points to our corresponding Element
        element: idx_size
    };
}

pub fn PGAPointHyperNode(comptime idx_size: type) type {
    return struct {
        ///points to our first element if we're a leaf or our first child if we're not
        first: idx_size,
        element_count: i32, //TODO: convert to be signed thats sizeof(idx_size)
    };
}

pub fn PGAPointHyperTree(comptime Alg: type, comptime K: type) type {
    return struct {
        const Self = @This();

        const A = Alg;
        const idx_size: type = u32;
        const dim = A.p;

        const Node = PGAPointHyperNode(Alg, idx_size);
        pub const Element = PGAPointElement(A, K);
        const ElementNode = PGAPointElementNode(idx_size);
        const HyperPlane: type = A.Plane;

        const children_per_split: usize = std.math.pow(usize, 2, dim);

        allocator: Allocator,
        nodes: std.ArrayListUnmanaged(Node),
        elements: std.ArrayListUnmanaged(Element),
        element_nodes: std.ArrayListUnmanaged(ElementNode),
        AABB: [2 * dim]HyperPlane,

        elems_to_split: usize,
        max_depth: usize,

        pub fn init(allocator: Allocator, elems_to_split: usize, max_depth: usize) Self {
            return Self{
                allocator,
                std.ArrayListUnmanaged(Node){},
                std.ArrayListUnmanaged(Element){},
                std.ArrayListUnmanaged(ElementNode){},
                blk: {
                    var hyperplanes: [2 * dim]HyperPlane = undefined;
                    for(0..hyperplanes.len) |i| {
                        _=hyperplanes[i].zeros();
                    }
                    const _hyperplanes = hyperplanes;
                    break :blk _hyperplanes;
                },
                elems_to_split,
                max_depth
            };
        }

        pub fn insert_single(self: *Self, to_insert: Element) !void {
            const ally = self.allocator;

            if(self.nodes.len == 0) {
                if(self.elems_to_split == 0) {
                    var new_nodes: [1 + Self.children_per_split]Node = undefined;
                    
                } else {
                    try self.nodes.append()
                }
                //try self.nodes.append(ally, Node{0,0});

            }
        }
    };
}

pub fn main() !void {

    @setEvalBranchQuota(10000000);
    //const alg = Algebra(3, 0, 1, f64);

    //const context = glfw.createContext();
    try create_program();
}

pub fn create_program() !void {
    glfw.setErrorCallback(errorCallback);
    if(!glfw.init(.{})) {
        debug.print("failed to init GLFW: {any}", .{glfw.getErrorString()});
        std.process.exit(1);
    }
    defer glfw.terminate();

    const window_width: usize = 640;
    const window_height: usize = 480;

    const window = glfw.Window.create(window_width, window_height, "Test", null, null, .{
        .context_version_major = gl.info.version_major,
        .context_version_minor = gl.info.version_minor,

        .opengl_profile = switch(gl.info.api) {
            .gl => .opengl_core_profile,
            .gles => .opengl_any_profile,
            else => comptime unreachable,
        },
        .opengl_forward_compat = gl.info.api == .gl,
    }) orelse {
        debug.print("failed to create a GLFW window: {any}", .{glfw.getErrorString()});
        std.process.exit(1);
    };
    defer window.destroy();

    glfw.makeContextCurrent(window);
    defer glfw.makeContextCurrent(null);

    if(!procs.init(glfw.getProcAddress)) return error.InitFailed;
    gl.makeProcTableCurrent(&procs);
    defer gl.makeProcTableCurrent(null);

    const shader_source_preamble = switch (gl.info.api) {
        .gl => (
            \\#version 410 core
            \\
        ),
        .gles => (
            \\#version 300 es
            \\precision highp float;
            \\
        ),
        else => comptime unreachable,
    };
    const vertex_shader_source =
        \\in vec4 a_Position;
        \\//in vec4 a_Color;
        \\in vec2 tex_coord;
        \\
        \\out vec4 v_Color;
        \\out vec2 tex_coord_0;
        \\
        \\void main() {
        \\    tex_coord_0 = tex_coord;
        \\    gl_Position = a_Position;
        \\    //v_Color = a_Color;
        \\}
        \\
    ;
    const fragment_shader_source =
        \\in vec2 tex_coord_0;
        \\//in vec4 v_Color;
        \\out vec4 f_Color;
        \\uniform sampler2D texture1;
        \\
        \\void main() {
        \\    f_Color = texture(texture1, tex_coord_0);
        \\}
        \\
    ;

    // For the sake of conciseness, this example doesn't check for shader compilation/linking
    // errors. A more robust program would use 'GetShaderiv'/'GetProgramiv' to check for errors.
    const program = create_program: {
        const vertex_shader = gl.CreateShader(gl.VERTEX_SHADER);
        defer gl.DeleteShader(vertex_shader);

        gl.ShaderSource(
            vertex_shader,
            2,
            &[2][*]const u8{ shader_source_preamble, vertex_shader_source },
            &[2]c_int{ @intCast(shader_source_preamble.len), @intCast(vertex_shader_source.len) },
        );
        gl.CompileShader(vertex_shader);

        const fragment_shader = gl.CreateShader(gl.FRAGMENT_SHADER);
        defer gl.DeleteShader(fragment_shader);

        gl.ShaderSource(
            fragment_shader,
            2,
            &[2][*]const u8{ shader_source_preamble, fragment_shader_source },
            &[2]c_int{ @intCast(shader_source_preamble.len), @intCast(fragment_shader_source.len) },
        );
        gl.CompileShader(fragment_shader);

        const program = gl.CreateProgram();

        gl.AttachShader(program, vertex_shader);
        gl.AttachShader(program, fragment_shader);
        gl.LinkProgram(program);

        break :create_program program;
    };
    defer gl.DeleteProgram(program);

    gl.UseProgram(program);
    defer gl.UseProgram(0);

    var vao: c_uint = undefined;
    gl.GenVertexArrays(1, @ptrCast(&vao));
    defer gl.DeleteVertexArrays(1, @ptrCast(&vao));

    gl.BindVertexArray(vao);
    defer gl.BindVertexArray(0);

    var vbo: c_uint = undefined;
    gl.GenBuffers(1, @ptrCast(&vbo));
    defer gl.DeleteBuffers(1, @ptrCast(&vbo));

    gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
    defer gl.BindBuffer(gl.ARRAY_BUFFER, 0);

    const Vertex = extern struct { position: [2]f32, color: [3]f32, texture: [2]f32 };
    // zig fmt: off
    const vertices = [_]Vertex{
        .{ .position = .{  -1.0, -1.0 }, .color = .{ 1, 0, 0 }, .texture = .{1, 1} },
        .{ .position = .{  -1.0 , 1.0 }, .color = .{ 0, 1, 0 }, .texture = .{1, 0}  },
        .{ .position = .{  -1.0, -1.0 }, .color = .{ 0, 0, 1 }, .texture = .{0, 0}  },
        .{ .position = .{   1.0,  1.0 }, .color = .{ 1, 1, 0 }, .texture = .{0, 1}  },
    };
    // zig fmt: on

    gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, gl.STATIC_DRAW);


    debug.print("\nattrib loc (position): {}", .{gl.GetAttribLocation(program, "a_Position")});
    const position_attrib: c_uint = @intCast(gl.GetAttribLocation(program, "a_Position"));
    gl.EnableVertexAttribArray(position_attrib);
    gl.VertexAttribPointer(
        position_attrib,
        @typeInfo(@TypeOf(@as(Vertex, undefined).position)).Array.len,
        gl.FLOAT,
        gl.FALSE,
        @sizeOf(Vertex),
        @offsetOf(Vertex, "position"),
    );
    debug.print("\nattrib loc (color): {}", .{gl.GetAttribLocation(program, "a_Color")});
    debug.print("\nattrib loc (tex_coord): {}", .{gl.GetAttribLocation(program, "tex_coord")});


    //const color_attrib: c_uint = @intCast(gl.GetAttribLocation(program, "a_Color"));
    //gl.EnableVertexAttribArray(color_attrib);
    //gl.VertexAttribPointer(
    //    color_attrib,
    //    @typeInfo(@TypeOf(@as(Vertex, undefined).color)).Array.len,
    //    gl.FLOAT,
    //    gl.FALSE,
    //    @sizeOf(Vertex),
    //    @offsetOf(Vertex, "color"),
    //);

    var texture_attrib: c_uint = @intCast(gl.GetAttribLocation(program, "tex_coord"));
    gl.EnableVertexAttribArray(texture_attrib);
    gl.VertexAttribPointer(
        texture_attrib,
        @typeInfo(@TypeOf(@as(Vertex, undefined).texture)).Array.len,
        gl.FLOAT,
        gl.FALSE,
        @sizeOf(Vertex),
        @offsetOf(Vertex, "texture"),
    );

    var sing_ptr = &texture_attrib;
    const arr_ptr = sing_ptr[0..1];
    const many_ptr: [*]c_uint = arr_ptr;
    gl.GenTextures(1, many_ptr);
    gl.BindTexture(gl.TEXTURE_2D, texture_attrib);

    const color_channels: usize = 4;

    var cpu_pixel_buffer: [window_width * window_height * color_channels]u8 = undefined;
    for(0..cpu_pixel_buffer.len) |i| {
        cpu_pixel_buffer[i] = 255;
    }

    var camera_pos: [4]f64 = undefined;
    for(0..4) |i| {
        camera_pos[i] = 0.0;
    }



    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, window_width, window_height, 0, gl.RGBA, gl.UNSIGNED_BYTE, &cpu_pixel_buffer);
    gl.Uniform1i(gl.GetUniformLocation(program, "texture1"), 0);

    main_loop: while (true) {
        glfw.waitEvents();
        if (window.shouldClose()) break :main_loop;

        // Update the viewport to reflect any changes to the window's size.
        const fb_size = window.getFramebufferSize();
        gl.Viewport(0, 0, @intCast(fb_size.width), @intCast(fb_size.height));



        // Clear the window.
        //gl.ClearBufferfv(gl.COLOR, 0, &[4]f32{ 1, 1, 1, 1 });

        // Draw the vertices.
        gl.ClearColor(0.0,0.0,0.0,1.0);

        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, window_width, window_height, 0, gl.RGBA, gl.UNSIGNED_BYTE, &cpu_pixel_buffer);
        gl.GenerateMipmap(gl.TEXTURE_2D);


        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);	// set texture wrapping to GL_REPEAT (default wrapping method)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        // set texture filtering parameters
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

        gl.BindTexture(gl.TEXTURE_2D, texture_attrib);
        //glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
        gl.DrawArrays(gl.TRIANGLES, 0, vertices.len);
        
        // Perform some wizardry that prints a nice little message in the center :)
        //gl.Enable(gl.SCISSOR_TEST);
        //const magic: u154 = 0x3bb924a43ddc000170220543b8006ef4c68ad77;
        //const left = @divTrunc(@as(gl.int, @intCast(fb_size.width)) - 11 * 8, 2);
        //const bottom = @divTrunc((@as(gl.int, @intCast(fb_size.height)) - 14 * 8) * 2, 3);
        //var i: gl.int = 0;
        //while (i < 154) : (i += 1) {
        //    if (magic >> @intCast(i) & 1 != 0) {
        //        gl.Scissor(left + @rem(i, 11) * 8, bottom + @divTrunc(i, 11) * 8, 8, 8);
        //        gl.ClearBufferfv(gl.COLOR, 0, &[4]f32{ 0, 0, 0, 1 });
        //    }
        //}
        //gl.Disable(gl.SCISSOR_TEST);

        window.swapBuffers();
    }

    //try test_stuff();
}

pub fn test_stuff() !void {
    const stdout = std.io.getStdOut().writer();

    //const target = std.Target.zigTriple(target: Target, allocator: Allocator)
    //try stdout.print("")

    //try stdout.print("test");
    @setEvalBranchQuota(10000000);
    const alg = Algebra(3, 0, 1, f64);
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer _ = arena.deinit();
    const table_format: []const alg.RowFormat = &.{alg.RowFormat{}}; //, alg.RowFormat{.blade_fmt = .binary_no_e, .nonzero_scalars_as_blade = true}};
    const ptr = try alg.get_cayley_table(allocator, &alg.gp_cayley, table_format);
    try stdout.print("Algebra Signature: ({},{},{}):\nGeometric Product:\n{s}\n", .{ alg.p, alg.n, alg.z, ptr });
    const ptr1 = try alg.get_cayley_table(allocator, &alg.op_cayley, table_format);
    try stdout.print("Outer Product:\n{s}\n", .{ptr1});

    const ptr2 = try alg.get_cayley_table(allocator, &alg.ip_cayley, table_format);
    try stdout.print("Inner Product:\n{s}\n", .{ptr2});
    const ptr3 = try alg.get_cayley_table(allocator, &alg.rp_cayley, table_format);
    try stdout.print("Regressive Product:\n{s}\n", .{ptr3});

    const NVec = alg.NVec;

    var buffer: [alg.basis_len * 8 * 1000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const fba_alloc = fba.allocator();

    const obj_pool: []NVec = try fba_alloc.alloc(NVec, 10);
    defer fba_alloc.free(obj_pool);

    const fst: *NVec = obj_pool[0].zeros();
    fst.terms[0b0000] = 1.2;
    fst.terms[0b0010] = 3.0;
    fst.terms[0b1000] = 1.0;
    fst.terms[0b0110] = 5.1;
    fst.terms[0b1100] = -5.2;
    fst.terms[0b1011] = -4.1;
    const snd: *NVec = obj_pool[1].zeros();
    snd.terms[0b0000] = 2.5;
    snd.terms[0b0001] = 0.5;
    snd.terms[0b0010] = 1.0;
    snd.terms[0b1111] = 0.5;
    snd.terms[0b1001] = 2.3;

    const third: *NVec = obj_pool[2].zeros();
    _ = fst.gp(snd, third);

    try stdout.print("{} gp {} = {}\n", .{ fst, snd, third });
    //51: .LBB5_69
    _ = third.zeros();

    _ = fst.gp(snd, third).add(fst, third);

    try stdout.print("({} gp {}) + {} = {}\n", .{ fst, snd, fst, third });
    //57: .LBB5_79: same add, same commands but slightly different offsets
    //_=fst.gp_get(snd, .ptr, .{.ptr=third}).add(fst, .ptr, .{.ptr=third});

    //try stdout.print("{} gp_get {} + {} = {}\n", .{fst, snd, fst, third});

    const frth: *NVec = obj_pool[3].zeros();
    _ = fst.ip(snd, frth);
    try stdout.print("{} ip {} = {}\n", .{ fst, snd, frth });
    try stdout.print("mag of {} is {}", .{ fst, fst.magnitude() });
    //try stdout.print("{s}", .{alg._op_string});

    //try stdout.print("NVec.Blade: {}", .{NVec.Blade.e2});

    //const whatever = NVec.Blade.@"e2";

    //try stdout.print("std.meta.stringToEnum(NVec.Blade, e2) = {?}", .{std.meta.stringToEnum(NVec.Blade, "e2")});
    //try stdout.print("\nfst.get(.e3) = {d}", .{fst.get(.stack, .e3)});
    //fst.get(.ptr,.e3).* = 2.0;

    //try stdout.print("\nfst.get(.e3) after changing = {d}", .{fst.get(.stack, .e3)});

    const Motor = alg.Motor;
    const mtr: *Motor = try allocator.create(Motor);
    _ = mtr.zeros();
    mtr.terms[0] = 1.0;
    mtr.terms[1] = 2.3;
    mtr.terms[2] = 0.21;
    mtr.terms[3] = 1.5;
    const add_res: *NVec = try allocator.create(NVec);
    _ = add_res.zeros();
    fst.get(.ptr, .e0).* = 1.2;
    fst.get(.ptr, .e1).* = 0.17;
    fst.get(.ptr, .e2).* = 31.4;
    fst.get(.ptr, .e3).* = 15.6;
    try stdout.print("\nmotor terms length {}, motor {} + mvec {} = {}", .{ Motor.num_terms, mtr, fst, mtr.add(fst, add_res) });

    try stdout.print("\nNVec subset: {b}, our_idx_to_blade: {b}", .{ NVec.subset_field, NVec.our_idx_to_blade });
    try stdout.print("\nMotor subset: {b}, our_idx_to_blade: {b}", .{ Motor.subset_field, Motor.our_idx_to_blade });

    //try benchmark(stdout, allocator);

    const gp_res: *NVec = try allocator.create(NVec);
    _ = gp_res.zeros();

    const op_l: *NVec = try allocator.create(NVec);
    _ = op_l.zeros();

    op_l.terms[3] = 1.235;
    op_l.terms[5] = -5.1;

    const op_r: *NVec = try allocator.create(NVec);
    _ = op_r.zeros();

    op_r.terms[1] = 3.12;
    op_r.terms[3] = 4.2;
    op_r.terms[6] = -2.1;

    //NVec.gp_op(fst, snd, gp_res);
    //const xie = std.builtin.CallModifier;
    _ = @call(.never_inline, NVec.gp, .{ op_l, op_r, gp_res });
    try stdout.print("\ngp op: {} * {} = {}", .{ op_l, op_r, gp_res });

    //try benchmark(stdout, allocator);

    const blankie = try allocator.create(NVec);
    _ = blankie.zeros();

    try stdout.print("\n{} dual = {}", .{ op_r, op_r.dual(blankie) });

    const mot: *Motor = try allocator.create(Motor);
    _ = mot.zeros();
    mot.terms[0] = 1;
    mot.terms[1] = 3.1;

    const sand_res = mot.sandwich(op_l);
    try stdout.print("\n{} >>> {} = {}", .{mot, op_l, sand_res});

    mot.terms[2] = -2.13;
    mot.terms[1] = 9.1;
    mot.terms[3] = 6.7;

    const sand_res2 = mot.sandwich(op_l);
    try stdout.print("\n{d:<.3} >>> {d:<.3} = {d:<.3}", .{mot, op_l, sand_res2});

    const PRNG = Random.DefaultPrng;
    var rnd = PRNG.init(4);
    var rnd2 = rnd.random();

    const Bivector = alg.KVector(2);

    for(0..10) |_| {

        const sand_meat_2: *NVec = try allocator.create(NVec);
        defer allocator.destroy(sand_meat_2);
        _=sand_meat_2.zeros().randomize(&rnd2, 1.0,0.0, 3);
        _=mot.zeros().randomize(&rnd2, 1.0,0.0, 3);
        _=mot.normalize(.ptr, .{.ptr=mot});

        const sand_res_rand = mot.sandwich(sand_meat_2);
        try stdout.print("\n{d:<.3} >>> {d:<.3} = {d:<.3}", .{mot, sand_meat_2, sand_res_rand});

        const biv: *Bivector = try allocator.create(Bivector);
        _=biv.zeros().randomize(&rnd2, 1.0, 0.0, 2);
        //debug.print("\n_____biv is {} before norm, mag is {}", .{biv, biv.magnitude()});
        _=biv.normalize(.ptr,.{.ptr=biv});

        //debug.print("\n_____biv is {} after norm", .{biv});

        const exp_res = biv.exp(15);
        try stdout.print("\n\te ^ {d:<.3} = {d:<.3}", .{biv, exp_res});
    }




}

pub fn benchmark(stdout: anytype, allocator: Allocator) !void {
    var gp_normal_avg_throughput: f128 = 0.0;
    var gp_better_avg_throughput: f128 = 0.0;
    var gp_rolled_avg_throughput: f128 = 0.0;
    var gp_inv_avg_throughput: f128 = 0.0;

    var gp_normal_iters: u128 = 0;
    var gp_better_iters: u128 = 0;
    var gp_rolled_iters: u128 = 0;
    var gp_inv_iters: u128 = 0;

    const length_milliseconds = 200;

    const max_p = 5;

    const algs: [max_p]type = comptime blk: {
        var algies: [max_p]type = undefined;
        for (1..max_p + 1) |i| {
            algies[i - 1] = Algebra(i, 0, 1, f64);
        }
        break :blk algies;
    };

    const nvecs: [max_p]type = comptime blk: {
        var nvies: [max_p]type = undefined;
        for (1..max_p + 1) |i| {
            nvies[i - 1] = algs[i - 1].NVec;
        }
        break :blk nvies;
    };

    inline for (1..max_p + 1) |p| {
        gp_normal_avg_throughput = 0.0;
        gp_better_avg_throughput = 0.0;
        gp_rolled_avg_throughput = 0.0;
        gp_inv_avg_throughput = 0.0;

        //const alg2 = algs[p-1];
        const nvec = nvecs[p - 1];

        const perf_pool: []nvec = try allocator.alloc(nvec, 1000);
        for (0..100) |_| {
            var timer: Timer = Timer.start() catch unreachable;

            while (timer.read() / 1_000_000 < length_milliseconds) {
                for (0..50) |_| {
                    for (0..perf_pool.len) |j| {
                        const m = &perf_pool[j];
                        _ = m.gp(&perf_pool[(j + 1) % perf_pool.len], &perf_pool[(j -% 1) % perf_pool.len]);
                    }
                }
                gp_normal_iters += 1;
            }

            gp_normal_avg_throughput = 0.5 * gp_normal_avg_throughput + 0.5 * @as(f128, @floatFromInt(gp_normal_iters)) * 50.0 * @as(f128, @floatFromInt(perf_pool.len)) / @as(f128, @floatFromInt(length_milliseconds));
            gp_normal_iters = 0;
            timer.reset();

            while (timer.read() / 1_000_000 < length_milliseconds) {
                for (0..50) |_| {
                    for (0..perf_pool.len) |j| {
                        const m = &perf_pool[j];
                        _ = m.gp_better(&perf_pool[(j + 1) % perf_pool.len], .ptr, .{ .ptr = &perf_pool[(j -% 1) % perf_pool.len] });
                    }
                }
                gp_better_iters += 1;
            }

            gp_better_avg_throughput = 0.5 * gp_better_avg_throughput + 0.5 * @as(f128, @floatFromInt(gp_better_iters)) * 50.0 * @as(f128, @floatFromInt(perf_pool.len)) / @as(f128, @floatFromInt(length_milliseconds));
            gp_better_iters = 0;
            timer.reset();

            while (timer.read() / 1_000_000 < length_milliseconds) {
                for (0..50) |_| {
                    for (0..perf_pool.len) |j| {
                        const m = &perf_pool[j];

                        _ = m.gp_not_unrolled(&perf_pool[(j + 1) % perf_pool.len], .ptr, .{ .ptr = &perf_pool[(j -% 1) % perf_pool.len] });
                    }
                }
                gp_rolled_iters += 1;
            }

            gp_rolled_avg_throughput = 0.5 * gp_rolled_avg_throughput + 0.5 * @as(f128, @floatFromInt(gp_rolled_iters)) * 50.0 * @as(f128, @floatFromInt(perf_pool.len)) / @as(f128, @floatFromInt(length_milliseconds));
            gp_rolled_iters = 0;
            timer.reset();

            while (timer.read() / 1_000_000 < length_milliseconds) {
                for (0..50) |_| {
                    for (0..perf_pool.len) |j| {
                        const m = &perf_pool[j];

                        _ = m.gp_inv(&perf_pool[(j + 1) % perf_pool.len], .ptr, .{ .ptr = &perf_pool[(j -% 1) % perf_pool.len] });
                    }
                }
                gp_inv_iters += 1;
            }

            gp_inv_avg_throughput = 0.5 * gp_inv_avg_throughput + 0.5 * @as(f128, @floatFromInt(gp_inv_iters)) * 50.0 * @as(f128, @floatFromInt(perf_pool.len)) / @as(f128, @floatFromInt(length_milliseconds));
            gp_inv_iters = 0;
            timer.reset();
        }

        try stdout.print("\nalgebra({},0,1): sparse vectorized gp() got {:.4} avg calls / ms, unrolled reordered gp() got {:.4} avg calls / ms, unrolled (no table lookup) gp_better() got {:.4} avg calls / ms, non inlined (w/ table lookup) gp_rolled() got {:.4} avg calls / ms", .{ p, gp_normal_avg_throughput, gp_inv_avg_throughput, gp_better_avg_throughput, gp_rolled_avg_throughput });
        //return;
    }
}

inline fn is_comptime(val: anytype) bool {
    return @typeInfo(@TypeOf(.{val})).Struct.fields[0].is_comptime;
}

pub fn factorial(n: anytype) @TypeOf(n) {
    var result: @TypeOf(n) = 1;
    var k: @TypeOf(n) = n;
    while (k > 1) {
        result *= k;
        k -= 1;
    }
    //for (2..n+1) |k| {
    //    result *= k;
    //}
    return result;
}

pub fn n_choose_k(n: anytype, k: @TypeOf(n)) @TypeOf(n) {
    return factorial(n) / (factorial(k) * factorial(n - k));
}

/// assumes all elements are distinct
/// also assumes T is an integer type, signed or unsigned
pub fn cycle_sort_ret_writes(T: anytype, slice: []T) usize {
    var cycle_elements: usize = 0;
    var cycles: usize = 0;
    for (0..slice.len) |cycle_start| {
        var item = slice[cycle_start];
        var pos = cycle_start;
        //everything behind us is definitely sorted, some things ahead of us may be sorted
        for (slice[cycle_start + 1 .. slice.len]) |ahead| {
            if (ahead < item) {
                pos += 1;
            }
        }

        if (pos != cycle_start) {
            cycles += 1;
            //cycle_elements += 1;
        }

        //if correct and real pos's are different, then there is a cycle of some length that includes item and the item_at_correct_pos's pos
        //and item_at_correct_pos's_correct_pos and so on until item_at_correct_pos's_correct_pos's..._correct_pos = pos
        //all cycles are disjoint, and the number of writes is the sum of the length of each cycle - number of cycles
        while (pos != cycle_start) {
            //writes += 1;
            pos = cycle_start;
            for (slice[cycle_start + 1 .. slice.len]) |ahead| {
                if (ahead < item) {
                    pos += 1;
                }
            }

            cycle_elements += 1;

            const swapped_item = slice[pos];
            slice[pos] = item;
            item = swapped_item;
        }
    }
    return cycle_elements - cycles;
}

fn count_bits(v: anytype) @TypeOf(v) {
    var val = v;
    var count: @TypeOf(v) = 0;
    //var parity: bool = false;
    while (val != 0) {
        //parity = !parity;
        count += 1;
        val &= val - 1;
    }
    //var t = v >> 1;
    //t ^= t >> 1;
    //t ^= t >> 2;
    //t ^= t >> 4;
    //t ^= t >> 8;
    //t ^= t >> 16;
    //t ^= t >> 32;
    //@compileLog(comptimePrint("count_bits({b}) = {}", .{ v, t }));
    //return t;
    return count;
}

///outputs a vector as a mask for @shuffle() that aligns a subset packed array with a superset array
/// it selects the next subset idx if it aligns with the superset and selects against it if it doesnt
/// TODO: this might also work if sbset is partially disjoint with superset
fn subset_align_with_superset_shuffle_mask(comptime sbset: usize, comptime superset: usize, comptime select_against: enum { to_neg_1, decr }) @Vector(count_bits(superset), i32) {
    var len: usize = count_bits(superset);
    //var subset_len: usize = count_bits(sbset);
    var ret = @Vector(len, i32){0} ** len;

    //array indices
    var superset_idx = 0;
    var sbset_idx = 0;

    var bit_index = 0;
    var select_against_idx = -1;

    //iterate bit_index until you find a 1 in superset, that will be superset's first array element
    // super set:
    //0b10110110001101
    //  7 65 43   21 0
    // = {0,1,2,3,4,5,6,7}

    // subset:
    //0b10110010000100
    //  4 32  1    0
    // = {0,1,2,3,4}
    //aligns with {1,3,5,6,7}
    //output @Vector(_,i32){s,0,s,1,s,2,3,4}
    //where s = something determined by the value of select_against
    //then with the output a caller than wants to zero fill unaligned components can then do
    // @shuffle(T, subset.terms, zero_mask, @subset_align_with_superset_shuffle_mask(subset_type.subset, dest_type.subset, .to_neg_1))
    // to create something that can just be added to superset.terms
    //ret must align with superset's array

    //const one: usize = 0b1;
    while (len > 0) { //the bitfields are aligned, but we need to count array indices (mapping from set elems to natural numbers)
        defer bit_index += 1;
        const in_superset: bool = (superset >> bit_index) & 0b1 != 0;
        const in_subset: bool = (sbset >> bit_index) & 0b1 != 0;

        if (in_superset == false) {
            continue;
        }

        if (in_subset) {
            ret[superset_idx] = sbset_idx;
            sbset_idx += 1;
        } else {
            ret[superset_idx] = select_against_idx;
            if (select_against == .decr) {
                select_against_idx -= 1;
            }
        }

        superset_idx += 1;
        len -= 1;
    }

    return ret;
}

//fn bitfield_to_vector_shuffle_mask(comptime superset: usize, comptime sbset: usize) @Vector(count_bits(superset), i32) {
//    const len: usize = count_bits(superset);
//    var ret = @Vector(len, )
//}

//we want 1 for an odd number of 1's, 0 for an even number of 1's (even parity)
//given that we need to map +1->-1 = 1111... and 0->+1 = 0b000...01
//0b000...01 -> 1111..., 0b000... -> 0b000...01
//NOT: ~0b0...01 -> 0b11...10 + 1 will work here, ~0b000... -> 0b111... +2 w/ overflow will work here
//val = ~even_parity(lhs & rhs) + 1 + even_parity(lhs & rhs) & 1
//so flip_value = ~even_parity(lhs & rhs) += 1 + flip_value & 1

fn count_flips(left: anytype, rhs: anytype) @TypeOf(left) {
    var lhs = left >> 1;
    var flips: @TypeOf(left) = 0;
    while (lhs != 0) {
        flips += count_bits(lhs & rhs);
        lhs >>= 1;
    }
    //flips += count_bits((left >> (1 + i)) + rhs)
    return flips;
}
fn flips_value(left: usize, rhs: usize) isize {
    var lhs = left >> 1;
    var val: isize = 1;
    while (lhs != 0) {
        //val = val * (1 - 2 * (count_bits(lhs & rhs) & 1));
        val = (val + @as(isize, @bitCast(count_bits(lhs & rhs) & 1))) & 1;
        lhs >>= 1;
    }
    return 1 - 2 * val;
}

fn flips_value_parity(left: usize, rhs: usize, comptime d: comptime_int) isize {
    var lhs = left >> 1;
    var val: isize = 1;
    while (lhs != 0) {
        //val = val * (1 - 2 * (count_bits(lhs & rhs) & 1));
        val &= @intCast(even_parity(lhs & rhs, d) & 1);
        lhs >>= 1;
    }
    return @as(isize, @intCast(1 - 2 * val));
}

fn even_parity(field: usize, comptime d: comptime_int) usize {
    if (d > 64) {
        @compileError("even_parity() doesnt support field sizes greater than 64 bits");
    }
    if (d == 64) {
        field ^= field >> 32;
    }
    if (d >= 32) {
        field ^= field >> 16;
    }
    if (d >= 16) {
        field ^= field >> 8;
    }
    if (d <= 8) {
        const hex_coeff: usize = 0x0101010101010101;
        const hex_andeff: usize = 0x8040201008040201;
        return (((field * hex_coeff) & hex_andeff) % 0x1FF) & 1;
    }
    field ^= field >> 4;
    field &= 0xf;
    return (0x6996 >> field) & 1;
}

fn cosh(num: anytype) @TypeOf(num) {
    return 0.5 * (@exp(num) + @exp(-num));
}

fn sinh(num: anytype) @TypeOf(num) {
    return 0.5 * (@exp(num) - @exp(-num));
}

//fn Foo<T>(arg: T) {
//return arg * 2;
//}

const AlgebraOptions: type = struct {
    const Self = @This();
    /// affects whether 1 & 2 forms are 1 & 2 dimensional or d-1 and d-2 dimensional,
    /// and whether wedge = join or meet
    dual: bool,

};

fn Algebra(comptime _p: usize, comptime _n: usize, comptime _z: usize, comptime T: type, comptime algebra_options: AlgebraOptions) type {
    const _d: usize = _p + _n + _z;
    const basis_size: usize = std.math.pow(usize, 2, _d);

    const bin_basis: [basis_size]usize = comptime blk: {
        var ret: [basis_size]usize = undefined;
        for (0..basis_size) |blade| {
            ret[blade] = blade;
        }
        break :blk ret;
    };
    //_ = bin_basis;
    //we need the 1blade squaring masks

    //var bin_cayley_table

    //scalar field
    //basis[0] = .{ 1, true, 0, .{0 ** _d} };
    //

    var z_bits = _z;
    var p_bits = _p;
    var n_bits = _n;

    //var curr_bit = 0;
    var _zero_mask: usize = 0;
    var _pos_mask: usize = 0;
    var _neg_mask: usize = 0;

    for (0.._d) |b| { // bitfield gen
        if (z_bits > 0) {
            z_bits -= 1;
            _zero_mask |= (0b1 << b);
        } else if (p_bits > 0) {
            p_bits -= 1;
            _pos_mask |= (0b1 << b);
        } else if (n_bits > 0) {
            n_bits -= 1;
            _neg_mask |= (0b1 << b);
        }
    }

    const zero_mask: usize = _zero_mask;
    const pos_mask: usize = _pos_mask;
    const neg_mask: usize = _neg_mask;

    //@compileLog("zero, pos, neg: ", zero_mask, pos_mask, neg_mask, "0b10000:", 0b10000, "count_bits(0b1001):", count_bits(0b1001), "count_flips(e12 = 0b0011, e1 = 0b0001):", count_flips(0b0011, 0b0001));

    const BinBlade = struct { value: isize, blade: usize };

    const ProdTerm = struct { mult: T, left_blade: usize, right_blade: usize };

    @setEvalBranchQuota(1000000);

    var bin_gp_cayley_table: [basis_size][basis_size]BinBlade = .{.{.{ .value = 0, .blade = 0 }} ** basis_size} ** basis_size;
    var bin_op_cayley_table: [basis_size][basis_size]BinBlade = .{.{.{ .value = 0, .blade = 0 }} ** basis_size} ** basis_size;
    var bin_ip_cayley_table: [basis_size][basis_size]BinBlade = .{.{.{ .value = 0, .blade = 0 }} ** basis_size} ** basis_size;
    var bin_rp_cayley_table: [basis_size][basis_size]BinBlade = .{.{.{ .value = 0, .blade = 0 }} ** basis_size} ** basis_size;

    //array {blade idx = {{lhs blade that produces this, rhs blade that produces this}, ...}, ...}
    var bin_gp_cayley_table_inverse: [basis_size][basis_size]ProdTerm = .{.{.{ .mult = 1.0, .left_blade = basis_size + 1, .right_blade = basis_size + 1 }} ** basis_size} ** basis_size;
    var bin_op_cayley_table_inverse: [basis_size][basis_size]ProdTerm = .{.{.{ .mult = 1.0, .left_blade = basis_size + 1, .right_blade = basis_size + 1 }} ** basis_size} ** basis_size;
    var bin_ip_cayley_table_inverse: [basis_size][basis_size]ProdTerm = .{.{.{ .mult = 1.0, .left_blade = basis_size + 1, .right_blade = basis_size + 1 }} ** basis_size} ** basis_size;
    var bin_rp_cayley_table_inverse: [basis_size][basis_size]ProdTerm = .{.{.{ .mult = 1.0, .left_blade = basis_size + 1, .right_blade = basis_size + 1 }} ** basis_size} ** basis_size;

    var gp_inv_idx: [basis_size]usize = .{0} ** basis_size;
    var op_inv_idx: [basis_size]usize = .{0} ** basis_size;
    var ip_inv_idx: [basis_size]usize = .{0} ** basis_size;
    var rp_inv_idx: [basis_size]usize = .{0} ** basis_size;

    const pseudoscalar_blade: isize = comptime blk: {
        var val: usize = 0;
        for (0.._d) |i| {
            val |= (1 << i);
        }
        break :blk val;
    };

    for (0..basis_size) |lhs| {
        for (0..basis_size) |rhs| {
            const squares: usize = lhs & rhs;

            const lhsI: isize = lhs ^ pseudoscalar_blade;
            const rhsI: isize = rhs ^ pseudoscalar_blade;
            const dual_squares: isize = lhsI & rhsI;
            if (dual_squares == 0) {

                //const ineg_mask: isize = @bitCast(neg_mask);
                //const lhsI_value: isize = -2 * (((@as(isize, @bitCast(lhs)) & pseudoscalar_blade & ineg_mask) ^ count_flips(lhs, pseudoscalar_blade)) & 1) + 1;
                //const rhsI_value: isize =  -2 * (((@as(isize, @bitCast(rhs)) & pseudoscalar_blade & ineg_mask) ^ count_flips(rhs, pseudoscalar_blade)) & 1) + 1;

                const dual_blade: isize = lhsI ^ rhsI ^ pseudoscalar_blade;
                const dual_value: isize = (-2 * (((lhsI & rhsI & @as(isize, @bitCast(neg_mask))) ^ count_flips(lhsI, rhsI)) & 1) + 1);
                //if(dual_value != dual_value / (lhsI_value * rhsI_value)) {
                //    @compileLog("dual value ", dual_value, " != ", dual_value / (lhsI_value * rhsI_value), " for lhs and rhs: ", lhsI_value, rhsI_value);
                //}

                bin_rp_cayley_table[lhs][rhs] = .{ .value = dual_value, .blade = @bitCast(dual_blade) };

                bin_rp_cayley_table_inverse[@bitCast(dual_blade)][rp_inv_idx[@bitCast(dual_blade)]] = .{ .mult = bin_rp_cayley_table[lhs][rhs].value, .left_blade = lhs, .right_blade = rhs };
                rp_inv_idx[@bitCast(dual_blade)] += 1;
            }

            if (squares & zero_mask != 0) {
                continue;
            }
            const flips = count_flips(lhs, rhs);

            const negative_powers_mod_2: isize = (((squares & neg_mask) ^ flips) & 1);
            const value: isize = -2 * negative_powers_mod_2 + 1;
            //@bitCast(@as(u8,@truncate((((squares & neg_mask) ^ flips) & 1) << 7)));
            const gp_blade: usize = lhs ^ rhs; //xor = or == true, and not and == true
            //@compileLog("lhs: ", lhs, "rhs: ", rhs, "value:", value, "blade:", blade);
            bin_gp_cayley_table[lhs][rhs] = .{ .value = value, .blade = gp_blade };
            bin_gp_cayley_table_inverse[gp_blade][gp_inv_idx[gp_blade]] = .{ .mult = value, .left_blade = lhs, .right_blade = rhs };
            gp_inv_idx[gp_blade] += 1;
            //if the two blades have no common non scalar factors then they get turned to 0
            const ul = lhs & gp_blade; //lhs & ((lhs | rhs) & ~(lhs & rhs))
            const ur = rhs & gp_blade;
            bin_ip_cayley_table[lhs][rhs] = .{ .value = if (ul == 0 or ur == 0) value else 0, .blade = gp_blade };

            bin_ip_cayley_table_inverse[gp_blade][ip_inv_idx[gp_blade]] = .{ .mult = bin_ip_cayley_table[lhs][rhs].value, .left_blade = lhs, .right_blade = rhs };
            ip_inv_idx[gp_blade] += 1;

            if (squares == 0) {
                bin_op_cayley_table[lhs][rhs] = .{ .value = if (flips & 1) -1 else 1, .blade = gp_blade };
                bin_op_cayley_table_inverse[gp_blade][op_inv_idx[gp_blade]] = .{ .mult = bin_op_cayley_table[lhs][rhs].value, .left_blade = lhs, .right_blade = rhs };
                op_inv_idx[gp_blade] += 1;
            }
        }
    }

    //every element of the alg is a subset of the elements of a full multivector
    //they have a dynamic terms array of d elements alongside a constant array of mappings to
    //the indices of the full multivector,
    //and a static terms array of s elements (alongside a constant array of mappings to
    //the indices of a full multivector) representing the terms the MVecSubset keeps as
    //a constant value that isnt stored in the dynamic array.
    //the length of the dynamic and static term arrays must equal the length of the dynamic
    //array of the full multivector of the algebra, which must equal the basis_size of the algebra

    //for example, i can create a MVecSubset(dynamic grades 1 and 2, index 0 is value 1)
    //which for 3d PGA represents a dynamic array of terms of all grade 1 and 2 basis k-vectors
    //and a static term array where the scalar term is value 1 and all other terms not in
    //the dynamic array are value 0.
    const _bin_gp_cayley_table = bin_gp_cayley_table;
    const _bin_op_cayley_table = bin_op_cayley_table;
    const _bin_ip_cayley_table = bin_ip_cayley_table;
    const _bin_rp_cayley_table = bin_rp_cayley_table;

    const _bin_gp_cayley_table_inv = bin_gp_cayley_table_inverse;
    const _bin_op_cayley_table_inv = bin_op_cayley_table_inverse;
    const _bin_ip_cayley_table_inv = bin_ip_cayley_table_inverse;
    const _bin_rp_cayley_table_inv = bin_rp_cayley_table_inverse;

    const alg = struct {
        pub const Alg = @This();
        pub const D = T;
        pub const p: usize = _p;
        pub const n: usize = _n;
        pub const z: usize = _z;
        pub const d: usize = _d;
        pub const basis: [basis_len]BinBlade = bin_basis;
        pub const basis_len: usize = basis_size;
        pub const alg_options = algebra_options;

        ///runtime int needed to fit a single blade
        pub const ud: type = std.math.IntFittingRange(0, basis_len - 1);
        ///runtime int needed to fit our maximum subset
        pub const ux: type = std.math.IntFittingRange(0, std.math.pow(u128, 2, basis_len) - 1);

        pub const mask_zero = zero_mask;
        pub const mask_pos = pos_mask;
        pub const mask_neg = neg_mask;

        pub const KnownSignatures = enum {
            PGAnd,
            CGAnd,
            VGAnd,
            STA,
            STAP,
            None,
        };
        pub const signature_name = blk: {
            if (z == 1 and n == 0 and p > 0) {
                break :blk KnownSignatures.PGAnd;
            }
            if (n == 1 and z == 0 and p > 0) {
                break :blk KnownSignatures.CGAnd;
            }
            if (z == 0 and n == 0 and p > 0) {
                break :blk KnownSignatures.VGAnd;
            }
        };

        pub const gp_cayley: [basis_len][]const BinBlade = blk: {
            var arr: [basis_size][]const BinBlade = undefined;
            for (0..basis_size) |i| {
                arr[i] = _bin_gp_cayley_table[i][0.._bin_gp_cayley_table.len];
            }
            break :blk arr;
        };
        pub const op_cayley: [basis_len][]const BinBlade = blk: {
            var arr: [basis_size][]const BinBlade = undefined;
            for (0..basis_size) |i| {
                arr[i] = _bin_op_cayley_table[i][0.._bin_op_cayley_table.len];
            }
            break :blk arr;
        };
        pub const ip_cayley: [basis_len][]const BinBlade = blk: {
            var arr: [basis_size][]const BinBlade = undefined;
            for (0..basis_size) |i| {
                arr[i] = _bin_ip_cayley_table[i][0.._bin_ip_cayley_table.len];
            }
            break :blk arr;
        };
        pub const rp_cayley: [basis_len][]const BinBlade = blk: {
            var arr: [basis_size][]const BinBlade = undefined;
            for (0..basis_size) |i| {
                arr[i] = _bin_rp_cayley_table[i][0.._bin_rp_cayley_table.len];
            }
            break :blk arr;
        };

        pub const gp_inverse: [basis_len][]const ProdTerm = blk: {
            var arr: [basis_size][]const ProdTerm = undefined;
            for (0..basis_size) |i| {
                arr[i] = _bin_gp_cayley_table_inv[i][0.._bin_gp_cayley_table_inv.len];
            }
            break :blk arr;
        };
        pub const op_inverse: [basis_len][]const ProdTerm = blk: {
            var arr: [basis_size][]const ProdTerm = undefined;
            for (0..basis_size) |i| {
                arr[i] = _bin_op_cayley_table_inv[i][0.._bin_op_cayley_table_inv.len];
            }
            break :blk arr;
        };
        pub const ip_inverse: [basis_len][]const ProdTerm = blk: {
            var arr: [basis_size][]const ProdTerm = undefined;
            for (0..basis_size) |i| {
                arr[i] = _bin_ip_cayley_table_inv[i][0.._bin_ip_cayley_table_inv.len];
            }
            break :blk arr;
        };
        pub const rp_inverse: [basis_len][]const ProdTerm = blk: {
            var arr: [basis_size][]const ProdTerm = undefined;
            for (0..basis_size) |i| {
                arr[i] = _bin_rp_cayley_table_inv[i][0.._bin_rp_cayley_table_inv.len];
            }
            break :blk arr;
        };

        pub const BladeFormats = enum {
            const Us = @This();
            normal,
            binary_blades,
            binary_no_e,
            decimal_no_e,

            pub fn should_print_e(self: Us) bool {
                return switch (self) {
                    .binary_no_e => false,
                    .decimal_no_e => false,
                    else => true,
                };
            }

            pub fn base(self: Us) usize {
                return switch (self) {
                    .binary_blades, .binary_no_e => 2,
                    .normal, .decimal_no_e => 10,
                };
            }
        };

        pub const RowFormat = struct { //TODO: allow format matrices
            print_parity: bool = true,
            blade_fmt: BladeFormats = .normal,
            ignore_zeroes: bool = false,
            nonzero_scalars_as_blade: bool = false,
        };

        fn cayley_printer(element: BinBlade, current_slice: []u8, fmt: RowFormat) void {
            const mid_slice = @as(usize, @as(usize, @intFromFloat(std.math.ceil(@as(T, @floatFromInt(current_slice.len)) / 2.0)))) - 1;
            for (0..current_slice.len) |i| {
                current_slice[i] = ' ';
            }

            if (fmt.ignore_zeroes == false) {
                if (element.value == 0) { //0
                    current_slice[mid_slice] = '0';
                    return;
                }
            }

            const is_negative: bool = element.value < 0;
            const starting_factor_label = if (z > 0) 0 else 1;
            const num_labels = count_bits(element.blade);

            if (fmt.nonzero_scalars_as_blade == false and num_labels == 0) { //scalar
                if (is_negative and fmt.print_parity == true) {
                    current_slice[mid_slice] = '-';
                    current_slice[mid_slice + 1] = '1';
                } else {
                    current_slice[mid_slice] = '1';
                }
                return;
            }

            var num_chars: usize = num_labels;
            if (fmt.blade_fmt.base() == 2) {
                num_chars = d;
            }
            if (fmt.blade_fmt.should_print_e()) {
                num_chars += 1;
            }
            if (is_negative and fmt.print_parity == true) {
                num_chars += 1;
            }

            var left_margin: usize = 0;
            var right_margin: usize = 0;
            var leftover_margin = current_slice.len - num_chars;

            while (leftover_margin > 0) {
                leftover_margin -= 1;
                left_margin += 1;
                if (leftover_margin > 0) {
                    leftover_margin -= 1;
                    right_margin += 1;
                }
            }

            var i = left_margin;
            if (is_negative == true and fmt.print_parity == true) {
                current_slice[i] = '-';
                i += 1;
            }
            if (fmt.blade_fmt.should_print_e() == true) {
                current_slice[i] = 'e';
                i += 1;
            }

            var current_bit_index: usize = 0;
            if (fmt.blade_fmt.base() == 10) {
                for (0..num_labels) |fac_i| {
                    while (current_bit_index < 10) {
                        const one: usize = 0b1;
                        if (element.blade & (one << @truncate(current_bit_index)) != 0) {
                            break;
                        }
                        current_bit_index += 1;
                    }
                    if (fmt.blade_fmt.base() != 2 and current_bit_index > 9) {
                        current_slice[i + fac_i] = 'X';
                        return;
                    }

                    current_slice[i + fac_i] = @truncate(current_bit_index + starting_factor_label + 48);
                    current_bit_index += 1;
                }
            } else {
                var bit_index = d - 1;
                while (bit_index >= 0) {
                    current_slice[i + bit_index] = @truncate(((element.blade >> @truncate((d - 1) - bit_index)) & 1) + 48);
                    if (bit_index == 0) {
                        break;
                    }
                    bit_index -= 1;
                }
            }
        }

        fn get_cayley_table(allocator: Allocator, cayley: []const []const BinBlade, fmt: []const RowFormat) ![]u8 {
            var maximum: usize = 0;
            for (fmt) |row| {
                var elem_size = d;
                if (row.print_parity == true) {
                    elem_size += 1;
                }
                if (row.blade_fmt.should_print_e() == true) {
                    elem_size += 1;
                }
                if (elem_size > maximum) {
                    maximum = elem_size;
                }
            }
            const max_chars_per_index: usize = maximum + 1;
            const ret_string = try allocator.alloc(u8, max_chars_per_index * basis_len * basis_len * fmt.len);
            format_table_string(BinBlade, cayley, ret_string, fmt, maximum, cayley_printer);
            return ret_string;
        }

        fn FormatTableElementPrinter(ElemType: type) type {
            return *const fn (elem: ElemType, string_slice: []u8, fmt: RowFormat) void;
        }

        fn format_table_string(elem_type: type, table: []const []const elem_type, buffer: []u8, fmt: []const RowFormat, max_chars_per_element: usize, element_printer: FormatTableElementPrinter(elem_type)) void {
            var current_string_idx: usize = 0;
            const max_chars_per_index = max_chars_per_element + 1;
            for (0..table.len * fmt.len) |table_r| {
                for (0..table[table_r % table.len].len) |table_c| {
                    var current_slice = buffer[current_string_idx .. current_string_idx + max_chars_per_index];
                    const ending_char: u8 = blk: {
                        if (table_c == table[table_r % table.len].len - 1) {
                            break :blk '\n';
                        }
                        break :blk ' ';
                    };

                    defer {
                        current_slice[current_slice.len - 1] = ending_char;
                        current_string_idx += max_chars_per_index;
                    }

                    element_printer(table[table_r % table.len][table_c], current_slice[0 .. current_slice.len - 1], fmt[table_r % fmt.len]);
                }
            }
        }

        fn GenBlade() type {

            //we want .fields,
            //var blade = @typeInfo(enum(isize){});
            var fields: [Alg.basis_len]std.builtin.Type.EnumField = undefined;
            var decls = [_]std.builtin.Type.Declaration{};
            //const existing_fields = @typeInfo(Self.ResTypes).Enum.fields;
            //@compileLog( "@typeInfo(Self.ResTypes).Enum.fields) = ", existing_fields, "existing_fields[0].name: ", existing_fields[0].name);
            for (&fields, 0..Alg.basis_len) |*field, i| {
                var name1: [:0]const u8 = "";
                var n_i = 0;
                if (i == 0) {

                    //name1[n_i] = 's';
                    name1 = name1 ++ "s";
                    n_i += 1;
                } else {
                    //name1[n_i] = 'e';
                    name1 = name1 ++ "e";
                    n_i += 1;

                    for (0..Alg.d + 1) |n_j| {
                        const val = (i >> n_j) & 1;
                        if (val != 0) {
                            var char: u8 = '1' + n_j;
                            if (Alg.z > 0) {
                                char -= 1;
                            }
                            //name1[n_i] = char;
                            name1 = name1 ++ .{char};
                            n_i += 1;
                        }
                    }
                }

                //const used_name: [:0]const u8 = name1[0..Alg.d+1]++"";

                field.* = .{ .name = name1, .value = i };
            }

            const ret = @Type(.{ .Enum = .{
                .tag_type = std.math.IntFittingRange(0, Alg.basis_len - 1),
                .fields = &fields,
                .decls = &decls,
                .is_exhaustive = true,
            } });
            //const info = @typeInfo(ret);
            //@compileLog("@typeInfo(reified type) = ", info, "info.Enum = ", info.Enum, "info.Enum.fields = ", info.Enum.fields, "info.Enum.fields[4] (should be e2) = ", info.Enum.fields[4], "name = ", info.Enum.fields[4].name);
            return ret;
        }

        pub const BasisBladeEnum = GenBlade(); //TODO: array?
        pub const BasisBlades: [basis_size]BasisBladeEnum = blk: {
            var ret: [basis_size]BasisBladeEnum = undefined;
            for (0..basis_size) |i| {
                ret[i] = @enumFromInt(i);
            }
            break :blk ret;
        };
        //*const fn(BladeMult, []u8) void

        //this is the base level constructor, we need the dynamic array to be defined by
        // an array the indices of the basis vectors they map to,
        // and the static array to be defined by an array of tuples of the form:
        // (basis index, value they take)
        //fn MVecSubset(comptime T: type, comptime dyn: []const u8, comptime static: [basis_size - dyn.len].{ u8, @TypeOf(T) }) type {

        //}

        //define a datatype that is total over the functions you want
        //and then place it in a tensor
        fn BladeTerm() type {
            return struct {
                const Us: type = @This();
                value: T,
                blade: ux,
            };
        }

        //multiplication like binary operations map a tensor of dim [a,b,c,...f]
        //and a tensor of dim[g,h,i,j,...,m] to a concatenated [a,b,...f,g,h,i,...m]
        //[16] gp [16] = [16,16] = 16**2 terms in a dense map
        //[16,16] gp [16] = [16,16,16] = 16**3 terms in a dense map
        fn Tensor() type {
            //pub fn to_sparse_map()
        }

        ///pretty sure its 100% possible to get runtime and compile time GA expression generation and optimization
        /// done using the exact same infrastructure, so im structuring operations after something like an expression parser
        const Operation = enum {
            //binary
            GeometricProduct,
            OuterProduct,
            InnerProduct,
            RegressiveProduct,
            SandwichProduct,

            //unary
            Dual,
            Reverse,

            pub fn n_ary(self: @This()) comptime_int {
                return switch (self) {
                    .GeometricProduct => 2,
                    .OuterProduct => 2,
                    .InnerProduct => 2,
                    .RegressiveProduct => 2,
                    .SandwichProduct => 2,
                    .Dual => 1,
                    .Reverse => 1,
                };
            }

            //pub fn terms_upper_bound(self: @This()) comptime_int {
            //    return switch(self) {
            //        .GeometricProduct =>
            //    }
            //}

            pub fn BladeOp(self: @This()) type {
                return switch (self) {
                    .GeometricProduct => struct {
                        pub fn eval(left: BladeTerm(), right: BladeTerm()) BladeTerm() {
                            const lhs = left.blade;
                            const rhs = right.blade;
                            const squares = lhs & rhs;
                            const blade: ux = lhs ^ rhs;
                            if (squares & zero_mask != 0) {
                                return BladeTerm(){ .value = 0, .blade = 0 };
                            }
                            const neg_powers_mod_2: isize = @intCast(((squares & neg_mask) ^ count_flips(lhs, rhs)) & 1);
                            const value: isize = -2 * neg_powers_mod_2 + 1;
                            const ret_val = left.value * right.value * @as(f64, @floatFromInt(value));
                            if(@round(ret_val) != ret_val) {
                                @compileLog(comptimePrint("\n\t\tgp lhs val {} * rhs val {} * parity {} = noninteger val {}", .{left.value, right.value, @as(f64, @floatFromInt(value)), ret_val}));
                            }
                            return BladeTerm(){ .value = ret_val, .blade = blade };
                        }
                    },
                    .OuterProduct => struct {
                        pub fn eval(left: BladeTerm(), right: BladeTerm()) BladeTerm() {
                            const lhs = left.blade;
                            const rhs = right.blade;
                            const squares = lhs & rhs;
                            const blade = lhs ^ rhs;
                            if (squares != 0) {
                                return .{ .value = 0, .blade = blade };
                            }
                            return .{ .value = if (count_flips(lhs, rhs) & 1) -1 else 1, .blade = blade };
                        }
                    },
                    .InnerProduct => struct {
                        pub fn eval(left: BladeTerm(), right: BladeTerm()) BladeTerm() {
                            const lhs = left.blade;
                            const rhs = right.blade;
                            const squares = lhs & rhs;
                            const blade = lhs ^ rhs;
                            if (squares & zero_mask != 0) {
                                return .{ .value = 0, .blade = blade };
                            }
                            const ul = lhs & blade;
                            const ur = rhs & blade;

                            const neg_powers_mod_2: isize = @intCast(((squares & neg_mask) ^ count_flips(lhs, rhs)) & 1);
                            const value: isize = -2 * neg_powers_mod_2 + 1;
                            return .{ .value = if (ul == 0 or ur == 0) left.value * right.value * value else 0, .blade = blade };
                        }
                    },

                    .RegressiveProduct => struct {
                        pub fn eval(left: BladeTerm(), right: BladeTerm()) BladeTerm() {
                            const lhs = left.blade ^ pseudoscalar_blade;
                            const rhs = right.blade ^ pseudoscalar_blade;
                            const squares = lhs & rhs;
                            if (squares != 0) {
                                return;
                            }

                            const blade = lhs ^ rhs ^ pseudoscalar_blade;

                            const value = -2 * (((squares & neg_mask) ^ count_flips(lhs, rhs)) & 1) + 1;
                            return .{ .value = value, .blade = blade };
                        }
                    },

                    //execution is something like first * first * second * coeff
                    .SandwichProduct => struct {
                        pub fn eval() BladeTerm() {
                            //const lhs = left.blade;
                            //const rhs = right.blade;
                            //const gp = Operation.GeometricProduct.BladeOp();
                            //const reverse = Operation.Reverse.BladeOp();
                            //const ret = gp.eval(gp.eval(left, right), reverse.eval(left));
                        }
                    },

                    .Dual => struct {
                        pub fn eval(us: BladeTerm()) BladeTerm() {
                            const squares = us.blade & pseudoscalar_blade;
                            return .{ .value = us.value * (-2 * ((squares & neg_mask) ^ count_flips(us.blade, pseudoscalar_blade) & 1)) + 1, .blade = us.blade ^ pseudoscalar_blade };
                        }
                    },

                    .Reverse => struct {
                        pub fn eval(us: BladeTerm()) BladeTerm() {
                            const blade: ud = @truncate(us.blade);
                            const one: ux = 0b1;
                            const mult: T = comptime blk: {
                                var x: usize = blade & ~one;
                                x >>= 1;
                                if (x & 1 == 0) {
                                    break :blk 1.0;
                                }
                                break :blk -1.0;
                            };
                            return BladeTerm(){.blade = blade, .val = mult};
                        }
                    }
                    
                };
            }
        };

        const CayleyReturn = struct { fst: [basis_size][basis_size]BladeTerm(), snd: [basis_size][basis_size]ProdTerm, third: [basis_size]usize };

        //step 1: create the masked cayley space
        //if this is generic to the transformation we need to tell it how to do each operand blade n-tuple
        //pub fn masked_cayley_space(comptime operand_subsets: []comptime_int, comptime operations: []Operation) void {}
        pub fn cayley_table(lhs_subset: ux, rhs_subset: ux, op: anytype, lhs_known_vals: ?[basis_size]struct { known: bool, val: T }, rhs_known_vals: ?[basis_size]struct { known: bool, val: T }) CayleyReturn {
            //const prods = count_bits(lhs_subset & rhs_subset);
            //const left_elems = count_bits(lhs_subset);
            //const right_elems = count_bits(rhs_subset);
            var ret: [basis_len][basis_len]BladeTerm() = .{.{undefined} ** basis_len} ** basis_len;
            var inv: [basis_len][basis_len]ProdTerm = .{.{undefined} ** basis_len} ** basis_len;

            const one: ux = 0b1;

            var inv_indices: [basis_len]usize = .{0} ** basis_len;

            for (0..basis_len) |lhs| {
                //const lhs_curr_idx = count_bits(lhs_subset & ((0b1 << lhs) - 1));
                const lhs_value = if (lhs_known_vals != null and lhs_known_vals.?[lhs].known) lhs_known_vals.?[lhs].val else 1.0;
                for (0..basis_len) |rhs| {
                    const t_lhs: ud = @truncate(lhs);
                    const t_rhs: ud = @truncate(rhs);
                    if (rhs_subset & (one << t_rhs) == 0 or lhs_subset & (one << t_lhs) == 0) {
                        ret[lhs][rhs] = BladeTerm(){ .value = 0, .blade = 0 };
                        continue;
                    }
                    //const rhs_curr_idx = count_bits(rhs_subset & ((0b1 << rhs) - 1));
                    const rhs_value = if (rhs_known_vals != null and rhs_known_vals.?[lhs].known) rhs_known_vals.?[lhs].val else 1.0;

                    const res = op.eval(.{ .value = lhs_value, .blade = t_lhs }, .{ .value = rhs_value, .blade = t_rhs });
                    ret[lhs][rhs] = res;
                    if (res.value == 0) {
                        continue;
                    }
                    //inv[result term blade][0..n] = .{magnitude coeff, lhs operand, rhs operand}
                    // where 0..n are the filled in indices, n = inv_indices[]
                    inv[res.blade][inv_indices[res.blade]] = .{ .mult = res.value, .left_blade = lhs, .right_blade = rhs };
                    inv_indices[res.blade] += 1;
                }
            }

            return .{ .fst = ret, .snd = inv, .third = inv_indices };
        }

        pub fn inverse_table_and_op_res_to_scatter_masks(comptime inv: [basis_len][basis_len]ProdTerm, comptime inv_indices: [basis_len]usize, comptime lhs_subset: ux, comptime rhs_subset: ux, comptime superset: ux, comptime len: usize) struct { [basis_len][len]i32, [basis_len][len]i32, [basis_len][len]T } {
            //for full multivectors, result[i] = sigma(inverse[i][0..inv_indices[i]])
            //in the end we want to do inline for(mask_a, mask_b, mask_coeff) |ma,mb,mc| {
            //  res.* += @shuffle(lhs.val, @splat(1), ma)}
            // this means that mask_a[i] = ma must be of the form: {-1,-1,5,4,2,-1,1,-1,3,0}
            // if lhs is len 6, its being gathered into a result type of len 10, and:
            // res[0] = op(1,rhs[x]) + ... = inv[0][0] ** 2 + inv[0][1] ** 2 + inv[0][2] ** 2 + ... + inv[0][inv_indices[0]] ** 2
            // res[1] = op(1, rhs[x]) + ...
            // res[2] = op(lhs[5], rhs[x]) + ...
            // res[3] = op(lhs[4],rhs[x]) + ...
            // res[4] = op(lhs[2], rhs[x]) + ...
            // res[5] = op(1, rhs[x]) + ...
            // res[6] = op(lhs[1], rhs[x]) + ...
            // ...
            //where inv[res blade][ith term] ** 2 = inv[res blade][ith].mult * lhs.terms[inv[res blade][ith].left_blade] * rhs.terms[inv[res blade][ith].right_blade]
            //                                      = coeff_masks[ith][res blade]               = lhs_masks[ith][res blade]   = rhs_masks[ith][res blade]
            //const len = count_bits(superset);
            const max_terms = basis_len;

            //       terms upper bound       count_bits(superset)
            //of the form: [ith term][res blade idx in superset] = an index in the lhs.terms array (inv[res blade][ith].left_blade) if lhs_subset & (0b1 << res blade) != 0 else -1
            //execute_sparse_vector_op() needs to iterate through the adds we give them, num_terms of these,
            //meaning that at least one of the result vectors elements = t1 + t2 + t3 + ... + t[num_terms]
            //if either of the lhs or rhs masks ith term = {-1,...,-1} for count_bits(superset) then that term is invalid and we continue
            comptime var lhs_masks: [basis_size][len]i32 = .{.{-1} ** len} ** basis_len;
            comptime var rhs_masks: [basis_size][len]i32 = .{.{-1} ** len} ** basis_len;
            comptime var coeff_masks: [basis_size][len]T = .{.{0} ** len} ** basis_len;

            var masks_idx: usize = 0;

            //lhs_masks[upper_len-1][]

            //res_idx = count_bits(superset & ((0b1 << result_blade) - 1))

            const one: ux = 0b1;

            for (0..max_terms) |ith_term| {
                //check if ith_term <= inv_indices[result_blade] for all result_blade's that are in superset, if theres any terms left then collate them into the next set of masks
                var remaining_terms: bool = false;
                for (0..basis_len) |res_blade| {
                    const result_blade: ud = @truncate(res_blade);
                    if ((superset & (one << result_blade)) != 0 and inv_indices[result_blade] >= ith_term) {
                        remaining_terms = true;
                        break;
                    }
                }
                if (remaining_terms == false) {
                    break;
                }
                defer masks_idx += 1;

                var lhs_mask: [len]i32 = .{-1} ** len;
                var rhs_mask: [len]i32 = .{-1} ** len;
                var coeff_mask: [len]T = .{0} ** len;

                for (0..basis_len) |res_blade| {
                    const result_blade: ud = @truncate(res_blade);
                    //@compileLog(result_blade.Int);
                    if (superset & (one << result_blade) == 0) {
                        continue;
                    }
                    //is this undefined?
                    const inv_term = comptime inv[result_blade][ith_term];

                    const coeff = inv_term.mult;
                    const left_operand_blade = inv_term.left_blade;
                    const right_operand_blade = inv_term.right_blade;

                    const left_t_blade: std.math.IntFittingRange(0, 15) = @truncate(left_operand_blade);
                    const right_t_blade: ud = @truncate(right_operand_blade);

                    //const xd = (one << left_operand_blade) - 1;
                    //_ = xd;

                    const lhs_idx = comptime count_bits(lhs_subset & ((one << left_t_blade) -% 1));
                    const rhs_idx = comptime count_bits(rhs_subset & ((one << right_t_blade) -% 1));

                    const res_idx = comptime count_bits(superset & ((one << result_blade) -% 1));

                    //comptime lhs_mask.set(res_idx, lhs_idx);
                    //comptime rhs_mask.set(res_idx, rhs_idx);
                    //comptime coeff_mask.set(res_idx, coeff);
                    lhs_mask[res_idx] = lhs_idx;
                    rhs_mask[res_idx] = rhs_idx;
                    coeff_mask[res_idx] = coeff;
                }

                //lhs_masks[ith_term] =
                //comptime try lhs_masks.append(lhs_mask);
                //comptime try rhs_masks.append(rhs_mask);
                //comptime try coeff_masks.append(coeff_mask);
                @memcpy(lhs_masks[ith_term][0..len], lhs_mask[0..len]);
                @memcpy(rhs_masks[ith_term][0..len], rhs_mask[0..len]);
                @memcpy(coeff_masks[ith_term][0..len], coeff_mask[0..len]);
            }

            const ret_lhs: [basis_len]@Vector(len, i32) = lhs_masks;
            const ret_rhs: [basis_len]@Vector(len, i32) = rhs_masks;
            const ret_coeff: [basis_len]@Vector(len, T) = coeff_masks;

            return comptime .{ ret_lhs, ret_rhs, ret_coeff };
        }

        //shuffle, mul, and add
        pub fn execute_sparse_vector_op(lhs: anytype, rhs: anytype, res: anytype, comptime masks: anytype, comptime len: usize, comptime DataType: type) void {
            const lhs_masks = masks[0];
            const rhs_masks = masks[1];
            const coeff_masks = masks[2];

            //const res_type = @typeInfo(@TypeOf(res)).Pointer.child;

            //std.debug.print("\n\t pre execute res.terms: {d:<.1}, lhs.terms: {d:<.1}, rhs.terms: {d:<.1}, ", .{res.terms, lhs.terms, rhs.terms});

            if (is_comptime(len)) {
                //@compileLog("execute_sparse_vector_op() is in comptime");
                //const lhs_subset = @typeInfo(@TypeOf(lhs)).Pointer.child.subset_field;
                //const rhs_subset = @typeInfo(@TypeOf(rhs)).Pointer.child.subset_field;
                //const res_subset = @typeInfo(@TypeOf(res)).Pointer.child.subset_field;
                //@compileLog(comptimePrint("lhs size: {} rhs size: {} res size: {}", .{comptime count_bits(lhs_subset), comptime count_bits(rhs_subset), comptime count_bits(res_subset)}));

                const ones: @Vector(len, T) = @splat(1.0);
                const invalid_mask: @Vector(len, i32) = @splat(-1.0);
                //const zeros: @Vector(len, T) = @splat(0.0);

                const pos: @Vector(len, T) = @splat(1);
                const neg: @Vector(len, T) = @splat(-1);

                //decreasing delta further doesnt detect near zeros.
                const delta: @Vector(len, T) = @splat(0.00001);

                inline for (lhs_masks, rhs_masks, coeff_masks) |_lhs_mask, _rhs_mask, _coeff_mask| {
                    const lhs_mask: @Vector(_lhs_mask.len, i32) = _lhs_mask;
                    const rhs_mask: @Vector(_lhs_mask.len, i32) = _rhs_mask;
                    const coeff_mask: @Vector(_lhs_mask.len, T) = _coeff_mask;
                    const invalid = comptime blk: {
                        //@compileLog(comptimePrint("lhs_mask type: {}, rhs_mask type: {}, coeff_mask type: {}", .{@TypeOf(lhs_mask), @TypeOf(rhs_mask), @TypeOf(coeff_mask)}));
                        break :blk @reduce(.And, lhs_mask == invalid_mask) or @reduce(.And, rhs_mask == invalid_mask) or @reduce(.And, @abs(coeff_mask) < delta);
                    };
                    if (!invalid) {
                        //@compileLog(comptimePrint("\nlhs mask: {d: <3.0}, rhs_mask: {d: <3.0}, coeff_mask: {d: <3.0}", .{ lhs_mask, rhs_mask, coeff_mask }));

                        //std.debug.print("\ncoeff_mask == zeros is {}, reduce: {}", .{@as(@Vector(len, T), @splat(@as(f64, 2.0))) * coeff_mask == coeff_mask, @reduce(.And, @as(@Vector(len, T), @splat(@as(f64, 2.0))) * coeff_mask == coeff_mask)});
                        const first = @shuffle(DataType, lhs.terms, ones, lhs_mask);
                        const second = @shuffle(DataType, rhs.terms, ones, rhs_mask);
                        //std.debug.print("\n\tfirst: {d: <.1} second: {d: <.1}, coeff: {}", .{first, second, coeff_mask});
                        if (comptime @reduce(.And, coeff_mask == pos)) {
                            res.terms += first * second;
                        } else if (comptime @reduce(.And, coeff_mask == neg)) {
                            res.terms -= first * second;
                        } else {
                            res.terms += first * second * coeff_mask;
                        }
                        //std.debug.print("\n\tres.terms: {d:<.1}", .{res.terms});
                    }
                }
            } else {
                @compileLog("execute_sparse_vector_op() is NOT in comptime!!!!!!!");
                const ones: @Vector(basis_len, i32) = @splat(1);
                const invalid_mask: @Vector(basis_len, i32) = @splat(-1);
                const zeros: @Vector(basis_len, i32) = @splat(0);

                //remove this when we get the comptime branch open
                inline for (lhs_masks, rhs_masks, coeff_masks) |lhs_mask, rhs_mask, coeff_mask| {
                    const invalid = @reduce(.And, lhs_mask == invalid_mask) or @reduce(.And, rhs_mask == invalid_mask) or @reduce(.And, coeff_mask == zeros);
                    if (!invalid) {
                        const first = @shuffle(DataType, lhs.terms, ones, lhs_mask);
                        const second = @shuffle(DataType, rhs.terms, ones, rhs_mask);
                        res.terms.* += first * second * coeff_mask;
                    }
                }
            }
        }

        const UnaryProdTerm = struct { mult: T, opr: usize };
        const UnaryCayleyReturn = struct { fst: [basis_len]BladeTerm(), snd: [basis_len]UnaryProdTerm };

        pub fn unary_cayley_table(opr_subset: ux, op: anytype, opr_known_vals: ?[basis_size]struct { known: bool, val: T }) UnaryCayleyReturn {
            //const prods = count_bits(lhs_subset & rhs_subset);
            //const left_elems = count_bits(lhs_subset);
            //const right_elems = count_bits(rhs_subset);
            var ret: [basis_len]BladeTerm() = .{undefined} ** basis_len;
            var inv: [basis_len]UnaryProdTerm = .{undefined} ** basis_len;

            const one: ux = 0b1;

            for (0..basis_len) |blade| {
                const t_blade: ud = @truncate(blade);
                if (opr_subset & (one << t_blade) == 0) {
                    ret[t_blade] = BladeTerm(){ .value = 0, .blade = 0 };
                    continue;
                }
                //const rhs_curr_idx = count_bits(rhs_subset & ((0b1 << rhs) - 1));
                const value = if (opr_known_vals != null and opr_known_vals.?[t_blade].known) opr_known_vals.?[t_blade].val else 1;

                const res = op.eval(.{ .value = value, .blade = blade });
                ret[blade] = res;
                if (res.value == 0) {
                    continue;
                }
                //inv[result term blade][0..n] = .{magnitude coeff, lhs operand, rhs operand}
                // where 0..n are the filled in indices, n = inv_indices[]
                inv[res.blade] = .{ .mult = res.value, .opr = blade };
            }

            return .{ .fst = ret, .snd = inv };
        }

        pub fn unary_inverse_table_to_scatter_mask(comptime inv: [basis_len]UnaryProdTerm, comptime opr_subset: ux, comptime res_subset: ux, comptime len: usize) struct { [len]i32, [len]T } {
            comptime var coeff_mask: [len]T = .{0} ** len;
            comptime var opr_mask: [len]i32 = .{-1} ** len;
            const one: ux = 0b1;
            for (0..basis_len) |res_blade| {
                const result_blade: ud = @truncate(res_blade);
                if (res_subset & (one << result_blade) == 0) {
                    continue;
                }
                const term = inv[result_blade];
                const coeff = term.mult;
                const opr_blade: ud = @truncate(term.opr);

                const opr_index = comptime count_bits(opr_subset & ((one << opr_blade) -% 1));
                const res_idx = comptime count_bits(res_subset & ((one << result_blade) -% 1));

                opr_mask[res_idx] = opr_index;
                coeff_mask[res_idx] = coeff;
            }

            const cf_mask: @Vector(len, T) = coeff_mask;
            const operand_mask: @Vector(len, i32) = opr_mask;
            return comptime .{ operand_mask, cf_mask };
        }

        pub fn unary_execute_sparse_vector_op(opr: anytype, res: anytype, comptime masks: anytype, comptime len: usize, comptime DataType: type) void {
            const opr_mask = masks[0];
            const coeff_mask = masks[1];

            //const ones: @Vector(len, i32) = @splat(1);
            //const invalid_mask: @Vector(len, i32) = @splat(-1);
            const zeros: @Vector(len, T) = @splat(0);
            //const pos: @Vector(len, T) = @splat(1);
            //const neg: @Vector(len, T) = @splat(-1);

            const gather = @shuffle(DataType, opr.terms, zeros, opr_mask);
            res.terms = gather * coeff_mask;
        }
        ///goes through every element of the given cayley table and adds its value to a return array at the index of that elements blade
        /// we want output += coeffs * scattered lhs * scattered rhs
        //pub fn invert_cayley_table(cayley_table: [][]BladeTerm()) [][]ProdTerm() {
        //to our customers we want to provide the information "what affects the value of this term" for each term
        //cayley_table will be 0 in every non included row
        //    var ret: [basis_len][basis_len]ProdTerm() = undefined;

        //}

        pub fn MVecSubset(comptime subset: ux) type {

            //Naive (Multi) Vector - full basis_size elements
            const ret = struct {
                pub const Algebra: type = Alg;
                const Self: type = @This();
                pub const ResTypes = enum {
                    alloc_new,
                    stack_alloc,
                    ptr,
                };
                pub const ResSemantics = union {
                    alloc_new: Allocator,
                    stack_alloc: void,
                    ptr: *Self,
                };

                pub const name = [_]u8{"Multivector"};
                pub const subset_field: ux = subset;

                pub const unbroken_range: bool = blk: {
                    var bit_index = 0;
                    const one = 1;
                    var sbset = subset;
                    var found_one_before: bool = false;
                    //var remaining_cardinality = count_bits(subset);
                    while (sbset != 0) {
                        defer bit_index += 1;
                        const cur_mask = one << bit_index;
                        const val = sbset & cur_mask;
                        if (val == 0 and found_one_before) {
                            break :blk false;
                        }
                        if (val != 0) {
                            found_one_before = true;
                            sbset ^= cur_mask;
                        }
                    }
                    break :blk true;
                };

                pub const num_terms: usize = count_bits(subset);

                ///when converted to MVecSubset this MUST only contain the blades specific to this instance
                pub const BladeE: type = Self.Algebra.BasisBladeEnum;
                //pub const Blades: [num_terms]Blade = blk: {
                //    var ret: [num_terms]Blade = undefined;
                //    for(0..dyn.len) |i| {
                //        ret[i] = dyn[i];
                //    }
                //    break :blk ret;
                //};
                /// since blade binary rep == mvec index of blade, this also gets the mvec index
                /// bit field where the ith multiple of d LSB's (e.g. d = 4 and i = 2 means bits 4 * 2 through 4 * 2 + 3 from the LSB)
                /// corresponds to the ith blade in the full mvec.
                /// find it with (our_index_to_blade >> index in our array) & ((0b1 << d) - 1)
                /// everything more significant than the largest blade value is set to 0b1111... (maybe find a better solution)
                pub const our_idx_to_blade = blk: {
                    var ret: usize = 0b0;
                    var bit_index: usize = 0b0;
                    //const one: usize = 0b1;
                    var ones_left = num_terms;
                    while (ones_left > 0) {
                        defer bit_index += 1;
                        const one: usize = 0b1;
                        const ith_bit: usize = (subset >> bit_index) & one;
                        if (ith_bit > 0) {
                            //@compileLog(subset, ": 1 found at index ", ith_bit, );
                            //@compileLog(comptimePrint("subset {b}, 1 found at index {}, ret was {b} and now set to {b}", .{ subset, bit_index, ret, ret | (bit_index << (d * (num_terms - ones_left))) }));
                            //if 3 original terms and: 3 terms left then shift 0 terms (ret = 0b[blade1]), 2 terms left then shift once (ret = 0b[blade2][blade1])
                            //1 term left then shift twice (ret = 0b[blade3][blade2][blade1])
                            ret |= (bit_index << (d * (num_terms - ones_left)));
                            ones_left -= 1;
                        }
                    }
                    //const mask: usize = (0b1 << d) - 1;
                    //for(bit_index..mask) |b_i| { //TODO: should i set bits more significant than the most sig blade to 1111...? it wont always overflow
                    //    ret |= (mask << b_i);
                    //}
                    break :blk ret;
                    //find the ith bit of subset at bit index b(i), set the (i * d)th bits of ret to b(i)
                };
                //pub const blade_to_our_idx = blk: {

                //};

                terms: @Vector(num_terms, T),

                pub fn get(self: *Self, comptime res_type: enum { stack, ptr }, blade: BladeE) switch (res_type) {
                    .stack => T,
                    .ptr => *T,
                } {
                    switch (res_type) {
                        .stack => {
                            const idx: usize = @intFromEnum(blade);
                            return self.terms[idx];
                        },
                        .ptr => {
                            const idx: usize = @intFromEnum(blade);
                            return &self.terms[idx];
                        },
                    }
                }

                pub fn zeros(self: *Self) *Self {
                    inline for (0..Self.num_terms) |i| {
                        //self.get(.ptr, b).* = 0;
                        self.terms[i] = 0.0;
                    }
                    return self;
                }

                pub fn randomize(self: *Self, gen: *Random, stddev: T, mean: T, terms_to_randomize: anytype) *Self {
                    const random_terms_left: i32 = comptime blk: {
                        switch(@typeInfo(@TypeOf(terms_to_randomize))) {
                            .Int, .ComptimeInt => {
                                break :blk @max(0, @min(terms_to_randomize, Self.num_terms));
                            },

                            .Float, .ComptimeFloat => {
                                break :blk @max(0, @min(@as(T, @ceil(terms_to_randomize * @as(T, @floatFromInt(Self.num_terms)))), Self.num_terms));
                            },
                            else => {
                                @compileError(comptimePrint("non int or float passwed to multivector.randomize()! type: {}, info: {}", .{@TypeOf(terms_to_randomize), @typeInfo(@TypeOf(terms_to_randomize))}));
                            }
                        }
                    };
                    var randomized_terms: @Vector(Self.num_terms, bool) = @splat(false);
                    for(0..random_terms_left) |_| {
                        while(true) {
                            const next_term = gen.intRangeAtMost(u32, 0, Self.num_terms-1);
                            if(randomized_terms[next_term] == false) {
                                randomized_terms[next_term] = true;
                                break; 
                            } else {
                                continue;
                            }
                        }
                    }
                    for(0..Self.num_terms) |i| {
                        const should_randomize: bool = randomized_terms[i];
                        if(should_randomize == false) {
                            continue;
                        }
                        
                        self.terms[i] = gen.floatNorm(T) * stddev + mean;
                    }
                    return self;
                }

                pub fn set_to(self: *Self, source: *Self) *Self {
                    @memcpy(self.terms[0..Self.Algebra.basis_len], source.terms[0..Self.Algebra.basis_len]);
                    return self;
                }

                pub fn format(
                    nvec: Self,
                    comptime _: []const u8,
                    _: std.fmt.FormatOptions,
                    writer: anytype,
                ) !void {
                    //try writer.writeAll("Multivector: {");
                    try writer.print("Multivector ({b}): ", .{Self.subset_field});
                    try writer.writeAll("{");
                    var has_written_before: bool = false;
                    for (0..num_terms) |i| {
                        const term = nvec.terms[i];
                        if (term == 0.0) {
                            continue;
                        }
                        if (has_written_before == true) {
                            _ = try writer.print(" ", .{});
                            if (term > 0.0) {
                                _ = try writer.print("+ ", .{});
                            }
                        }
                        has_written_before = true;

                        var blade_buff: [10]u8 = .{0} ** 10;

                        const blade: usize = (Self.our_idx_to_blade >> @truncate(d * i)) & ((0b1 << d) - 1);

                        var chars_needed: usize = count_bits(blade);
                        var curr_char_idx: usize = 0;
                        //_ = try writer.print(" our_idx_to_blade: {b}, blade: {b}, chars: {d} ", .{ Self.our_idx_to_blade, blade, chars_needed });

                        _ = try writer.print("{d:.3}", .{term});

                        if (chars_needed > 0) {
                            blade_buff[curr_char_idx] = 'e';
                            curr_char_idx += 1; //e
                            //var blade_copy = i;
                            var curr_bit_idx: usize = 0b1;
                            var curr_bit_char_num: usize = blk: {
                                if (Self.Algebra.z > 0) {
                                    break :blk 0;
                                }
                                break :blk 1;
                            };
                            while (chars_needed > 0) {
                                if (blade & curr_bit_idx == curr_bit_idx) {
                                    chars_needed -= 1;
                                    blade_buff[curr_char_idx] = @truncate(curr_bit_char_num + 48);
                                    curr_char_idx += 1;
                                }
                                curr_bit_idx <<= 1;
                                curr_bit_char_num += 1;
                            }

                            const slice = blade_buff[0..curr_char_idx];
                            _ = try writer.print("{s}", .{slice});
                        }
                    }
                    try writer.writeAll("}");
                }

                pub inline fn has(comptime m_i: usize) bool {
                    return subset & (0b1 << m_i) != 0b0;
                }

                pub inline fn redirect(comptime m_i: usize) usize {
                    comptime {
                        return count_bits(((0b1 << m_i) - 1) & subset);
                    }
                }

                pub inline fn set_redirect(self: *Self, comptime m_i: usize, value: T) void {
                    self.terms[Self.redirect(m_i)] = value;
                }

                pub inline fn get_redirect(self: *Self, comptime m_i: usize) T {
                    return self.terms[Self.redirect(m_i)];
                }

                pub fn mvec_index(comptime i: usize) usize {
                    comptime {
                        return (our_idx_to_blade >> i) & ((0b1 << d) - 1);
                    }
                }

                ///TODO: maybe i can do some kind of callback pass in for non invariant subset operations
                pub fn GetStandardRes(comptime res_type: ResTypes) type {
                    return switch(res_type) {
                        .alloc_new => *Self,
                        .stack_alloc => Self,
                        .ptr => *Self
                    };
                }

                pub inline fn get_standard_res(comptime res_type: ResTypes, res_data: ResSemantics) GetStandardRes(res_type) {
                    return switch(res_type) {
                        .alloc_new => try res_data.alloc.new.create(Self),
                        .stack_alloc => Self{.terms=@splat(0)},
                        .ptr => res_data.ptr
                    };
                }

                pub fn add(lhs: anytype, rhs: anytype, res: anytype) @TypeOf(res) { //comptime lhs_type: type, lhs: *lhs_type, comptime rhs_type: type, rhs: *rhs_type, comptime ret_type: type, ret_ptr: *ret_type) *ret_type {
                    //if((@hasField(left_type, "Blades") == false or @hasField(right_type, "Blades") == false)) {
                    //    @compileError("YOU CANT JUST PASS ANYTHING INTO ADD()");
                    //}
                    //ret_ptr.terms =

                    const left_type: type = @typeInfo(@TypeOf(lhs)).Pointer.child;
                    const right_type: type = @typeInfo(@TypeOf(rhs)).Pointer.child;
                    const res_type: type = @typeInfo(@TypeOf(res)).Pointer.child;

                    const left_set: ux = comptime blk: {
                        break :blk left_type.subset_field;
                    };
                    const right_set: ux = comptime blk: {
                        break :blk right_type.subset_field;
                    };
                    const res_set: ux = comptime blk: {
                        break :blk res_type.subset_field;
                    };
                    const len = comptime count_bits(res_set);

                    comptime var _lhs_mask: @Vector(len, i32) = @splat(-1);
                    comptime var _rhs_mask: @Vector(len, i32) = @splat(-1);
                    comptime {
                        const one: ux = 0b1;
                        for (0..basis_len) |res_blade| {
                            const result_blade: ud = @truncate(res_blade);
                            if (res_set & (one << result_blade) == 0) {
                                continue;
                            }
                            //left_set = 0b01011101, if res_blade = 101 (5)
                            //then if (0b01011101 & (0b1 << 101 = 0b100000) != 0 (true)),
                            //then the index in left for blade 101 is:
                            //count_bits(0b01011101 & (0b100000 -% 1 = 0b011111) = 0b00011101) = 4
                            //which is correct
                            
                            //may not exist
                            const left_idx = count_bits(left_set & ((one << result_blade) -% 1));
                            const right_idx = count_bits(right_set & ((one << result_blade) -% 1));

                            //must exist, and if an operand idx exists this is >= that
                            //assuming res is a superset of lhs.subset_field | rhs.subset_field
                            const res_idx = count_bits(res_set & ((one << result_blade) -% 1));

                            if (left_set & (one << result_blade) != 0) {
                                _lhs_mask[res_idx] = left_idx;
                            }
                            if (right_set & (one << result_blade) != 0) {
                                _rhs_mask[res_idx] = right_idx;
                            }
                        }
                    }
                    const lhs_mask = _lhs_mask;
                    const rhs_mask = _rhs_mask;
                    const zero: @Vector(len, T) = @splat(0);

                    const left = @shuffle(T, lhs.terms, zero, lhs_mask);
                    const right = @shuffle(T, rhs.terms, zero, rhs_mask);

                    res.terms = left + right;

                    return res;

                    //inline for (0..ret_type.num_terms) |i| {
                    //    const mvec_idx = comptime blk: {
                    //        break :blk ret_type.mvec_index(i);
                    //    };
                    //    if (lhs_type.has(mvec_idx)) { //this has terrible code generation, it "inlines" by jumping all over the place
                    //        if (rhs_type.has(mvec_idx)) {
                    //            ret_ptr.set_redirect(mvec_idx, lhs.get_redirect(mvec_idx) + rhs.get_redirect(mvec_idx));
                    //        } else {
                    //            ret_ptr.set_redirect(mvec_idx, lhs.get_redirect(mvec_idx));
                    //        }
                    //    } else {
                    //        if (rhs_type.has(mvec_idx)) {
                    //            ret_ptr.set_redirect(mvec_idx, rhs.get_redirect(mvec_idx));
                    //        }
                    //    }
                    //    //check if lhs or rhs have the given field value, and if they do do the add. if they dont then continue
                    //    //we need a way of comparing
                    //    //result.terms[i] = lhs.terms[i] + rhs.terms[i];
                    //}
                    //return ret_ptr;
                }

                pub fn sub(lhs: anytype, rhs: anytype, res: anytype) *Self {
                    const left_type: type = @typeInfo(@TypeOf(lhs)).Pointer.child;
                    const right_type: type = @typeInfo(@TypeOf(rhs)).Pointer.child;
                    const res_type: type = @typeInfo(@TypeOf(res)).Pointer.child;

                    const left_set: ux = comptime blk: {
                        break :blk left_type.subset_field;
                    };
                    const right_set: ux = comptime blk: {
                        break :blk right_type.subset_field;
                    };
                    const res_set: ux = comptime blk: {
                        break :blk res_type.subset_field;
                    };
                    const len = comptime count_bits(res_set);

                    comptime var _lhs_mask: @Vector(len, i32) = @splat(-1);
                    comptime var _rhs_mask: @Vector(len, i32) = @splat(-1);
                    comptime {
                        const one: ux = 0b1;
                        for (0..basis_len) |res_blade| {
                            const result_blade: ud = @truncate(res_blade);
                            if (res_set & (one << result_blade) == 0) {
                                continue;
                            }
                            const left_idx = count_bits(left_set & ((one << result_blade) -% 1));
                            const right_idx = count_bits(right_set & ((one << result_blade) -% 1));
                            const res_idx = count_bits(res_set & ((one << result_blade) -% 1));

                            if (left_set & (one << result_blade) != 0) {
                                _lhs_mask[res_idx] = left_idx;
                            }
                            if (right_set & (one << result_blade) != 0) {
                                _rhs_mask[res_idx] = right_idx;
                            }
                        }
                    }
                    const lhs_mask = _lhs_mask;
                    const rhs_mask = _rhs_mask;
                    const zero: @Vector(len, T) = @splat(0);

                    res.terms = @shuffle(T, lhs.terms, zero, lhs_mask) - @shuffle(T, rhs.terms, zero, rhs_mask);

                    return res;
                }


                pub fn mul_scalar(nvec: *Self, scalar: anytype, comptime res_type: ResTypes, res_data: ResSemantics) GetStandardRes(res_type) {
                    var result = get_standard_res(res_type, res_data);
                    result.terms = nvec.terms * @as(@Vector(Self.num_terms, T), @splat(scalar));
                    return result;
                }

                pub fn gp(left: anytype, right: anytype, res: anytype) @TypeOf(res) {
                    const left_type: type = @typeInfo(@TypeOf(left)).Pointer.child;
                    const right_type: type = @typeInfo(@TypeOf(right)).Pointer.child;
                    const res_type: type = @typeInfo(@TypeOf(res)).Pointer.child;

                    const left_set: ux = comptime blk: {
                        break :blk left_type.subset_field;
                    };
                    const right_set: ux = comptime blk: {
                        break :blk right_type.subset_field;
                    };
                    const res_set: ux = comptime blk: {
                        break :blk res_type.subset_field;
                    };

                    @setEvalBranchQuota(10000000);

                    const table = comptime Alg.cayley_table(left_set, right_set, Alg.Operation.GeometricProduct.BladeOp(), null, null);
                    //tell the table inverter the res size, then we can expect it to return an array with comptime known size
                    const res_size = comptime count_bits(res_set);
                    const operation = comptime Alg.inverse_table_and_op_res_to_scatter_masks(table.snd, table.third, left_set, right_set, res_set, res_size);

                    Alg.execute_sparse_vector_op(left, right, res, comptime operation, comptime res_size, D);
                    return res;
                }

                pub fn gp_inv(left: *Self, right: *Self, comptime res_type: ResTypes, res_data: ResSemantics) GetStandardRes(res_type) {
                    const result = get_standard_res(res_type, res_data);

                    inline for (0..Self.num_terms) |res_blade| { //find every mult pair that produces this blade
                        inner: inline for (0..Self.num_terms) |prod_idx| {
                            const val = comptime blk: {
                                break :blk gp_inverse[res_blade][prod_idx].mult;
                            };
                            const lhs = comptime blk: {
                                break :blk gp_inverse[res_blade][prod_idx].left_blade;
                            };
                            const rhs = comptime blk: {
                                break :blk gp_inverse[res_blade][prod_idx].right_blade;
                            };

                            comptime {
                                if (lhs > Self.num_terms or rhs > Self.num_terms) {
                                    break :inner;
                                }
                            }

                            result.terms[res_blade] += val * (left.terms[lhs] + right.terms[rhs]);
                        }
                    }

                    return result;
                }

                pub fn gp_handrolled(left: *Self, right: *Self, comptime res_type: ResTypes, res_data: ResSemantics) GetStandardRes(res_type) {
                    const result = get_standard_res(res_type, res_data);
                    const res = &result.terms;
                    const b = &right.terms;
                    const a = &left.terms;

                    res[0] = b[0] * a[0] + b[2] * a[2] + b[3] * a[3] + b[4] * a[4] - b[8] * a[8] - b[9] * a[9] - b[10] * a[10] - b[14] * a[14];
                    res[1] = b[1] * a[0] + b[0] * a[1] - b[5] * a[2] - b[6] * a[3] - b[7] * a[4] + b[2] * a[5] + b[3] * a[6] + b[4] * a[7] + b[11] * a[8] + b[12] * a[9] + b[13] * a[10] + b[8] * a[11] + b[9] * a[12] + b[10] * a[13] + b[15] * a[14] - b[14] * a[15];
                    res[2] = b[2] * a[0] + b[0] * a[2] - b[8] * a[3] + b[9] * a[4] + b[3] * a[8] - b[4] * a[9] - b[14] * a[10] - b[10] * a[14];
                    res[3] = b[3] * a[0] + b[8] * a[2] + b[0] * a[3] - b[10] * a[4] - b[2] * a[8] - b[14] * a[9] + b[4] * a[10] - b[9] * a[14];
                    res[4] = b[4] * a[0] - b[9] * a[2] + b[10] * a[3] + b[0] * a[4] - b[14] * a[8] + b[2] * a[9] - b[3] * a[10] - b[8] * a[14];
                    res[5] = b[5] * a[0] + b[2] * a[1] - b[1] * a[2] - b[11] * a[3] + b[12] * a[4] + b[0] * a[5] - b[8] * a[6] + b[9] * a[7] + b[6] * a[8] - b[7] * a[9] - b[15] * a[10] - b[3] * a[11] + b[4] * a[12] + b[14] * a[13] - b[13] * a[14] - b[10] * a[15];
                    res[6] = b[6] * a[0] + b[3] * a[1] + b[11] * a[2] - b[1] * a[3] - b[13] * a[4] + b[8] * a[5] + b[0] * a[6] - b[10] * a[7] - b[5] * a[8] - b[15] * a[9] + b[7] * a[10] + b[2] * a[11] + b[14] * a[12] - b[4] * a[13] - b[12] * a[14] - b[9] * a[15];
                    res[7] = b[7] * a[0] + b[4] * a[1] - b[12] * a[2] + b[13] * a[3] - b[1] * a[4] - b[9] * a[5] + b[10] * a[6] + b[0] * a[7] - b[15] * a[8] + b[5] * a[9] - b[6] * a[10] + b[14] * a[11] - b[2] * a[12] + b[3] * a[13] - b[11] * a[14] - b[8] * a[15];
                    res[8] = b[8] * a[0] + b[3] * a[2] - b[2] * a[3] + b[14] * a[4] + b[0] * a[8] + b[10] * a[9] - b[9] * a[10] + b[4] * a[14];
                    res[9] = b[9] * a[0] - b[4] * a[2] + b[14] * a[3] + b[2] * a[4] - b[10] * a[8] + b[0] * a[9] + b[8] * a[10] + b[3] * a[14];
                    res[10] = b[10] * a[0] + b[14] * a[2] + b[4] * a[3] - b[3] * a[4] + b[9] * a[8] - b[8] * a[9] + b[0] * a[10] + b[2] * a[14];
                    res[11] = b[11] * a[0] - b[8] * a[1] + b[6] * a[2] - b[5] * a[3] + b[15] * a[4] - b[3] * a[5] + b[2] * a[6] - b[14] * a[7] - b[1] * a[8] + b[13] * a[9] - b[12] * a[10] + b[0] * a[11] + b[10] * a[12] - b[9] * a[13] + b[7] * a[14] - b[4] * a[15];
                    res[12] = b[12] * a[0] - b[9] * a[1] - b[7] * a[2] + b[15] * a[3] + b[5] * a[4] + b[4] * a[5] - b[14] * a[6] - b[2] * a[7] - b[13] * a[8] - b[1] * a[9] + b[11] * a[10] - b[10] * a[11] + b[0] * a[12] + b[8] * a[13] + b[6] * a[14] - b[3] * a[15];
                    res[13] = b[13] * a[0] - b[10] * a[1] + b[15] * a[2] + b[7] * a[3] - b[6] * a[4] - b[14] * a[5] - b[4] * a[6] + b[3] * a[7] + b[12] * a[8] - b[11] * a[9] - b[1] * a[10] + b[9] * a[11] - b[8] * a[12] + b[0] * a[13] + b[5] * a[14] - b[2] * a[15];
                    res[14] = b[14] * a[0] + b[10] * a[2] + b[9] * a[3] + b[8] * a[4] + b[4] * a[8] + b[3] * a[9] + b[2] * a[10] + b[0] * a[14];
                    res[15] = b[15] * a[0] + b[14] * a[1] + b[13] * a[2] + b[12] * a[3] + b[11] * a[4] + b[10] * a[5] + b[9] * a[6] + b[8] * a[7] + b[7] * a[8] + b[6] * a[9] + b[5] * a[10] - b[4] * a[11] - b[3] * a[12] - b[2] * a[13] - b[1] * a[14] + b[0] * a[15];

                    return result;
                }

                pub fn gp_old(left: *Self, right: *Self, comptime res_type: ResTypes, res_data: ResSemantics) GetStandardRes(res_type) {
                    const result = get_standard_res(res_type, res_data);

                    inline for (0..Self.Algebra.basis_len) |lhs| {
                        inline for (0..Self.Algebra.basis_len) |rhs| {
                            if (Self.Algebra.mask_zero & lhs & rhs == 0) { //should be collapsed at comptime
                                const cayley_elem = comptime blk: {
                                    break :blk Self.Algebra.gp_cayley[lhs][rhs];
                                };
                                result.terms[cayley_elem.blade] += cayley_elem.value * left.terms[lhs] * right.terms[rhs];
                            }
                        }
                    }
                    return result;
                }

                pub fn gp_better(left: *Self, right: *Self, comptime res_type: ResTypes, res_data: ResSemantics) GetStandardRes(res_type) {
                    const result = get_standard_res(res_type, res_data);

                    //inline for(0..Self.Algebra.basis_len) |blade| {
                    //    var val: f64 = 0;
                    //2 ({us, 0000} * 2) + 2 ** (d - count_bits(blade))
                    //degenerate indices can be created from 2 ** d total basis blade pairs,
                    //non degenerate indices seem to have half as many? 1 / 2 ** num_degen_bases as many?
                    //we want to find every pair of indices that xor into us
                    //    inline for(blade..Self.Algebra.basis_len) |lhs
                    //}

                    inline for (0..Self.Algebra.basis_len) |lhs| {
                        inline for (0..Self.Algebra.basis_len) |rhs| {
                            if (Self.Algebra.mask_zero & lhs & rhs == 0) {
                                const squares: isize = lhs & rhs;
                                const flips = count_flips(lhs, rhs);
                                const value: isize = -2 * (((squares & Self.Algebra.mask_neg) ^ @as(isize, @intCast(flips))) & 1) + 1;
                                const gp_blade: usize = lhs ^ rhs;
                                result.terms[gp_blade] += @as(T, @floatFromInt(value)) * left.terms[lhs] * right.terms[rhs];
                            }
                        }
                    }
                    return result;
                }

                pub fn gp_not_unrolled(left: *Self, right: *Self, comptime res_type: ResTypes, res_data: ResSemantics) GetStandardRes(res_type) {
                    const result = get_standard_res(res_type, res_data);

                    for (0..Self.Algebra.basis_len) |lhs| {
                        for (0..Self.Algebra.basis_len) |rhs| {
                            if (Self.Algebra.mask_zero & lhs & rhs == 0) { //should be collapsed at comptime
                                const cayley_elem = Self.Algebra.gp_cayley[lhs][rhs];
                                result.terms[cayley_elem.blade] += @as(T, @floatFromInt(cayley_elem.value)) * left.terms[lhs] * right.terms[rhs];
                            }
                        }
                    }
                    return result;
                }

                pub fn op(left: anytype, right: anytype, res: anytype) void {
                    const left_type: type = @typeInfo(@TypeOf(left)).Pointer.child;
                    const right_type: type = @typeInfo(@TypeOf(right)).Pointer.child;
                    const res_type: type = @typeInfo(@TypeOf(res)).Pointer.child;

                    const left_set: ux = comptime blk: {
                        break :blk left_type.subset_field;
                    };
                    const right_set: ux = comptime blk: {
                        break :blk right_type.subset_field;
                    };
                    const res_set: ux = comptime blk: {
                        break :blk res_type.subset_field;
                    };

                    const table = comptime Alg.cayley_table(left_set, right_set, Alg.Operation.OuterProduct.BladeOp(), null, null);
                    //tell the table inverter the res size, then we can expect it to return an array with comptime known size
                    const res_size = comptime count_bits(res_set);
                    const operation = comptime Alg.inverse_table_and_op_res_to_scatter_masks(table.snd, table.third, left_set, right_set, res_set, res_size);

                    Alg.execute_sparse_vector_op(left, right, res, comptime operation, comptime res_size, D);
                }

                pub fn op_old(left: *Self, right: *Self, comptime res_type: ResTypes, res_data: ResSemantics) GetStandardRes(res_type) {
                    const result = get_standard_res(res_type, res_data);

                    inline for (0..Self.Algebra.basis_len) |lhs| {
                        inline for (0..Self.Algebra.basis_len) |rhs| {
                            if (lhs & rhs == 0) {
                                const cayley_elem = comptime blk: {
                                    break :blk Self.Algebra.op_cayley[lhs][rhs];
                                };
                                result.terms[cayley_elem.blade] += cayley_elem.value * left.terms[lhs] * right.terms[rhs];
                            }
                        }
                    }

                    return result;
                }

                pub fn ip(left: anytype, right: anytype, res: anytype) void {
                    const left_type: type = @typeInfo(@TypeOf(left)).Pointer.child;
                    const right_type: type = @typeInfo(@TypeOf(right)).Pointer.child;
                    const res_type: type = @typeInfo(@TypeOf(res)).Pointer.child;

                    const left_set: ux = comptime blk: {
                        break :blk left_type.subset_field;
                    };
                    const right_set: ux = comptime blk: {
                        break :blk right_type.subset_field;
                    };
                    const res_set: ux = comptime blk: {
                        break :blk res_type.subset_field;
                    };

                    const table = comptime Alg.cayley_table(left_set, right_set, Alg.Operation.InnerProduct.BladeOp(), null, null);
                    //tell the table inverter the res size, then we can expect it to return an array with comptime known size
                    const res_size = comptime count_bits(res_set);
                    const operation = comptime Alg.inverse_table_and_op_res_to_scatter_masks(table.snd, table.third, left_set, right_set, res_set, res_size);

                    Alg.execute_sparse_vector_op(left, right, res, comptime operation, comptime res_size, D);
                }

                pub fn ip_old(left: *Self, right: *Self, comptime res_type: ResTypes, res_data: ResSemantics) GetStandardRes(res_type) {
                    const result = get_standard_res(res_type, res_data);

                    inline for (0..Self.Algebra.basis_len) |lhs| {
                        inline for (0..Self.Algebra.basis_len) |rhs| {
                            if (Self.Algebra.mask_zero & lhs & rhs == 0) { //should be collapsed at comptime
                                const cayley_elem = comptime blk: {
                                    break :blk Self.Algebra.ip_cayley[lhs][rhs];
                                };
                                result.terms[cayley_elem.blade] += cayley_elem.value * left.terms[lhs] * right.terms[rhs];
                            }
                        }
                    }

                    return result;
                }
                //e0010 * e1111 = -e1101
                //e0100 * e1111 = e1011
                //e1000 * e1111 = -e0111
                //e1010 * e1111 = (val(e1000 * e1111) + val(e0010 * e1111))e0101
                //blade = ~lhs,
                //value = -2 * (count_flips(lhs, 1111...) & 1) + 1
                //count_flips(0100, 1111):
                //lhs := 0100 >> 1 = 0010
                //lhs != 0
                // flips += count_bits(0010 & 1111) = 0 + 1 = 1
                // lhs = 0010 >> 1 = 0001
                //lhs != 0
                // flips += count_bits(0001 & 1111) = 1 + 1 = 2
                // lhs = 0001 >> 1 = 0000
                //lhs == 0: return 2
                //count_flips(x, 1111...) = sum(count_bits(x >>= 1))
                //if in lhs bit i = 1, then flips += pow(2,i-1) (lsb is index 0)

                pub fn rp(left: anytype, right: anytype, res: anytype) void {
                    const left_type: type = @typeInfo(@TypeOf(left)).Pointer.child;
                    const right_type: type = @typeInfo(@TypeOf(right)).Pointer.child;
                    const res_type: type = @typeInfo(@TypeOf(res)).Pointer.child;

                    const left_set: ux = comptime blk: {
                        break :blk left_type.subset_field;
                    };
                    const right_set: ux = comptime blk: {
                        break :blk right_type.subset_field;
                    };
                    const res_set: ux = comptime blk: {
                        break :blk res_type.subset_field;
                    };

                    const table = comptime Alg.cayley_table(left_set, right_set, Alg.Operation.RegressiveProduct.BladeOp(), null, null);
                    //tell the table inverter the res size, then we can expect it to return an array with comptime known size
                    const res_size = comptime count_bits(res_set);
                    const operation = comptime Alg.inverse_table_and_op_res_to_scatter_masks(table.snd, table.third, left_set, right_set, res_set, res_size);

                    Alg.execute_sparse_vector_op(left, right, res, comptime operation, comptime res_size, D);
                }

                pub fn rp_old(left: *Self, right: *Self, comptime res_type: ResTypes, res_data: ResSemantics) GetStandardRes(res_type) {
                    const result = get_standard_res(res_type, res_data);

                    inline for (0..Self.Algebra.basis_len) |lhs| {
                        inline for (0..Self.Algebra.basis_len) |rhs| {
                            const cayley_elem = comptime blk: {
                                break :blk Self.Algebra.rp_cayley[lhs][rhs];
                            };
                            result.terms[cayley_elem.blade] += cayley_elem.value * left.terms[lhs] * right.terms[rhs];
                        }
                    }

                    return result;
                }

                pub fn meet(left: anytype, right: anytype, res: anytype) void {
                    if(comptime Self.Algebra.alg_options.dual == true) {
                        return Self.rp(left,right,res);
                    } else {
                        return Self.op(left,right,res);
                    }
                }

                pub fn join(left: anytype, right: anytype, res: anytype) void {
                    if(comptime Self.Algebra.alg_options.dual == true) {
                        return Self.op(left,right,res);
                    } else {
                        return Self.rp(left,right,res);
                    }
                }

                pub fn grade_project(self: *Self, grade: usize, comptime res_type: ResTypes, res_data: ResSemantics) GetStandardRes(res_type) {
                    const result = get_standard_res(res_type, res_data);

                    inline for (0..Self.Algebra.basis_len) |i| {
                        if (count_bits(i) == grade) { //theres a better way to do this, the next elem of the same grade is 2^ith indices next
                            result.terms[i] = self.terms[i];
                        } else {
                            result.terms[i] = 0.0;
                        }
                    }
                    return result;
                }

                //pub fn unary_op_handle_result(self: *Self, res_arg: anytype, operation: Operation) void {}

                ///i want to be able to handle:
                /// allocating a new result (res_arg is an allocator),
                /// mutating a passed in result (res_arg is a ptr that must have the correct subset),
                /// stack allocating a new result (res_arg is null)
                //pub fn UnaryOpResultType(self: anytype, res_arg: anytype, operation: Operation) type {
                //    const ResArg: type = @TypeOf(res_arg);
                //    const ResInfo = @typeInfo(ResArg);
                //    const SelfInfo = @typeInfo(@TypeOf(self));
                //    var mutate_res_arg: bool = false;
                //    switch(ResInfo) {
                //        .Optional => {
                //            if(res_arg == null) {
                //
                //                return void; //in place mutation or stack allocation
                //            } else {
                //
                //            }
                //        },
                //        .Null => {
                //
                //        }
                //    }
                //}


                ///subset invariant
                /// 0 1 10, 11, 100, 101, 110, 111
                /// +,+,-,-,+,+,-,-,+,+,...
                pub fn revert(self: *Self) *Self {
                    const one: ux = 0b1;
                    inline for (0..Self.Algebra.basis_len) |blade| {
                        if (Self.subset_field & (one << @as(ud, @truncate(blade))) != 0) {
                            const i = count_bits(Self.subset_field & (one << @as(ud, @truncate(blade))) -% 1);
                            const mult: T = comptime blk: {
                                var x: usize = count_bits(blade); //this is correct
                                x >>= 1;
                                if (x & 1 == 0) {
                                    break :blk 1.0;
                                }
                                break :blk -1.0;
                            };
                            self.terms[i] = mult * self.terms[i];
                        }
                    }
                    return self;
                }

                //TODO: figure out return semantics api that doesnt suck ass to use and to write
                //pub fn reverse(self: *Self) Self {
                //    const result: *Self = blk: {
                //        switch(res_type) {
                //            .alloc_new => break :blk try res_data.alloc_new.create(Self),
                //            .ptr => break :blk res_data.ptr,
                //        }
                //    };
                //
                //}

                pub fn invert(self: *Self) *Self {
                    _=self.revert();
                    //const mag = self.magnitude_squared();
                    //var x = self.copy(Self);
                    //_=x.mul_scalar(1.0 / mag, .ptr, .{.ptr = self});
                    return self.normalize(.ptr, .{.ptr=self});
                }

                //pub fn inverse(self: *Self) Self {
                // 
                //}

                const SubsetResultEnum = enum {
                    into,
                    //minimum,
                    mvec,
                    //infer
                };

                const SubsetResult = union(SubsetResultEnum) {
                    /// forces
                    into: ux,
                    //minimum,
                    mvec,
                    //infer,
                };

                //const DataResult = enum { ptr, allocator, stack_alloc };
                const DataResultEnum = enum {
                    ptr,
                    allocator,
                    stack_alloc,
                };
                pub fn DataResult(comptime sbset_res: SubsetResult) type {
                    return union(DataResultEnum) { ptr: switch (sbset_res) {
                        .into => *MVecSubset(sbset_res.into),
                        .mvec => *MVecSubset(Alg.NVec.subset_field),
                    }, allocator: *Allocator, stack_alloc };
                }

                pub fn DualResult(comptime res: SubsetResult, comptime data: DataResult(res)) type {
                    switch (res) {
                        .into => {
                            switch (std.meta.activeTag(data)) {
                                .ptr => {
                                    return *MVecSubset(res.into);
                                },
                                .allocator => {
                                    return !*MVecSubset(res.into);
                                },
                                .stack_alloc => {
                                    return MVecSubset(res.into);
                                },
                            }
                        },
                        //.minimum => {
                        //    switch (std.meta.activeTag(data)) {
                        //        .ptr => {
                        //            if (@TypeOf(data.ptr) == *Alg.NVec) {
                        //                return *Alg.NVec;
                        //            }
                        //            @compileError("passed .mvec and a pointer to a non mvec to a function!");
                        //        },
                        //        .allocator => {
                        //            return !*Alg.NVec;
                        //        },
                        //        .stack_alloc => {
                        //            return Alg.NVec;
                        //        },
                        //    }
                        //},
                        .mvec => {
                            switch (std.meta.activeTag(data)) {
                                .ptr => {
                                    if (@TypeOf(data.ptr) == *Alg.NVec) {
                                        return *Alg.NVec;
                                    }
                                    @compileError("passed .mvec and a pointer to a non mvec to a function!");
                                },
                                .allocator => {
                                    return !*Alg.NVec;
                                },
                                .stack_alloc => {
                                    return Alg.NVec;
                                },
                            }
                        },
                        //.infer => {
                        //    switch (std.meta.activeTag(data)) {
                        //        .ptr => {
                        //            if (@TypeOf(data.ptr) == *Alg.NVec) {
                        //                return *Alg.NVec;
                        //            }
                        //            @compileError("passed .mvec and a pointer to a non mvec to a function!");
                        //        },
                        //        .allocator => {
                        //            return !*Alg.NVec;
                        //        },
                        //        .stack_alloc => {
                        //            return Alg.NVec;
                        //        },
                        //    }
                        //},
                    }
                }

                pub fn get_dual_result(comptime res: SubsetResult, data: DataResult(res)) DualResult(res, data) {
                    if (data.ptr) {
                        return data.ptr;
                    }
                    const Res: type = DualResult(res, data);
                    if (std.meta.activeTag(data) == DataResultEnum.allocator) {
                        const x = try data.create(Res);
                        x.zeros();
                        return x;
                    }
                    if (std.meta.activeTag(data) == DataResultEnum.stack_alloc) {
                        const x: Res = undefined;
                        x.zeros();
                        return x;
                    }
                }

                ///changes subsets
                /// if we have a blade at bit index i, our dual must have a blade at bit index basis_len - 1 - i
                /// in other words our dual has our subset but mirror across the middle at minimum
                pub fn dual(self: *Self, result: *NVec) *NVec {
                    const table = comptime unary_cayley_table(Self.subset_field, Operation.Dual.BladeOp(), null);
                    const masks = comptime unary_inverse_table_to_scatter_mask(table.snd, Self.subset_field, NVec.subset_field, count_bits(NVec.subset_field));
                    unary_execute_sparse_vector_op(self, result, masks, count_bits(NVec.subset_field), D);

                    //inline for (0..Self.Algebra.basis_len) |i| {
                    //    result.terms[i] = self.terms[Self.Algebra.basis_len - 1 - i];
                    //}
                    return result;
                }

                pub fn involution(self: *Self, comptime res_type: ResTypes, res_data: ResSemantics) GetStandardRes(res_type) {
                    const result = get_standard_res(res_type, res_data);

                    const len = comptime count_bits(@TypeOf(result).subset_field);
                    var _coeffs: @Vector(len, T) = undefined;
                    comptime {
                        const one: ux = 0b1;
                        var i = 0;
                        for (0..basis_len) |blade| {
                            const blade_t: ud = @truncate(blade);
                            if (Self.subset_field & (one << blade_t) == 0) {
                                continue;
                            }
                            var val = 1.0;
                            if (blade & 1) {
                                val = -1.0;
                            }
                            _coeffs[i] = val;
                            i += 1;
                        }
                    }
                    const coeffs = _coeffs;

                    result.terms = coeffs * self.terms;

                    return result;
                }

                //pub fn norm(self: Self) -> Scalar {
                //    let scalar_part = (self * self.Conjugate())[0];
                //
                //    scalar_part.abs().sqrt()
                //} we need gp with reverse

                pub fn magnitude_squared(self: *Self) T {
                    @setEvalBranchQuota(100000);
                    //var scalar: T = 0;

                    var gp_res = NVec{.terms = undefined};
                    _=gp_res.zeros();

                    //_= self.gp(self, gp_res.zeros());
                    var cop = self.copy(Self);
                    _ = cop.revert();
                    //return @reduce(.Add, (&cop).gp(self, gp_res).terms);
                    return (&cop).gp(self, &gp_res).terms[0];

                }

                pub fn magnitude(self: *Self) T {
                    return @sqrt(@abs(self.magnitude_squared()));
                }

                pub fn normalize(self: *Self, comptime res_type: ResTypes, res_data: ResSemantics) GetStandardRes(res_type) {
                    return self.mul_scalar(1.0 / self.magnitude(), res_type, res_data);
                }

                //in non degenerate algebras only squares of blades are scalars,
                //in degenerate algebras the only non squares that equal 0 are degenerate blades
                //
                //for bivector B:
                //if B ** 2 = -1 then e^tB = cos(t) + Bsin(t) = rotor
                //if B ** 2 = 0 then e^tB = 1 + tB = motor
                //if B ** 2 = 1 then e^tB = cosh(t) + Bsinh(t) = boost
                //e^x = 1 + x^1/1! + x^2/2! + x^3/3! + ...
                //pub fn exp(self: *Self, coeff: T) NVec {
                //    var res = 
                //}

                pub fn copy(self: *Self, comptime res_type: type) res_type {
                    var cop = res_type{.terms = @splat(0)};
                    _=cop.zeros();
                    var copcop = res_type{.terms = @splat(0)};
                    _=res_type.add(&copcop, self, &cop);
                    //@memcpy(&cop.terms, &self.terms);
                    return cop;
                }

                pub fn sandwich(bread: *Self, meat: anytype) NVec {
                    //const stdout = std.io.getStdOut().writer();
                    //try stdout.print("\nbread: {}", .{bread});
                    //var us = bread.copy(NVec);
                    var other_slice = bread.copy(Self);
                    //debug.print("\n\tother_slice = bread.copy(Self) = {}", .{other_slice});
                    _ = other_slice.revert();
                    //debug.print("\n\tother_slice.revert(): {}", .{other_slice});
                    //const meat_cop = meat.copy(NVec);
                    //debug.print("\n\tmeat_cop: {}", .{meat_cop});
                    var ret = NVec{.terms = @splat(0)};
                    _=ret.zeros();

                    //try stdout.print("\nret.zeros(): {}", .{ret});



                    _=bread.gp(meat, &ret);
                    
                    //std.debug.print("\n\t{} gp {} = {}", .{bread, meat, ret});

                    var ret2 = NVec{.terms = @splat(0)};

                    _=ret.gp(&other_slice, &ret2);

                    //try stdout.print("\n({} gp {}) gp {} = {}", .{bread, meat_cop, other_slice, ret2});

                    return ret2;
                }

                fn get_square(self: *Self) NVec {//TODO: might blow up if something squares to a multivector
                    var ret = NVec{.terms=@splat(0)};

                    var x = self.copy(NVec);
                    var y = self.copy(NVec);
                    //var neg_one = Self{.terms=@splat(0)};
                    _ = x.gp(&y, &ret);
                    return ret;
                }

                pub fn exp(self: *Self, terms: usize) NVec {
                    var ret = NVec{.terms = @splat(0)};
                    var cop = self.copy(NVec);

                    const square = self.get_square();
                    if(@reduce(.Add, square.terms) == square.terms[0]) {

                        //debug.print("\n\t{} ^ 2 == {}, a scalar.", .{self, square});

                        const squared_value = square.terms[0];
                        const alpha = @sqrt(@abs(square.terms[0]));

                        if(squared_value < 0.0) {
                            _=cop.mul_scalar(@sin(alpha) / alpha, .ptr, .{.ptr=&ret});
                            ret.terms[0] += @cos(alpha);
                            //debug.print("\n\t\texp({}) = cos(alpha) + (sin(alpha)/alpha)*self = {} (square is {d:.4}, alpha {d:.4})", .{self, ret, squared_value, alpha});
                            return ret;
                        }
                        if(squared_value > 0.0) {
                            _=cop.mul_scalar(sinh(alpha) / alpha, .ptr, .{.ptr=&ret});
                            ret.terms[0] += cosh(alpha);
                            //debug.print("\n\t\texp({}) = cosh(mag) + (sinh(mag)/mag)*self = {} (square is {}, mag {})", .{self, ret, alpha, mag});
                            return ret;
                        }
                        if(squared_value == 0.0) {
                            cop.terms[0] += 1.0;
                            //ebug.print("\n\t\texp({}) = 1 + self = {} (square is {}, mag {})", .{self, ret, alpha, self.magnitude()});
                            return cop;
                        }    
                    }
                    //debug.print("\n\t{} ^ 2 == {}, not a scalar", .{self, square});

                    //1 + x + (x^2)/2! + (x^3)/3! + (x^4)/4! + ...
                    ret.terms[0] = 1.0;
                    for(1..terms) |t| {
                        const denominator: f64 = @floatFromInt(factorial(t));
                        var term = self.copy(NVec);

                        for(1..t) |_| {
                            var tst = NVec{.terms=@splat(0)};
                            term = NVec.gp(&term,&cop, &tst).*;
                        }

                        var tst = NVec{.terms=@splat(0)};
                        var rhs = term.mul_scalar((1.0/denominator), .stack_alloc, .{.ptr=&tst});
                        ret = ret.add(&rhs, &tst).*;
                    }
                    return ret;
                }

                ///returns true if we are a subset of other, or if our only nonzero indices are in other
                pub fn is(self: *Self, other: type) bool {
                    if(comptime Self.subset_field & other.subset_field == Self.subset_field) {
                        return true;
                    }
                    const one: ux = 0b1;
                    for(0..basis_len) |blade| {
                        const blade_t: ud = @truncate(blade);
                        if(other.subset_field & (one << blade_t) != 0 and Self.subset_field & (one << blade_t) != 0) {
                            if(self.terms[count_bits(Self.subset_field & ((one << blade_t) -% 1))] != 0.0) {
                                return false;
                            }
                        }
                    }
                    return true;
                }

            };
            return ret;
        }

        pub fn enums_to_subset(enum_slice: []const BasisBladeEnum) usize {
            var ret: usize = 0b0;
            for (enum_slice) |e| {
                ret |= (0b1 << @intFromEnum(e));
            }
            return ret;
        }

        pub const NVec = MVecSubset(enums_to_subset(&BasisBlades));
        pub const Plane = blk: {
            
            if (p >= 1 and z == 1 and n == 0) { // pga
                if(alg_options.dual == true) {
                    if(d == 2) {
                        break :blk KVector(2);
                    } else {
                        break :blk KVector(p - 2);
                    }
                } else {
                    break :blk KVector(2);
                }
                //planes are either the pseudospace (p == 2), so KVector(p + 1), 
                //or less than the pseudospace (p > 2), so KVector(1)
                //break :blk KVector(p - 1); //&.{0b0001,0b0010,0b0100,0b1000});
            }
            break :blk void;
        };
        pub const Point = blk: {
            if(p >= 1 and z == 1 and n == 0) {
                if(alg_options.dual == true) {
                    break :blk KVector(d-1);
                } else {
                    break :blk KVector(1);
                }
            }
            break :blk void;
        };
        pub const Motor = blk: {
            if (p == 3 and z == 1 and n == 0) {
                //@compileLog("0b1011001101001: ", 0b1011001101001, "enums_to_subset(&.{.s,.e01,.e02,.e03,.e12,.e13,.e23}): ", enums_to_subset(&.{.s,.e01,.e02,.e03,.e12,.e13,.e23}));
                //s,e01,e02,e03,e12,e13,e23
                break :blk MVecSubset(KVector(2).subset_field | 1); //&.{0,0b0011,0b0101,0b1001, 0b0110,0b1100});
            }
            break :blk void;
        };
        pub fn KVector(comptime count: anytype) type {
            var field: ux = 0b0;
            const one: ux = 0b1;
            for(0..basis_len) |blade| {
                const b_idx = one << blade;
                if(count_bits(blade) == count) {
                    field |= b_idx;
                }
            }
            if(count_bits(field) != 0) {
                return MVecSubset(field);
            }
            return void;
        }

        pub const KVectors = blk: {
            var res: [d]type = undefined;
            for(0..d) |i| {
                const dim = i + 1;
                res[i] = KVector(dim);
            }
            const _res = res;
            break :blk _res;
        };
    };

    return alg;
}
