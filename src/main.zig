
//
// GLOBAL CONSTANTS ==========================================================================================
//

// @todo is there any reason to make these types `comptime_int`?
const TEXTURE_WIDTH : usize = 800;
const TEXTURE_HEIGHT: usize = 600;
const PIXEL_FORMAT = PixelFormat { // @note when modifying any value, make sure the others match
    .sdl_format = c.SDL_PIXELFORMAT_RGBA8888, // @todo consider RGB888, but suspect that it won't match OpenCL kernel memory alignment
    .opencl_format = c.cl_image_format {
        .image_channel_order = c.CL_RGBA,
        .image_channel_data_type = c.CL_UNORM_INT8,
    },
    .bytes_per_pixel = 4,
};

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

//
// MAIN ======================================================================================================
//

pub fn main() void {

    // OpenCL initialization ---------------------------------------------------------------------------------

    // get platforms
    const num_platforms: u32 = cl.getNumPlatforms() catch @panic("failed to get number of platforms");
    if (num_platforms == 0) @panic("No OpenCL platforms found");
    std.log.info("Found {} OpenCL platforms.\n", .{num_platforms});
    // var platform_ids = std.ArrayList(c.cl_uint).initCapacity(std.heap.c_allocator, num_platforms);
    var platform_ids = std.heap.raw_c_allocator.alloc(cl.PlatformID, num_platforms) catch @panic("failed to allocate");
    defer platform_ids.free();
    cl.getPlatformIDs(platform_ids) catch @panic("failed to get platform ids");
    std.process.exit(0); // @continue

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

const PixelFormat = struct {
    opencl_format: c.cl_image_format,
    bytes_per_pixel: usize,
    sdl_format: c.SDL_PixelFormatEnum,
};

inline fn enforce0(val: c_int) void {
    if (val != 0) @panic("Value was not 0");
}
