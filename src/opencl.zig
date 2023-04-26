const std = @import("std");
pub const c = @cImport({
    @cDefine("CL_TARGET_OPENCL_VERSION", "300");
    @cInclude("CL/opencl.h");
});

const Allocator = std.mem.Allocator;
const AllocErr = Allocator.Error;

//
// ERROR CODE CONVERSION =====================================================================================
//

/// Pulled from "Cl/cl.h".
pub const OpenClErr = error {
    // @note CL_SUCCESS not included here, because I don't consider it an "error"
    DeviceNotFound,
    DeviceNotAvailable,
    CompilerNotAvailable,
    MemObjectAllocationFailure,
    OutOfResources,
    OutOfHostMemory,
    ProfilingInfoNotAvailable,
    MemCopyOverlap,
    ImageFormatMismatch,
    ImageFormatNotSupported,
    BuildProgramFailure,
    MapFailure,
    MisalignedSubBufferOffset,
    ExecStatusErrorForEventsInWaitList,
    CompileProgramFailure,
    LinkerNotAvailable,
    LinkProgramFailure,
    DevicePartitionFailed,
    KernelArgInfoNotAvailable,
    InvalidValue,
    InvalidDeviceType,
    InvalidPlatform,
    InvalidDevice,
    InvalidContext,
    InvalidQueueProperties,
    InvalidCommandQueue,
    InvalidHostPtr,
    InvalidMemObject,
    InvalidImageFormatDescriptor,
    InvalidImageSize,
    InvalidSampler,
    InvalidBinary,
    InvalidBuildOptions,
    InvalidProgram,
    InvalidProgramExecutable,
    InvalidKernelName,
    InvalidKernelDefinition,
    InvalidKernel,
    InvalidArgIndex,
    InvalidArgValue,
    InvalidArgSize,
    InvalidKernelArgs,
    InvalidWorkDimension,
    InvalidWorkGroupSize,
    InvalidWorkItemSize,
    InvalidGlobalOffset,
    InvalidEventWaitList,
    InvalidEvent,
    InvalidOperation,
    InvalidGlObject,
    InvalidBufferSize,
    InvalidMipLevel,
    InvalidGlobalWorkSize,
    InvalidProperty,
    InvalidImageDescriptor,
    InvalidCompilerOptions,
    InvalidLinkerOptions,
    InvalidDevicePartitionCount,
    InvalidPipeSize,
    InvalidDeviceQueue,
    InvalidSpecId,
    MaxSizeRestrictionExceeded,
};

// @note it would be more efficient to just use each error code directly in the OpenClError error set
// definition, but we can't do that because the integers assigned to errors are global;
// see https:// github.com/ziglang/zig/issues/786#issuecomment-783888199
//
/// Indexing using the NEGATION of the OpenCL error code yields the equivalent OpenClError variant.
/// Do NOT use this to look up CL_SUCCESS; the result is undefined.
/// This implementation can break if the values of the error codes in "CL/cl.h" change; it relies on the
/// error codes being in the range [-72, 0].
const NEGATIVE_OPENCL_ERROR_CONVERSION_LUT: [73]OpenClErr = lut_compute_block: {
    var lut: [73]OpenClErr = undefined;

    // @note CL_SUCCESS not included here, because it isn't included in OpenClError
    lut[@as(usize, -c.CL_DEVICE_NOT_FOUND)] = OpenClErr.DeviceNotFound;
    lut[@as(usize, -c.CL_DEVICE_NOT_AVAILABLE)] = OpenClErr.DeviceNotAvailable;
    lut[@as(usize, -c.CL_COMPILER_NOT_AVAILABLE)] = OpenClErr.CompilerNotAvailable;
    lut[@as(usize, -c.CL_MEM_OBJECT_ALLOCATION_FAILURE)] = OpenClErr.MemObjectAllocationFailure;
    lut[@as(usize, -c.CL_OUT_OF_RESOURCES)] = OpenClErr.OutOfResources;
    lut[@as(usize, -c.CL_OUT_OF_HOST_MEMORY)] = OpenClErr.OutOfHostMemory;
    lut[@as(usize, -c.CL_PROFILING_INFO_NOT_AVAILABLE)] = OpenClErr.ProfilingInfoNotAvailable;
    lut[@as(usize, -c.CL_MEM_COPY_OVERLAP)] = OpenClErr.MemCopyOverlap;
    lut[@as(usize, -c.CL_IMAGE_FORMAT_MISMATCH)] = OpenClErr.ImageFormatMismatch;
    lut[@as(usize, -c.CL_IMAGE_FORMAT_NOT_SUPPORTED)] = OpenClErr.ImageFormatNotSupported;
    lut[@as(usize, -c.CL_BUILD_PROGRAM_FAILURE)] = OpenClErr.BuildProgramFailure;
    lut[@as(usize, -c.CL_MAP_FAILURE)] = OpenClErr.MapFailure;
    lut[@as(usize, -c.CL_MISALIGNED_SUB_BUFFER_OFFSET)] = OpenClErr.MisalignedSubBufferOffset;
    lut[@as(usize, -c.CL_EXEC_STATUS_ERROR_FOR_EVENTS_IN_WAIT_LIST)] = OpenClErr.ExecStatusErrorForEventsInWaitList;
    lut[@as(usize, -c.CL_COMPILE_PROGRAM_FAILURE)] = OpenClErr.CompileProgramFailure;
    lut[@as(usize, -c.CL_LINKER_NOT_AVAILABLE)] = OpenClErr.LinkerNotAvailable;
    lut[@as(usize, -c.CL_LINK_PROGRAM_FAILURE)] = OpenClErr.LinkProgramFailure;
    lut[@as(usize, -c.CL_DEVICE_PARTITION_FAILED)] = OpenClErr.DevicePartitionFailed;
    lut[@as(usize, -c.CL_KERNEL_ARG_INFO_NOT_AVAILABLE)] = OpenClErr.KernelArgInfoNotAvailable;
    lut[@as(usize, -c.CL_INVALID_VALUE)] = OpenClErr.InvalidValue;
    lut[@as(usize, -c.CL_INVALID_DEVICE_TYPE)] = OpenClErr.InvalidDeviceType;
    lut[@as(usize, -c.CL_INVALID_PLATFORM)] = OpenClErr.InvalidPlatform;
    lut[@as(usize, -c.CL_INVALID_DEVICE)] = OpenClErr.InvalidDevice;
    lut[@as(usize, -c.CL_INVALID_CONTEXT)] = OpenClErr.InvalidContext;
    lut[@as(usize, -c.CL_INVALID_QUEUE_PROPERTIES)] = OpenClErr.InvalidQueueProperties;
    lut[@as(usize, -c.CL_INVALID_COMMAND_QUEUE)] = OpenClErr.InvalidCommandQueue;
    lut[@as(usize, -c.CL_INVALID_HOST_PTR)] = OpenClErr.InvalidHostPtr;
    lut[@as(usize, -c.CL_INVALID_MEM_OBJECT)] = OpenClErr.InvalidMemObject;
    lut[@as(usize, -c.CL_INVALID_IMAGE_FORMAT_DESCRIPTOR)] = OpenClErr.InvalidImageFormatDescriptor;
    lut[@as(usize, -c.CL_INVALID_IMAGE_SIZE)] = OpenClErr.InvalidImageSize;
    lut[@as(usize, -c.CL_INVALID_SAMPLER)] = OpenClErr.InvalidSampler;
    lut[@as(usize, -c.CL_INVALID_BINARY)] = OpenClErr.InvalidBinary;
    lut[@as(usize, -c.CL_INVALID_BUILD_OPTIONS)] = OpenClErr.InvalidBuildOptions;
    lut[@as(usize, -c.CL_INVALID_PROGRAM)] = OpenClErr.InvalidProgram;
    lut[@as(usize, -c.CL_INVALID_PROGRAM_EXECUTABLE)] = OpenClErr.InvalidProgramExecutable;
    lut[@as(usize, -c.CL_INVALID_KERNEL_NAME)] = OpenClErr.InvalidKernelName;
    lut[@as(usize, -c.CL_INVALID_KERNEL_DEFINITION)] = OpenClErr.InvalidKernelDefinition;
    lut[@as(usize, -c.CL_INVALID_KERNEL)] = OpenClErr.InvalidKernel;
    lut[@as(usize, -c.CL_INVALID_ARG_INDEX)] = OpenClErr.InvalidArgIndex;
    lut[@as(usize, -c.CL_INVALID_ARG_VALUE)] = OpenClErr.InvalidArgValue;
    lut[@as(usize, -c.CL_INVALID_ARG_SIZE)] = OpenClErr.InvalidArgSize;
    lut[@as(usize, -c.CL_INVALID_KERNEL_ARGS)] = OpenClErr.InvalidKernelArgs;
    lut[@as(usize, -c.CL_INVALID_WORK_DIMENSION)] = OpenClErr.InvalidWorkDimension;
    lut[@as(usize, -c.CL_INVALID_WORK_GROUP_SIZE)] = OpenClErr.InvalidWorkGroupSize;
    lut[@as(usize, -c.CL_INVALID_WORK_ITEM_SIZE)] = OpenClErr.InvalidWorkItemSize;
    lut[@as(usize, -c.CL_INVALID_GLOBAL_OFFSET)] = OpenClErr.InvalidGlobalOffset;
    lut[@as(usize, -c.CL_INVALID_EVENT_WAIT_LIST)] = OpenClErr.InvalidEventWaitList;
    lut[@as(usize, -c.CL_INVALID_EVENT)] = OpenClErr.InvalidEvent;
    lut[@as(usize, -c.CL_INVALID_OPERATION)] = OpenClErr.InvalidOperation;
    lut[@as(usize, -c.CL_INVALID_GL_OBJECT)] = OpenClErr.InvalidGlObject;
    lut[@as(usize, -c.CL_INVALID_BUFFER_SIZE)] = OpenClErr.InvalidBufferSize;
    lut[@as(usize, -c.CL_INVALID_MIP_LEVEL)] = OpenClErr.InvalidMipLevel;
    lut[@as(usize, -c.CL_INVALID_GLOBAL_WORK_SIZE)] = OpenClErr.InvalidGlobalWorkSize;
    lut[@as(usize, -c.CL_INVALID_PROPERTY)] = OpenClErr.InvalidProperty;
    lut[@as(usize, -c.CL_INVALID_IMAGE_DESCRIPTOR)] = OpenClErr.InvalidImageDescriptor;
    lut[@as(usize, -c.CL_INVALID_COMPILER_OPTIONS)] = OpenClErr.InvalidCompilerOptions;
    lut[@as(usize, -c.CL_INVALID_LINKER_OPTIONS)] = OpenClErr.InvalidLinkerOptions;
    lut[@as(usize, -c.CL_INVALID_DEVICE_PARTITION_COUNT)] = OpenClErr.InvalidDevicePartitionCount;
    lut[@as(usize, -c.CL_INVALID_PIPE_SIZE)] = OpenClErr.InvalidPipeSize;
    lut[@as(usize, -c.CL_INVALID_DEVICE_QUEUE)] = OpenClErr.InvalidDeviceQueue;
    lut[@as(usize, -c.CL_INVALID_SPEC_ID)] = OpenClErr.InvalidSpecId;
    lut[@as(usize, -c.CL_MAX_SIZE_RESTRICTION_EXCEEDED)] = OpenClErr.MaxSizeRestrictionExceeded;

    break :lut_compute_block lut;
};

/// Returns an error iff the code isn't CL_SUCCESS
fn checkClErrCode(code: i32) OpenClErr!void {
    std.debug.assert(-code >= 0);
    if (code != c.CL_SUCCESS) return NEGATIVE_OPENCL_ERROR_CONVERSION_LUT[@intCast(usize, -code)];
}

//
// TYPES =====================================================================================================
//

pub const UInt2 = extern union {
    arr: [2]u32 align(8),
    vec: packed struct { x: u32, y: u32 },

    comptime { std.debug.assert(@sizeOf(@This()) == 8); }
};
pub const UInt4 = extern union {
    arr: [4]u32 align(16),
    vec: extern struct { x: u32, y: u32, z: u32, w: u32, },
    float2: extern struct { lo: UInt2, hi: UInt2 },

    comptime { std.debug.assert(@sizeOf(@This()) == 16); }
};

pub const Int2 = extern union {
    arr: [2]i32 align(8),
    vec: packed struct { x: i32, y: i32 },

    comptime { std.debug.assert(@sizeOf(@This()) == 8); }
};
pub const Int4 = extern union {
    arr: [4]i32 align(16),
    vec: extern struct { x: i32, y: i32, z: i32, w: i32, },
    float2: extern struct { lo: Int2, hi: Int2 },

    comptime { std.debug.assert(@sizeOf(@This()) == 16); }
};

pub const Float2 = extern union {
    arr: [2]f32 align(8),
    vec: packed struct { x: f32, y: f32 },

    comptime { std.debug.assert(@sizeOf(@This()) == 8); }
};
pub const Float4 = extern union {
    arr: [4]f32 align(16),
    vec: extern struct { x: f32, y: f32, z: f32, w: f32, },
    float2: extern struct { lo: Float2, hi: Float2 },
    // simd: @Vector(4, f32), // @todo ?? understand before including this

    comptime { std.debug.assert(@sizeOf(@This()) == 16); }
};

pub const Platform = c.cl_platform_id;
pub const Device = c.cl_device_id;
pub const Version = c.cl_version;
pub const Context = c.cl_context;
pub const Mem = c.cl_mem; // buffer, image, etc
pub const Program = c.cl_program;
pub const Kernel = c.cl_kernel;
pub const CommandQueue = c.cl_command_queue;
pub const Event = c.cl_event;

pub const DeviceType = u64;

// @todo you've put this under the "TYPES" section; should it be somewhere else?
// pulled from "CL/cl.h". I'd like to just use a packed struct of bools for this,
// but the 0xFFFFFFFF makes that hard
pub const DEVICE_TYPE_DEFAULT    : DeviceType = (1 << 0);
pub const DEVICE_TYPE_CPU        : DeviceType = (1 << 1);
pub const DEVICE_TYPE_GPU        : DeviceType = (1 << 2);
pub const DEVICE_TYPE_ACCELERATOR: DeviceType = (1 << 3);
pub const DEVICE_TYPE_CUSTOM     : DeviceType = (1 << 4);
pub const DEVICE_TYPE_ALL        : DeviceType = 0xFFFFFFFF;

// @todo maybe this should be split into multiple enums
// Order determined from "CL/cl.h".
pub const MemFlags = packed struct(u64) {
    read_write           : bool = false,
    write_only           : bool = false,
    read_only            : bool = false,
    use_host_ptr         : bool = false,
    alloc_host_ptr       : bool = false,
    copy_host_ptr        : bool = false,
    _reserved            : bool = false,
    host_write_only      : bool = false,
    host_read_only       : bool = false,
    host_no_access       : bool = false,
    svm_fine_grain_buffer: bool = false,
    svm_atomics          : bool = false,
    kernel_read_and_write: bool = false,
    _padding: u51 = 0,
};


pub const ImageFormat = extern struct {
    channel_order: ChannelOrder,
    channel_data_type: ChannelDataType,

    /// Values pulled from "CL/cl.h".
    pub const ChannelOrder = enum(u32) {
        R             = 0x10B0,
        A             = 0x10B1,
        RG            = 0x10B2,
        RA            = 0x10B3,
        RGB           = 0x10B4,
        RGBA          = 0x10B5,
        BGRA          = 0x10B6,
        ARGB          = 0x10B7,
        intensity     = 0x10B8,
        luminance     = 0x10B9,
        Rx            = 0x10BA,
        RGx           = 0x10BB,
        RGBx          = 0x10BC,
        depth         = 0x10BD,
        depth_stencil = 0x10BE,
        sRGB          = 0x10BF,
        sRGBx         = 0x10C0,
        sRGBA         = 0x10C1,
        sBGRA         = 0x10C2,
        ABGR          = 0x10C3,
    };
    /// Values pulled from "CL/cl.h".
    pub const ChannelDataType = enum(u32) {
        snorm_int8        = 0x10D0,
        snorm_int16       = 0x10D1,
        unorm_int8        = 0x10D2,
        unorm_int16       = 0x10D3,
        unorm_short565    = 0x10D4,
        unorm_short555    = 0x10D5,
        unorm_int101010   = 0x10D6,
        signed_int8       = 0x10D7,
        signed_int16      = 0x10D8,
        signed_int32      = 0x10D9,
        unsigned_int8     = 0x10DA,
        unsigned_int16    = 0x10DB,
        unsigned_int32    = 0x10DC,
        half_float        = 0x10DD,
        float             = 0x10DE,
        unorm_int24       = 0x10DF,
        unorm_int101010_2 = 0x10E0,
    };
};

/// Values pulled from "CL/cl.h".
pub const MemObjectType = enum(u32) {
    buffer         = 0x10F0,
    image2d        = 0x10F1,
    image3d        = 0x10F2,
    image2d_array  = 0x10F3,
    image1d        = 0x10F4,
    image1d_array  = 0x10F5,
    image1d_buffer = 0x10F6,
    pipe           = 0x10F7,
};

pub const ImageDescriptor = extern struct {
    type: MemObjectType,
    width : usize,
    height: usize,
    depth : usize,
    image_array_size: usize,
    row_pitch  : usize,
    slice_pitch: usize,
    _num_mip_levels: u32 = 0, // OpenCL spec requires this to be 0
    _num_samples   : u32 = 0, // OpenCL spec requires this to be 0
    mem_object: Mem, // a buffer or image. In the OpenCL spec this is a union, but I see no reason to do that
};

// Order determined from "CL/cl.h".
pub const CommandQueueProperties = packed struct(u64) {
    OutOfOrderExecMode: bool = false,
    Profiling         : bool = false,
    OnDevice          : bool = false,
    OnDeviceDefault   : bool = false,
    _padding: u60 = 0,
};

//
// FUNCTIONS =================================================================================================
//

// platforms -------------------------------------------------------------------------------------------------

// @todo should you really be inlining all these functions?
pub inline fn getNumPlatforms() OpenClErr!u32 {
    var num: u32 = undefined;
    try checkClErrCode(c.clGetPlatformIDs(0, null, &num));
    return num;
}
/// The number of platform IDs to get should be encoded in the fat pointer `dst`.
// @todo does `dst` need to be allocated with C alignment? Maybe that's guaranteed by the fact that PlatformID
// is declared as opaque?
pub inline fn getPlatformIDs(dst: []Platform) OpenClErr!void {
    try checkClErrCode(c.clGetPlatformIDs(@intCast(u32, dst.len), dst.ptr, null));
}

/// @note The caller is responsible for freeing the returned slice.
pub fn getAllPlatformIDs(allocator: Allocator) (AllocErr||OpenClErr)![]Platform {
    const num_platforms = try getNumPlatforms();
    var platform_ids = try allocator.alloc(Platform, num_platforms);
    try getPlatformIDs(platform_ids);
    return platform_ids;
}

/// Pulled from "CL/cl.h".
// const PlatformInfo = enum(u32) {
//     Profile = c.CL_PLATFORM_PROFILE,
//     Version = c.CL_PLATFORM_VERSION,
//     Name = c.CL_PLATFORM_NAME,
//     Vendor = c.CL_PLATFORM_VENDOR,
//     Extensions = c.CL_PLATFORM_EXTENSIONS,
//     HostTimerResolution = c.CL_PLATFORM_HOST_TIMER_RESOLUTION,
//     NumericVersion = c.CL_PLATFORM_NUMERIC_VERSION,
//     ExtensionsWithVersion = c.CL_PLATFORM_EXTENSIONS_WITH_VERSION,
// };
// fn platformInfoReturnType(info_type: PlatformInfo) type {
//     switch (info_type) {
//         .Profile, .Version, .Name, .Vendor, .Extensions => [*:0]u8,
//         .NumericVersion => ClVersion, // @todo C string? Null-terminated byte array?
//         .HostTimerResultion => u64,
//     }
// }

// @todo we can totally require the type of platform info requested to be a compile-time parameter, which
// would make allocation and the return type comptime-known
// pub fn getPlatformInfo(
//     comptime info: PlatformInfo, platform: PlatformID, allocator: Allocator
// ) (AllocErr||OpenClErr)!platformInfoReturnType(info) {
//     var ret_size: usize = undefined;
//     try checkClErrCode(
//         c.clGetPlatformInfo(platform, info, null, null, &ret_size)
//     );
//     var ret = try allocator.alloc(u8, ret_size);
//     try checkClErrCode(
//         c.clGetPlatformInfo(platform, info, ret_size, &ret.ptr, null)
//     );
// }

/// Returns a null-terminated string, in the form of a fat pointer so that you can call `free` on it.
pub fn getPlatformName(platform: Platform, allocator: Allocator) (AllocErr||OpenClErr)![]u8{
    var str_size: usize = undefined;
    // @todo not sure that the spec allows us to use 0 for the size
    try checkClErrCode(c.clGetPlatformInfo(platform, c.CL_PLATFORM_NAME, 0, null, &str_size));
    var str = try allocator.alloc(u8, str_size);
    try checkClErrCode(c.clGetPlatformInfo(platform, c.CL_PLATFORM_NAME, str.len, str.ptr, null));
    return str;
}
// @todo functions for querying other platform info?

// devices ---------------------------------------------------------------------------------------------------

/// device_type is a bitfield; use e.g. `DEVICE_TYPE_GPU` for the type you want.
pub inline fn getNumDevices(platform: Platform, device_type: DeviceType) OpenClErr!u32 {
    var num: u32 = undefined;
    try checkClErrCode(c.clGetDeviceIDs(platform, device_type, 0, null, &num));
    return num;
}
/// The number of IDs to get should be encoded in the fat pointer `dst`.
pub inline fn getDeviceIDs(
    platform: Platform, device_type: DeviceType, dst: []const Device
) OpenClErr!void {
    try checkClErrCode(
        c.clGetDeviceIDs(platform, device_type, @intCast(u32, dst.len), @constCast(dst.ptr), null)
    );
}

/// @note The caller is responsible for freeing the returned slice.
pub fn getAllDeviceIDs(
    platform: Platform, device_type: DeviceType, allocator: Allocator
) (AllocErr||OpenClErr)![]Device {
    const num_devices = try getNumDevices(platform, device_type);
    var device_ids = try allocator.alloc(Device, num_devices);
    try getDeviceIDs(platform, device_type, device_ids);
    return device_ids;
}

pub fn getDeviceName(device: Device, allocator: Allocator) (AllocErr||OpenClErr)![]u8 {
    var str_size: usize = undefined;
    // @todo not sure that the spec allows us to use 0 for the size
    try checkClErrCode(c.clGetDeviceInfo(device, c.CL_DEVICE_NAME, 0, null, &str_size));
    var str = try allocator.alloc(u8, str_size);
    try checkClErrCode(c.clGetDeviceInfo(device, c.CL_DEVICE_NAME, str.len, str.ptr, null));
    return str;
}
// @todo functions for querying other device info?

// context ---------------------------------------------------------------------------------------------------

pub fn createContext(devices: []const Device) OpenClErr!Context {
    var errcode: i32 = undefined;
    const context = c.clCreateContext(
        null, @intCast(u32, devices.len), @constCast(devices.ptr), null, null, &errcode
    );
    try checkClErrCode(errcode);
    return context;
}
pub inline fn releaseContext(context: Context) OpenClErr!void {
    try checkClErrCode( c.clReleaseContext(context) );
}
pub inline fn retainContext(context: Context) OpenClErr!void {
    try checkClErrCode( c.clRetainContext(context) );
}

// memory objects --------------------------------------------------------------------------------------------

pub inline fn releaseMemObject(object: Mem) OpenClErr!void {
    try checkClErrCode( c.clReleaseMemObject(object) );
}
pub inline fn retainMemObject(object: Mem) OpenClErr!void {
    try checkClErrCode( c.clRetainMemObject(object) );
}

pub fn createBuffer(context: Context, flags: MemFlags, size: usize, host_ptr: ?*anyopaque) OpenClErr!Mem {
    var errcode: i32 = undefined;
    const buffer = c.clCreateBuffer(context, @bitCast(u64, flags), size, host_ptr, &errcode);
    try checkClErrCode(errcode);
    return buffer;
}

pub fn createImage( // @todo should I make this a method of Context? Would "feel" more convenient
    context: Context,
    flags: MemFlags,
    format: ImageFormat,
    descriptor: ImageDescriptor,
    host_ptr: ?*anyopaque
) OpenClErr!Mem { // @todo any reason to create an Image type and make this return that instead?
    var errcode: i32 = undefined;
    const image = c.clCreateImage(
        context,
        @bitCast(u64, flags),
        @ptrCast(*c.cl_image_format, @constCast(&format)),
        @ptrCast(*c.cl_image_desc, @constCast(&descriptor)),
        host_ptr,
        &errcode
    );
    try checkClErrCode(errcode);
    return image;
}

// program ---------------------------------------------------------------------------------------------------

/// Note: creating the program is not enough; you must also build it using `buildProgram()`.
pub fn createProgramWithSource(context: Context, src: []const u8) OpenClErr!Program {
    var errcode: i32 = undefined;
    const program = c.clCreateProgramWithSource(
        context,
        1,
        @constCast(&@ptrCast([*c]const u8, src.ptr)), // @todo is this cast breaking something?
        &src.len,
        &errcode
    );
    try checkClErrCode(errcode);
    return program;
}
pub inline fn releaseProgram(program: Program) OpenClErr!void {
    try checkClErrCode( c.clReleaseProgram(program) );
}
pub inline fn retainProgram(program: Program) OpenClErr!void {
    try checkClErrCode( c.clRetainProgram(program) );
}

// @todo implement a safe/convenient way to pass '-D' definitions
pub inline fn buildProgram(
    program: Program, devices: []const Device, options: ?[*:0]const u8
) OpenClErr!void {
    try checkClErrCode(
        c.clBuildProgram(program, @intCast(u32, devices.len), devices.ptr, options, null, null)
    );
}

// kernel ----------------------------------------------------------------------------------------------------

pub fn createKernel(program: Program, name: [*:0]const u8) OpenClErr!Kernel {
    var errcode: i32 = undefined;
    const kernel = c.clCreateKernel(program, @constCast(name), &errcode);
    try checkClErrCode(errcode);
    return kernel;
}
pub inline fn releaseKernel(kernel: Kernel) OpenClErr!void {
    try checkClErrCode( c.clReleaseKernel(kernel) );
}
pub inline fn retainKernel(kernel: Kernel) OpenClErr!void {
    try checkClErrCode( c.clRetainKernel(kernel) );
}

// @todo maybe come up with a way to set kernel arguments that reduces the probability of passing the wrong index
pub fn setKernelArg(
    kernel: Kernel, arg_index: u32, comptime ArgType: type, arg: *const ArgType
) OpenClErr!void {
    try checkClErrCode(
        c.clSetKernelArg(kernel, arg_index, @sizeOf(ArgType), @ptrCast(*const anyopaque, arg))
    );
}

// queue -----------------------------------------------------------------------------------------------------

pub fn createCommandQueue(
    context: Context, device: Device, properties: CommandQueueProperties
) OpenClErr!CommandQueue {
    var errcode: i32 = undefined;
    const queue = c.clCreateCommandQueue(context, device, @bitCast(u64, properties), &errcode);
    try checkClErrCode(errcode);
    return queue;
}
pub inline fn releaseCommandQueue(queue: CommandQueue) OpenClErr!void {
    try checkClErrCode( c.clReleaseCommandQueue(queue) );
}
pub inline fn retainCommandQueue(queue: CommandQueue) OpenClErr!void {
    try checkClErrCode( c.clRetainCommandQueue(queue) );
}

pub inline fn flush(queue: CommandQueue) OpenClErr!void {
    try checkClErrCode( c.clFlush(queue) );
}
pub inline fn finish(queue: CommandQueue) OpenClErr!void {
    try checkClErrCode( c.clFinish(queue) );
}

/// @note The spec doesn't say that the `local_work_size` parameter is optional, but I've seen passing `NULL`
/// produce significantly better performance. Do so at your own risk.
pub fn enqueueNDRangeKernel(
    queue: CommandQueue,
    kernel: Kernel,
    n_dims: u32,
    global_work_offset: ?[*]const usize,
    global_work_size: [*]const usize, // the spec says this parameter is optional, but I don't like that
    local_work_size: ?[*]const usize,
    waitlist: ?[]const Event,
    event: ?*Event
) OpenClErr!void {
    try checkClErrCode(
        c.clEnqueueNDRangeKernel(
            queue, kernel, n_dims, global_work_offset, global_work_size, local_work_size,
            if (waitlist) |wl| @intCast(u32, wl.len) else 0,
            if (waitlist) |wl| wl.ptr else null,
            event
        )
    );
}

// @todo consider abstracting away the whole "origin, region, row_pitch, slice_pitch" stuff by providing a
// special `FatImage` struct that contains that information, and an associated `read` function. Maybe put this
// in a separate file for higher-level / more-abstracted functions
pub fn enqueueReadImage(
    queue: CommandQueue,
    image: Mem,
    blocking: bool,
    origin: [*]const usize,
    region: [*]const usize,
    row_pitch  : usize,
    slice_pitch: usize,
    dst: [*]u8,
    waitlist: ?[]const Event,
    event: ?*Event
) OpenClErr!void {
    // std.debug.assert(origin.len == region.len);
    try checkClErrCode(
        c.clEnqueueReadImage(
            queue, image, @boolToInt(blocking), origin, region, row_pitch, slice_pitch, dst,
            if (waitlist) |wl| @intCast(u32, wl.len) else 0,
            if (waitlist) |wl| wl.ptr else null,
            event
        )
    );
}

// events ----------------------------------------------------------------------------------------------------

pub fn releaseEvent(event: Event) OpenClErr!void {
    try checkClErrCode( c.clReleaseEvent(event) );
}
pub fn retainEvent(event: Event) OpenClErr!void {
    try checkClErrCode( c.clRetainEvent(event) );
}

pub fn waitForEvents(events: []const Event) OpenClErr!void {
    try checkClErrCode( c.clWaitForEvents(@intCast(u32, events.len), events.ptr) );
}
