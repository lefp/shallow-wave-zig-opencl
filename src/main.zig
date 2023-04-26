
//
// GLOBAL CONSTANTS ==========================================================================================
//

// @note when modifying any value, make sure the others match
const PIXEL_FORMAT = struct {
    // @note: unintuitively, SDL_PIXELFORMAT_RGBA32 is the format in which bytes are in RGBA order regardless
    // of endianness, while RGBA8888's byte order DOES depend on endianness.
    // See this comment from "SDL2/SDL_pixels.h", about the `struct SDL_Color { Uint8 r, g, b, a }`:
    // * The bits of this structure can be directly reinterpreted as an integer-packed
    // * color which uses the SDL_PIXELFORMAT_RGBA32 format (SDL_PIXELFORMAT_ABGR8888
    // * on little-endian systems and SDL_PIXELFORMAT_RGBA8888 on big-endian systems).
    const sdl_format = c.SDL_PIXELFORMAT_RGBA32; // not using RGB888 because don't wanna deal with the OpenCL memory alignment
    const opencl_format = cl.ImageFormat {
        .channel_order = cl.ImageFormat.ChannelOrder.RGBA,
        .channel_data_type = cl.ImageFormat.ChannelDataType.unorm_int8,
    };
    const bytes_per_pixel = 4;
};

const OPENCL_PROGRAM_SRC_PATH = "src/kernels.cl";

const SIMULATION_KERNEL_PARAM_INDICES = struct {
    const h: u32 = 0;
    const w: u32 = 1;
};
const RENDER_KERNEL_PARAM_INDICES = struct {
    const render_target: u32 = 0;
    const h            : u32 = 1;
    const axis_min     : u32 = 2;
    const axis_max     : u32 = 3;
};

const GRID = struct {
    const domain_size = struct {
        const x: f32 = 25;
        const y: f32 = 25;
    };
    const n_gridpoints = struct {
        const x: u32 = 100;
        const y: u32 = 100;
        const total: u32 = x * y;
    };

    // derived
    const spatial_step = struct {
        const x: f32 = domain_size.x / @as(f32, n_gridpoints.x);
        const y: f32 = domain_size.y / @as(f32, n_gridpoints.y);
    };
};

const TIME_STEP: f32 = 0.00001;

const INITIAL_CONDITIONS = struct { // @continue
    const fluid_depth: f32 = 1; // do not set to 0, else expect freaky behavior
    const wave_height: f32 = 0.1; // height of the wave above the rest of the fluid surface
    const wave_stddev = struct {
        const x: f32 = 1;
        const y: f32 = 1;
    };
    const wave_relative_centerpoint = struct { // "relative" meaning "in normalized [0, 1] coordinates"
        const x: f32 = 0.75;
        const y: f32 = 0.50;
    };

    // derived
    const wave_centerpoint = struct {
        const x: f32 = wave_relative_centerpoint.x * GRID.domain_size.x;
        const y: f32 = wave_relative_centerpoint.y * GRID.domain_size.y;
    };
};

const TEXTURE = struct {
    const width : usize = 800;

    // derived
    const height: usize = (GRID.domain_size.y / GRID.domain_size.x) * @intToFloat(f32, width);
    const n_pixels: usize = width*height;
};

const FRAMERATE = struct {
    const fps: usize = 60;

    // derived
    const interval_nanoseconds: u64 = 1_000_000_000 / fps;
};

//
// IMPORTS ===================================================================================================
//

const std = @import("std");
const cl = @import("opencl.zig");
const c = @cImport({
    // can enforce OpenCL version (at comptime, I think) here via e.g.:
    // @cDefine("CL_TARGET_OPENCL_VERSION", "120");
    @cInclude("SDL2/SDL.h");
});

const log = std.log;
const time = std.time;
const allocator = std.heap.c_allocator;
const Atomic = std.atomic.Atomic;
const AtomicOrdering = std.atomic.Ordering;
const Thread = std.Thread;

//
// MAIN ======================================================================================================
//

pub fn main() !void {

    // OpenCL initialization ---------------------------------------------------------------------------------

    const ocl_device = select_device: {
        const platform_ids = try cl.getAllPlatformIDs(allocator);
        defer allocator.free(platform_ids);
        if (platform_ids.len == 0) @panic("no OpenCL platforms found");
        log.info("Found {} OpenCL platforms.", .{platform_ids.len});

        // @todo smarter platform selection
        const selected_platform = platform_ids[0];

        const platform_name = try cl.getPlatformName(selected_platform, allocator);
        defer allocator.free(platform_name);
        log.info("Chose platform {s}.", .{platform_name});

        const device_ids = try cl.getAllDeviceIDs(selected_platform, cl.DEVICE_TYPE_GPU, allocator);
        defer allocator.free(device_ids);
        if (device_ids.len == 0) @panic("no devices found for chosen OpenCL platform");
        // @todo smarter device selection
        const selected_device = device_ids[0];

        const device_name = try cl.getDeviceName(selected_device, allocator);
        log.info("Chose device {s}.", .{device_name});

        break :select_device selected_device;
    };

    const ocl_context = try cl.createContext(&[_]cl.Device{ocl_device});
    defer cl.releaseContext(ocl_context) catch log.warn("failed to release context", .{});

    const sim_render_queue = try cl.createCommandQueue(ocl_context, ocl_device, .{});
    defer cl.releaseCommandQueue(sim_render_queue) catch log.warn("failed to release queue", .{});

    const data_transfer_queue = try cl.createCommandQueue(ocl_context, ocl_device, .{});
    defer cl.releaseCommandQueue(data_transfer_queue) catch log.warn("failed to release queue", .{});

    const ocl_image = try cl.createImage(
        ocl_context,
        cl.MemFlags { .write_only = true, .host_read_only = true },
        PIXEL_FORMAT.opencl_format,
        cl.ImageDescriptor {
            .type = cl.MemObjectType.image2d,
            .width  = TEXTURE.width,
            .height = TEXTURE.height,
            .depth = 1,
            .image_array_size = 1,
            .row_pitch = 0,
            .slice_pitch = 0,
            .mem_object = null,
        },
        null
    );
    defer cl.releaseMemObject(ocl_image) catch log.warn("failed to release image", .{});

    const ocl_h_buffer = create_initialized_h_buf: {
        var h_vals: []f32 = try allocator.alloc(f32, GRID.n_gridpoints.total);
        defer allocator.free(h_vals);

        for (h_vals, 0..) |*val, i| {
            const xcoord: f32 = @intToFloat(f32, i % GRID.n_gridpoints.x) * GRID.spatial_step.x;
            const ycoord: f32 = @intToFloat(f32, i / GRID.n_gridpoints.x) * GRID.spatial_step.y;
            val.* = INITIAL_CONDITIONS.fluid_depth + INITIAL_CONDITIONS.wave_height * gaussian2d(
                xcoord,
                ycoord,
                INITIAL_CONDITIONS.wave_stddev.x,
                INITIAL_CONDITIONS.wave_stddev.y,
                INITIAL_CONDITIONS.wave_centerpoint.x,
                INITIAL_CONDITIONS.wave_centerpoint.y,
            );
        }

        const h_buf = try cl.createBuffer(
            ocl_context,
            cl.MemFlags { .read_write = true, .host_no_access = true, .copy_host_ptr = true },
            GRID.n_gridpoints.total * @sizeOf(f32),
            h_vals.ptr
        );
        break :create_initialized_h_buf h_buf;
    };
    defer cl.releaseMemObject(ocl_h_buffer) catch log.warn("failed to release h buffer", .{});

    const ocl_w_buffer = create_initialized_w_buf: {
        var w_vals = try allocator.alloc(cl.Float2, GRID.n_gridpoints.total);
        defer allocator.free(w_vals);

        for (w_vals) |*val| val.* = cl.Float2 { .vec = .{ .x = 0, .y = 0} };

        const w_buf = try cl.createBuffer(
            ocl_context,
            cl.MemFlags { .read_write = true, .host_no_access = true, .copy_host_ptr = true },
            GRID.n_gridpoints.total * @sizeOf(cl.Float2),
            w_vals.ptr
        );
        break :create_initialized_w_buf w_buf;
    };
    defer cl.releaseMemObject(ocl_w_buffer) catch log.warn("failed to release w buffer", .{});

    const ocl_program = build_program: {
        const file = try std.fs.cwd().openFile(OPENCL_PROGRAM_SRC_PATH, .{});
        const file_len = try file.getEndPos() + 1;
        const src = try file.readToEndAlloc(allocator, file_len);
        defer allocator.free(src);
        file.close();

        const program = try cl.createProgramWithSource(ocl_context, src);

        // Stupid hack for defining compile-time constants in OpenCL kernels at application run-time.
        // An alternative is SPIRV specialization constants, but OpenCL 3.0 doesn't guarantee support.
        // Floats are printed in exponential notation, to avoid data loss for very small values.
        // @todo maybe come up with a wrapper function to handle this; it'd be a convenient tool to have.
        // @note Make sure there is a space between consecutive arguments.
        const preproc_defs = try std.fmt.allocPrintZ(
            allocator,
            "-D TIME_STEP={[ts]e:.100}"       ++ " " ++
            "-D SPATIAL_STEP_X={[ssx]e:.100}" ++ " " ++
            "-D SPATIAL_STEP_Y={[ssy]e:.100}" ++ " " ++
            "-D N_GRIDPOINTS_X={[ngx]d}"      ++ " " ++
            "-D N_GRIDPOINTS_Y={[ngy]d}",
            .{
                .ts  = TIME_STEP,
                .ssx = GRID.spatial_step.x,
                .ssy = GRID.spatial_step.y,
                .ngx = GRID.n_gridpoints.x,
                .ngy = GRID.n_gridpoints.y,
            }
        );
        log.info("Passing OpenCL preprocessor definitions: {s}", .{preproc_defs});
        try cl.buildProgram(program, &[_]cl.Device{ocl_device}, preproc_defs);

        break :build_program program;
    };
    defer cl.releaseProgram(ocl_program) catch log.warn("failed to release program", .{});

    const simulation_kernel = try cl.createKernel(ocl_program, "iterate");
    defer cl.releaseKernel(simulation_kernel) catch log.warn("failed to release simulation kernel", .{});
    try cl.setKernelArg(simulation_kernel, SIMULATION_KERNEL_PARAM_INDICES.h, cl.Mem, &ocl_h_buffer);
    try cl.setKernelArg(simulation_kernel, SIMULATION_KERNEL_PARAM_INDICES.w, cl.Mem, &ocl_w_buffer);

    const render_kernel = try cl.createKernel(ocl_program, "render");
    defer cl.releaseKernel(render_kernel) catch log.warn("failed to release render kernel", .{});
    try cl.setKernelArg(render_kernel, RENDER_KERNEL_PARAM_INDICES.render_target, cl.Mem, &ocl_image   );
    try cl.setKernelArg(render_kernel, RENDER_KERNEL_PARAM_INDICES.h            , cl.Mem, &ocl_h_buffer);
    try cl.setKernelArg(render_kernel, RENDER_KERNEL_PARAM_INDICES.axis_min     ,    f32, &INITIAL_CONDITIONS.fluid_depth);
    try cl.setKernelArg(render_kernel, RENDER_KERNEL_PARAM_INDICES.axis_max     ,    f32, &(INITIAL_CONDITIONS.fluid_depth + INITIAL_CONDITIONS.wave_height));

    // SDL initialization ------------------------------------------------------------------------------------

    enforce0(c.SDL_Init(c.SDL_INIT_VIDEO));
    defer c.SDL_Quit();

    const window = c.SDL_CreateWindow(
        "fuckin window",
        c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED,
        TEXTURE.width, TEXTURE.height,
        0 // window is only resizeable if we set that flag
    ).?;
    defer c.SDL_DestroyWindow(window);

    // @todo maybe use the "surface and direct pixel buffer access" method instead of using SDL's renderer;
    // it's probably more efficient that way, since we're already doing our own rendering. Although, maybe the
    // texture method will make it easier to support high-DPI screens (i.e., to not produce a tiny display).
    const sdl_renderer: *c.SDL_Renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_PRESENTVSYNC).?;
    defer c.SDL_DestroyRenderer(sdl_renderer);

    const sdl_texture: *c.SDL_Texture = c.SDL_CreateTexture(
        sdl_renderer,
        PIXEL_FORMAT.sdl_format,
        c.SDL_TEXTUREACCESS_STREAMING, // for textures that change frequently
        TEXTURE.width, TEXTURE.height
    ).?;
    defer c.SDL_DestroyTexture(sdl_texture);

    // misc initialization -----------------------------------------------------------------------------------

    // @todo Let OpenCL allocate this using CL_MEM_ALLOC_HOST_PTR, because "something something pinned memory
    // is fast".
    var pixel_hostbuffer: [TEXTURE.n_pixels*PIXEL_FORMAT.bytes_per_pixel]u8 = undefined;

    // render first frame
    try cl.enqueueNDRangeKernel(
        sim_render_queue,
        render_kernel,
        2,
        null,
        &[_]usize {TEXTURE.width, TEXTURE.height},
        null,
        null,
        null
    );
    try cl.enqueueReadImage(
        sim_render_queue, // same queue, we want it to happen in order
        ocl_image,
        true,
        &[_]usize {0, 0, 0},
        &[_]usize {TEXTURE.width, TEXTURE.height, 1},
        TEXTURE.width * PIXEL_FORMAT.bytes_per_pixel,
        0,
        &pixel_hostbuffer,
        null,
        null
    );

    enforce0(
        c.SDL_UpdateTexture(sdl_texture, null, &pixel_hostbuffer, TEXTURE.width*PIXEL_FORMAT.bytes_per_pixel)
    );
    enforce0(c.SDL_RenderCopy(sdl_renderer, sdl_texture, null, null));
    c.SDL_RenderPresent(sdl_renderer);

    // main loop ---------------------------------------------------------------------------------------------

    // loop variables
    var sdl_event: c.SDL_Event = undefined;
    var frame_timer = try time.Timer.start();
    var paused = Atomic(bool).init(true);

    // launch sim thread
    var sim_thread_should_quit = Atomic(bool).init(false);
    const sim_thread = try Thread.spawn(
        .{},
        simulation_thread,
        .{ sim_render_queue, simulation_kernel, &paused, &sim_thread_should_quit }
    );

    main_loop: while (true) {
        // process pending events
        while (c.SDL_PollEvent(&sdl_event) != 0) {
            switch (sdl_event.type) {
                c.SDL_QUIT => {
                    sim_thread_should_quit.store(true, AtomicOrdering.Monotonic);
                    break :main_loop;
                },
                c.SDL_KEYDOWN => {
                    if (sdl_event.key.keysym.sym == c.SDLK_p) paused.store(
                        !paused.loadUnchecked(), AtomicOrdering.Monotonic
                    );
                },
                else => {},
            }
        }

        // if paused, take no further action
        if (paused.loadUnchecked()) continue;

        // update display
        if (frame_timer.read() >= FRAMERATE.interval_nanoseconds) {
            frame_timer.reset();
            try cl.enqueueNDRangeKernel(
                sim_render_queue,
                render_kernel,
                2,
                null,
                &[_]usize {TEXTURE.width, TEXTURE.height},
                null,
                null,
                null
            );
            try cl.enqueueReadImage(
                data_transfer_queue,
                ocl_image,
                true,
                &[_]usize {0, 0, 0},
                &[_]usize {TEXTURE.width, TEXTURE.height, 1},
                TEXTURE.width * PIXEL_FORMAT.bytes_per_pixel,
                0,
                &pixel_hostbuffer,
                null,
                null
            );
            enforce0(c.SDL_UpdateTexture(
                sdl_texture, null, &pixel_hostbuffer, TEXTURE.width*PIXEL_FORMAT.bytes_per_pixel
            ));
            enforce0(c.SDL_RenderCopy(sdl_renderer, sdl_texture, null, null));
            c.SDL_RenderPresent(sdl_renderer);
        }
    }

    log.info("Main: waiting for simulation thread to finish.", .{});
    sim_thread.join();
    log.info("Quitting.\n", .{});
}

fn simulation_thread(
    queue: cl.CommandQueue,
    simulation_kernel: cl.Kernel,
    paused: *const Atomic(bool),
    quit: *const Atomic(bool) // @note these two atomics would be more efficient in one variable, but keeping it simple for now
) !void {
    // We use batching, and wait for batch k-1 to complete before enqueueing batch k+1.
    // This is because simply enqueueing commands nonstop can cause the queue to grow unboundedly,
    // eating up all the host's memory.
    // At least, that's what I think happened to me. In any case, the OpenCL spec doesn't protect against that.
    const batch_size: usize = 1000;

    // increment OpenCL reference counts, just to be safe
    try cl.retainCommandQueue(queue);
    defer cl.releaseCommandQueue(queue) catch log.warn("sim thread: failed to release command queue", .{});
    try cl.retainKernel(simulation_kernel);
    defer cl.releaseKernel(simulation_kernel) catch log.warn("sim thread: failed to release kernel", .{});

    var iters_completed: usize = 0;
    var print_timer: time.Timer = try time.Timer.start();
    // note: this start time is meaningless; don't take the first value seriously
    var batch_timer: time.Timer = try time.Timer.start();
    var last_batch_duration_nanoseconds: u64 = 0;
    var batch_event_0: cl.Event = try enqueue_sim_batch(batch_size, queue, simulation_kernel);
    var batch_event_1: cl.Event = try enqueue_sim_batch(batch_size, queue, simulation_kernel);

    // @todo return when some condition is satisfied, so that the main thread doesn't need to kill this one
    while (true) {
        if (quit.*.load(AtomicOrdering.Monotonic)) break;
        // @todo don't busy-wait; maybe use a Semaphore?
        if (paused.*.load(AtomicOrdering.Monotonic)) continue;

        try cl.waitForEvents(&.{batch_event_0});
        last_batch_duration_nanoseconds = batch_timer.lap();
        iters_completed += batch_size;
        try cl.releaseEvent(batch_event_0);
        batch_event_0 = batch_event_1;
        batch_event_1 = try enqueue_sim_batch(batch_size, queue, simulation_kernel);


        // print iteration info
        if (print_timer.read() >= time.ns_per_s) { // one second
            print_timer.reset();
            // @todo not sure of the appropriate log type to use here; maybe create a special "perf" log
            // output thing? We don't want a shitton of these messages being written to a file.
            log.debug(
                "iteration: {:10} ({d:7.0} per second)",
                .{
                    iters_completed,
                    @as(f32, batch_size) * time.ns_per_s / @intToFloat(f32, last_batch_duration_nanoseconds),
                }
            );
        }
    }

    // clean up
    try cl.waitForEvents(&.{batch_event_1});
    try cl.releaseEvent(batch_event_0);
    try cl.releaseEvent(batch_event_1);
}

/// Returns an event associated with the last command in the batch.
/// @note The caller is responsible for calling `releaseEvent()` on every returned event!
fn enqueue_sim_batch(batch_size: usize, queue: cl.CommandQueue, kernel: cl.Kernel) cl.OpenClErr!cl.Event {
    for (0..batch_size-1) |_| {
        try cl.enqueueNDRangeKernel(
            queue, kernel, 2, null,
            &[_]usize {GRID.n_gridpoints.x, GRID.n_gridpoints.y},
            null, null, null
        );
    }

    var event: cl.Event = undefined;
    try cl.enqueueNDRangeKernel(
        queue, kernel, 2, null,
        &[_]usize {GRID.n_gridpoints.x, GRID.n_gridpoints.y},
        null, null, &event
    );

    try cl.flush(queue);
    return event;
}

//
// STRUCTS AND FUNCTIONS =====================================================================================
//

// const PixelFormat = struct {
//     opencl_format: c.cl_image_format,
//     bytes_per_pixel: usize,
//     sdl_format: c.SDL_PixelFormatEnum,
// };

inline fn enforce0(val: c_int) void {
    if (val != 0) @panic("Value was not 0");
}

inline fn square(x: anytype) @TypeOf(x) { return x*x; }

fn gaussian2d(xcoord: f32, ycoord: f32, stddev_x: f32, stddev_y: f32, center_x: f32, center_y: f32) f32 {
    return @exp( -0.5 * (
        square((xcoord - center_x) / stddev_x) +
        square((ycoord - center_y) / stddev_y)
    ));
}
