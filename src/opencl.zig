//! Uses OpenCL 3.0. You can't enforce a specific OpenCL version at compile-time; reference the OpenCL spec
//! for the list of features available in your target version.
//!
//! Compile-time version enforcement can be implemented, I just haven't needed it yet. Feel free to create
//! an issue or pull request if you want this feature.

const std = @import("std");
pub const c = @cImport({
	@cDefine("CL_TARGET_OPENCL_VERSION", "300");
	@cInclude("CL/opencl.h");
});

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

/// Indexing using the NEGATION of the OpenCL error code yields the equivalent OpenClError variant.
/// Do NOT use this to look up CL_SUCCESS; the result is undefined.
/// This implementation can break if the values of the error codes in "CL/cl.h" change; it relies on the
/// error codes being in the range [-72, 0].
// @note it would be more efficient to just use each error code directly in the OpenClError enum definition,
// but we can't do that; see https://github.com/ziglang/zig/issues/786#issuecomment-783888199
const NEGATIVE_OPENCL_ERROR_CONVERSION_LUT: [73]OpenClErr = lut_compute_block: {
	var lut: [73]OpenClErr = undefined;

	// @note CL_SUCCESS not included here, because it isn't included in OpenClError
	lut[-c.CL_DEVICE_NOT_FOUND] = OpenClErr.DeviceNotFound;
	lut[-c.CL_DEVICE_NOT_AVAILABLE] = OpenClErr.DeviceNotAvailable;
	lut[-c.CL_COMPILER_NOT_AVAILABLE] = OpenClErr.CompilerNotAvailable;
	lut[-c.CL_MEM_OBJECT_ALLOCATION_FAILURE] = OpenClErr.MemObjectAllocationFailure;
	lut[-c.CL_OUT_OF_RESOURCES] = OpenClErr.OutOfResources;
	lut[-c.CL_OUT_OF_HOST_MEMORY] = OpenClErr.OutOfHostMemory;
	lut[-c.CL_PROFILING_INFO_NOT_AVAILABLE] = OpenClErr.ProfilingInfoNotAvailable;
	lut[-c.CL_MEM_COPY_OVERLAP] = OpenClErr.MemCopyOverlap;
	lut[-c.CL_IMAGE_FORMAT_MISMATCH] = OpenClErr.ImageFormatMismatch;
	lut[-c.CL_IMAGE_FORMAT_NOT_SUPPORTED] = OpenClErr.ImageFormatNotSupported;
	lut[-c.CL_BUILD_PROGRAM_FAILURE] = OpenClErr.BuildProgramFailure;
	lut[-c.CL_MAP_FAILURE] = OpenClErr.MapFailure;
	lut[-c.CL_MISALIGNED_SUB_BUFFER_OFFSET] = OpenClErr.MisalignedSubBufferOffset;
	lut[-c.CL_EXEC_STATUS_ERROR_FOR_EVENTS_IN_WAIT_LIST] = OpenClErr.ExecStatusErrorForEventsInWaitList;
	lut[-c.CL_COMPILE_PROGRAM_FAILURE] = OpenClErr.CompileProgramFailure;
	lut[-c.CL_LINKER_NOT_AVAILABLE] = OpenClErr.LinkerNotAvailable;
	lut[-c.CL_LINK_PROGRAM_FAILURE] = OpenClErr.LinkProgramFailure;
	lut[-c.CL_DEVICE_PARTITION_FAILED] = OpenClErr.DevicePartitionFailed;
	lut[-c.CL_KERNEL_ARG_INFO_NOT_AVAILABLE] = OpenClErr.KernelArgInfoNotAvailable;
	lut[-c.CL_INVALID_VALUE] = OpenClErr.InvalidValue;
	lut[-c.CL_INVALID_DEVICE_TYPE] = OpenClErr.InvalidDeviceType;
	lut[-c.CL_INVALID_PLATFORM] = OpenClErr.InvalidPlatform;
	lut[-c.CL_INVALID_DEVICE] = OpenClErr.InvalidDevice;
	lut[-c.CL_INVALID_CONTEXT] = OpenClErr.InvalidContext;
	lut[-c.CL_INVALID_QUEUE_PROPERTIES] = OpenClErr.InvalidQueueProperties;
	lut[-c.CL_INVALID_COMMAND_QUEUE] = OpenClErr.InvalidCommandQueue;
	lut[-c.CL_INVALID_HOST_PTR] = OpenClErr.InvalidHostPtr;
	lut[-c.CL_INVALID_MEM_OBJECT] = OpenClErr.InvalidMemObject;
	lut[-c.CL_INVALID_IMAGE_FORMAT_DESCRIPTOR] = OpenClErr.InvalidImageFormatDescriptor;
	lut[-c.CL_INVALID_IMAGE_SIZE] = OpenClErr.InvalidImageSize;
	lut[-c.CL_INVALID_SAMPLER] = OpenClErr.InvalidSampler;
	lut[-c.CL_INVALID_BINARY] = OpenClErr.InvalidBinary;
	lut[-c.CL_INVALID_BUILD_OPTIONS] = OpenClErr.InvalidBuildOptions;
	lut[-c.CL_INVALID_PROGRAM] = OpenClErr.InvalidProgram;
	lut[-c.CL_INVALID_PROGRAM_EXECUTABLE] = OpenClErr.InvalidProgramExecutable;
	lut[-c.CL_INVALID_KERNEL_NAME] = OpenClErr.InvalidKernelName;
	lut[-c.CL_INVALID_KERNEL_DEFINITION] = OpenClErr.InvalidKernelDefinition;
	lut[-c.CL_INVALID_KERNEL] = OpenClErr.InvalidKernel;
	lut[-c.CL_INVALID_ARG_INDEX] = OpenClErr.InvalidArgIndex;
	lut[-c.CL_INVALID_ARG_VALUE] = OpenClErr.InvalidArgValue;
	lut[-c.CL_INVALID_ARG_SIZE] = OpenClErr.InvalidArgSize;
	lut[-c.CL_INVALID_KERNEL_ARGS] = OpenClErr.InvalidKernelArgs;
	lut[-c.CL_INVALID_WORK_DIMENSION] = OpenClErr.InvalidWorkDimension;
	lut[-c.CL_INVALID_WORK_GROUP_SIZE] = OpenClErr.InvalidWorkGroupSize;
	lut[-c.CL_INVALID_WORK_ITEM_SIZE] = OpenClErr.InvalidWorkItemSize;
	lut[-c.CL_INVALID_GLOBAL_OFFSET] = OpenClErr.InvalidGlobalOffset;
	lut[-c.CL_INVALID_EVENT_WAIT_LIST] = OpenClErr.InvalidEventWaitList;
	lut[-c.CL_INVALID_EVENT] = OpenClErr.InvalidEvent;
	lut[-c.CL_INVALID_OPERATION] = OpenClErr.InvalidOperation;
	lut[-c.CL_INVALID_GL_OBJECT] = OpenClErr.InvalidGlObject; // @fix
	lut[-c.CL_INVALID_BUFFER_SIZE] = OpenClErr.InvalidBufferSize;
	lut[-c.CL_INVALID_MIP_LEVEL] = OpenClErr.InvalidMipLevel; // @fix
	lut[-c.CL_INVALID_GLOBAL_WORK_SIZE] = OpenClErr.InvalidGlobalWorkSize;
	lut[-c.CL_INVALID_PROPERTY] = OpenClErr.InvalidProperty;
	lut[-c.CL_INVALID_IMAGE_DESCRIPTOR] = OpenClErr.InvalidImageDescriptor; // @fix
	lut[-c.CL_INVALID_COMPILER_OPTIONS] = OpenClErr.InvalidCompilerOptions;
	lut[-c.CL_INVALID_LINKER_OPTIONS] = OpenClErr.InvalidLinkerOptions;
	lut[-c.CL_INVALID_DEVICE_PARTITION_COUNT] = OpenClErr.InvalidDevicePartitionCount;
	lut[-c.CL_INVALID_PIPE_SIZE] = OpenClErr.InvalidPipeSize;
	lut[-c.CL_INVALID_DEVICE_QUEUE] = OpenClErr.InvalidDeviceQueue;
	lut[-c.CL_INVALID_SPEC_ID] = OpenClErr.InvalidSpecId;
	lut[-c.CL_MAX_SIZE_RESTRICTION_EXCEEDED] = OpenClErr.MaxSizeRestrictionExceeded;

	break :lut_compute_block lut;
};

/// Returns an error iff the code isn't CL_SUCCESS
fn checkClErrCode(code: i32) OpenClErr!void {
	std.debug.assert(code >= 0);
	if (code != c.CL_SUCCESS) return NEGATIVE_OPENCL_ERROR_CONVERSION_LUT[@intCast(usize, -code)];
}

pub fn getNumPlatforms() OpenClErr!u32 {
	var num: c.cl_uint = 0;
	try checkClErrCode(c.clGetPlatformIDs(0, null, &num));
	return num;
}

pub const PlatformID = c.cl_platform_id;
pub const PlatformID = opaque {};
/// `dst` must use C alignment (e.g. allocate via `std.heap.raw_c_allocator`). I think. Maybe. @todo figure this shit out
pub fn getPlatformIDs(dst: []PlatformID) OpenClErr!void {
	try checkClErrCode(c.clGetPlatformIDs(@intCast(u32, dst.len), dst.ptr, null));
}

