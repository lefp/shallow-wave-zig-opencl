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

const PixelFormat = struct {
    opencl_format: c.cl_image_format,
    bytes_per_pixel: usize,
    sdl_format: c.SDL_PixelFormatEnum,
};

// derived constants
const N_PIXELS: usize = TEXTURE_WIDTH*TEXTURE_HEIGHT;

const std = @import("std");

const c = @cImport({
    // can enforce OpenCL version (at comptime, I think) here via e.g.:
    // @cDefine("CL_TARGET_OPENCL_VERSION", "120");
    @cInclude("CL/cl.h");
    @cInclude("SDL2/SDL.h");
});

pub fn main() void {
    _ = c.SDL_Init(c.SDL_INIT_VIDEO);

    const window = c.SDL_CreateWindow(
        "fuckin window",
        c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED,
        TEXTURE_WIDTH, TEXTURE_HEIGHT,
        0 // window is only resizeable if we set that flag
    );
    // @todo maybe use the "surface and direct pixel buffer access" method instead of using SDL's renderer;
    // it's probably more efficient that way, since we're already doing our own rendering. Although, maybe the
    // texture method will make it easier to support high-DPI screens (i.e., to not produce a tiny display).
    const renderer: *c.SDL_Renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_PRESENTVSYNC).?;
    const texture: *c.SDL_Texture = c.SDL_CreateTexture(
        renderer,
        PIXEL_FORMAT.sdl_format,
        c.SDL_TEXTUREACCESS_STREAMING, // for textures that change frequently; @todo TEXTUREACCESS_TARGET instead?
        TEXTURE_WIDTH, TEXTURE_HEIGHT
    ).?;

    // @todo Let OpenCL allocate this using CL_MEM_ALLOC_HOST_PTR, because "something something pinned memory
    // is fast".
    // @todo initialize pixel_buffer as `undefined` and render the initial condition to it using OpenCL
    const pixel_buffer = [_]u8{0}**(N_PIXELS*PIXEL_FORMAT.bytes_per_pixel);
    std.debug.assert(
        0 == c.SDL_UpdateTexture(texture, null, &pixel_buffer, TEXTURE_WIDTH*PIXEL_FORMAT.bytes_per_pixel)
        and
        0 == c.SDL_RenderCopy(renderer, texture, null, null)
    );
    c.SDL_RenderPresent(renderer);

    var event: c.SDL_Event = undefined;
    var existsPendingEvent: bool = undefined;

    main_loop: while (true) {
        // process pending events
        existsPendingEvent = c.SDL_PollEvent(&event) != 0;
        while (existsPendingEvent) {
            if (event.type == c.SDL_QUIT) break :main_loop;
            existsPendingEvent = c.SDL_PollEvent(&event) != 0;
        }
    }

    std.debug.print("end of main\n", .{});
}
