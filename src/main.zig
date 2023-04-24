
//
// GLOBAL CONSTANTS ==========================================================================================
//

// @todo is there any reason to make these types `comptime_int`?
const TEXTURE_WIDTH : usize = 800;
const TEXTURE_HEIGHT: usize = 600;
const PIXEL_FORMAT = .{ // @note when modifying any value, make sure the others match
    .sdl_format = c.SDL_PIXELFORMAT_RGBA8888, // @todo consider RGB888, but suspect that it won't match OpenCL kernel memory alignment
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
    const context = try cl.createContext(&[_]cl.DeviceID{device});
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

    const render_kernel = create_kernel: {
        const file = try std.fs.cwd().openFile(OPENCL_PROGRAM_SRC_PATH, .{});
        const file_len = try file.getEndPos() + 1;
        const src = try file.readToEndAlloc(allocator, file_len);
        defer allocator.free(src);
        file.close();

        const program = try cl.createProgramWithSource(context, src);
        try cl.buildProgram(program, &[_]cl.DeviceID{device}, null);
        const kernel = try cl.createKernel(program, "render");
        break :create_kernel kernel;
        // @todo create kernel
    };
    _ = render_kernel;

    // @todo create queues

    // @todo next steps:
    //    create program
    //    create simple render kernel
    //    enqueue kernel to render to image
    //    copy rendered image to texture buffer on host
    _ = image;

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
    // @todo initialize pixel_buffer as `undefined` and render the initial condition to it using OpenCL
    const pixel_hostbuffer = [_]u8{0}**(N_PIXELS*PIXEL_FORMAT.bytes_per_pixel);
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
