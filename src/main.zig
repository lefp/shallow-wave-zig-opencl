
//
// GLOBAL CONSTANTS ==========================================================================================
//

// @todo is there any reason to make these types `comptime_int`?
const TEXTURE_WIDTH : usize = 800;
const TEXTURE_HEIGHT: usize = 600;
const PIXEL_FORMAT = .{ // @note when modifying any value, make sure the others match
    // @note: unintuitively, SDL_PIXELFORMAT_RGBA32 is the format in which bytes are in RGBA order regardless
    // of endianness, while RGBA8888's byte order DOES depend on endianness.
    // See this comment from "SDL2/SDL_pixels.h", about the `struct SDL_Color { Uint8 r, g, b, a }`:
    // * The bits of this structure can be directly reinterpreted as an integer-packed
    // * color which uses the SDL_PIXELFORMAT_RGBA32 format (SDL_PIXELFORMAT_ABGR8888
    // * on little-endian systems and SDL_PIXELFORMAT_RGBA8888 on big-endian systems).
    .sdl_format = c.SDL_PIXELFORMAT_RGBA32, // not using RGB888 because don't wanna deal with the memory alignment
    .opencl_format = cl.ImageFormat {
        .channel_order = cl.ImageFormat.ChannelOrder.RGBA,
        .channel_data_type = cl.ImageFormat.ChannelDataType.unorm_int8,
    },
    .bytes_per_pixel = 4,
};
const OPENCL_PROGRAM_SRC_PATH = "src/kernels.cl";

// derived constants
const N_PIXELS: usize = TEXTURE_WIDTH*TEXTURE_HEIGHT;

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
const allocator = std.heap.c_allocator;

//
// MAIN ======================================================================================================
//

pub fn main() !void {

    // OpenCL initialization ---------------------------------------------------------------------------------

    const device = select_device: {
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
    const context = try cl.createContext(&[_]cl.Device{device});
    defer cl.releaseContext(context) catch log.warn("failed to release context", .{});
    const queue = try cl.createCommandQueue(context, device, .{});
    defer cl.releaseCommandQueue(queue) catch log.warn("failed to release queue", .{});
    const image = try cl.createImage(
        context,
        cl.MemFlags { .write_only = true, .host_read_only = true },
        PIXEL_FORMAT.opencl_format,
        cl.ImageDescriptor {
            .type = cl.MemObjectType.image2d,
            .width = TEXTURE_WIDTH,
            .height = TEXTURE_HEIGHT,
            .depth = 1,
            .image_array_size = 1,
            .row_pitch = 0,
            .slice_pitch = 0,
            .mem_object = null,
        },
        null
    );
    defer cl.releaseMemObject(image) catch log.warn("failed to release image", .{});
    const render_kernel = create_kernel: {
        const file = try std.fs.cwd().openFile(OPENCL_PROGRAM_SRC_PATH, .{});
        const file_len = try file.getEndPos() + 1;
        const src = try file.readToEndAlloc(allocator, file_len);
        defer allocator.free(src);
        file.close();

        const program = try cl.createProgramWithSource(context, src);
        defer cl.releaseProgram(program) catch log.warn("failed to release program", .{});
        try cl.buildProgram(program, &[_]cl.Device{device}, null);

        const kernel = try cl.createKernel(program, "render");
        break :create_kernel kernel;
    };
    defer cl.releaseKernel(render_kernel) catch log.warn("failed to release kernel", .{});

    // SDL initialization ------------------------------------------------------------------------------------

    enforce0(c.SDL_Init(c.SDL_INIT_VIDEO));
    defer c.SDL_Quit();

    const window = c.SDL_CreateWindow(
        "fuckin window",
        c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED,
        TEXTURE_WIDTH, TEXTURE_HEIGHT,
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
        TEXTURE_WIDTH, TEXTURE_HEIGHT
    ).?;
    defer c.SDL_DestroyTexture(sdl_texture);

    // -------------------------------------------------------------------------------------------------------

    // @todo Let OpenCL allocate this using CL_MEM_ALLOC_HOST_PTR, because "something something pinned memory
    // is fast".
    var pixel_hostbuffer: [N_PIXELS*PIXEL_FORMAT.bytes_per_pixel]u8 = undefined;

    // render first frame
    // @todo make index a global constant so that it's easier to change when the kernel signature changes
    try cl.setKernelArg(render_kernel, 0, @TypeOf(image), &image);
    try cl.enqueueNDRangeKernel(
        queue,
        render_kernel,
        2,
        null,
        &[_]usize {TEXTURE_WIDTH, TEXTURE_HEIGHT},
        &[_]usize {8, 8}, // @todo decide local work size
        null,
        null
    );
    try cl.enqueueReadImage(
        queue,
        image,
        true,
        &[_]usize {0, 0, 0},
        &[_]usize {TEXTURE_WIDTH, TEXTURE_HEIGHT, 1},
        TEXTURE_WIDTH * PIXEL_FORMAT.bytes_per_pixel,
        0,
        &pixel_hostbuffer,
        null,
        null
    );

    enforce0(
        c.SDL_UpdateTexture(sdl_texture, null, &pixel_hostbuffer, TEXTURE_WIDTH*PIXEL_FORMAT.bytes_per_pixel)
    );
    enforce0(c.SDL_RenderCopy(sdl_renderer, sdl_texture, null, null));
    c.SDL_RenderPresent(sdl_renderer);

    var event: c.SDL_Event = undefined;
    var exists_pending_event: bool = undefined;

    main_loop: while (true) {
        // process pending events
        exists_pending_event = c.SDL_PollEvent(&event) != 0;
        while (exists_pending_event) : (exists_pending_event = c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => break :main_loop,
                // @todo keypress P => pause
                else => {},
            }
        }
        // @todo render
    }

    std.debug.print("end of main\n", .{});
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
