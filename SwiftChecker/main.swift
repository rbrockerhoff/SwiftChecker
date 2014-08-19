//
//  main.swift
//  SwiftChecker
//
//  Created by Rainer Brockerhoff on 5/6/14.
//  Copyright (c) 2014 Rainer Brockerhoff. All rights reserved.
//

import Cocoa
import OpenCL

//	This TimeStamp is used in AppDelegate to log startup and quit times.
let startup = TimeStamp()
PrintLN("Started at \(startup)")

NSApplicationMain(C_ARGC, C_ARGV)

/*
let numberOfDataElements = 400_000

var err:cl_int = 0
var errCounter = 0

var program:cl_program = nil
var device:cl_device_id = nil

func e() {
	errCounter++
	switch (err) {
	case 0: return
	case -1: println( "CL_DEVICE_NOT_FOUND" )
	case -2: println( "CL_DEVICE_NOT_AVAILABLE" )
	case -3: println( "CL_COMPILER_NOT_AVAILABLE" )
	case -4: println( "CL_MEM_OBJECT_ALLOCATION_FAILURE" )
	case -5: println( "CL_OUT_OF_RESOURCES" )
	case -6: println( "CL_OUT_OF_HOST_MEMORY" )
	case -7: println( "CL_PROFILING_INFO_NOT_AVAILABLE" )
	case -8: println( "CL_MEM_COPY_OVERLAP" )
	case -9: println( "CL_IMAGE_FORMAT_MISMATCH" )
	case -10: println( "CL_IMAGE_FORMAT_NOT_SUPPORTED" )
	case -11: println( "CL_BUILD_PROGRAM_FAILURE" )
	case -12: println( "CL_MAP_FAILURE" )
	case -30: println( "CL_INVALID_VALUE" )
	case -31: println( "CL_INVALID_DEVICE_TYPE" )
	case -32: println( "CL_INVALID_PLATFORM" )
	case -33: println( "CL_INVALID_DEVICE" )
	case -34: println( "CL_INVALID_CONTEXT" )
	case -35: println( "CL_INVALID_QUEUE_PROPERTIES" )
	case -36: println( "CL_INVALID_COMMAND_QUEUE" )
	case -37: println( "CL_INVALID_HOST_PTR" )
	case -38: println( "CL_INVALID_MEM_OBJECT" )
	case -39: println( "CL_INVALID_IMAGE_FORMAT_DESCRIPTOR" )
	case -40: println( "CL_INVALID_IMAGE_SIZE" )
	case -41: println( "CL_INVALID_SAMPLER" )
	case -42: println( "CL_INVALID_BINARY" )
	case -43: println( "CL_INVALID_BUILD_OPTIONS" )
	case -44: println( "CL_INVALID_PROGRAM" )
	case -45: println( "CL_INVALID_PROGRAM_EXECUTABLE" )
	case -46: println( "CL_INVALID_KERNEL_NAME" )
	case -47: println( "CL_INVALID_KERNEL_DEFINITION" )
	case -48: println( "CL_INVALID_KERNEL" )
	case -49: println( "CL_INVALID_ARG_INDEX" )
	case -50: println( "CL_INVALID_ARG_VALUE" )
	case -51: println( "CL_INVALID_ARG_SIZE" )
	case -52: println( "CL_INVALID_KERNEL_ARGS" )
	case -53: println( "CL_INVALID_WORK_DIMENSION" )
	case -54: println( "CL_INVALID_WORK_GROUP_SIZE" )
	case -55: println( "CL_INVALID_WORK_ITEM_SIZE" )
	case -56: println( "CL_INVALID_GLOBAL_OFFSET" )
	case -57: println( "CL_INVALID_EVENT_WAIT_LIST" )
	case -58: println( "CL_INVALID_EVENT" )
	case -59: println( "CL_INVALID_OPERATION" )
	case -60: println( "CL_INVALID_GL_OBJECT" )
	case -61: println( "CL_INVALID_BUFFER_SIZE" )
	case -62: println( "CL_INVALID_MIP_LEVEL" )
	case -63: println( "CL_INVALID_GLOBAL_WORK_SIZE" )
	default: println( "Unknown OpenCL error" )
	}
	println("errCounter: \(errCounter)")
	
	var len:size_t = 0
	clGetProgramBuildInfo(program, device, cl_program_build_info(CL_PROGRAM_BUILD_LOG), 0, nil, &len);
	var buffer = [CChar](count:Int(len), repeatedValue:CChar(0))
	clGetProgramBuildInfo(program, device, cl_program_build_info(CL_PROGRAM_BUILD_LOG), len, &buffer, nil);
	println( String.stringWithBytes(buffer, encoding: NSUTF8StringEncoding)! )
	
	abort()
}

func USize<T>(_: T.Type) -> UInt {
	return UInt(sizeof(T))
}

var numberOfPlatforms:cl_uint = 0
clGetPlatformIDs(1, nil, &numberOfPlatforms)

var platform:cl_platform_id = nil
clGetPlatformIDs(1, &platform, nil)

var numberOfDevices:cl_uint = 0
clGetDeviceIDs(platform, cl_device_type(CL_DEVICE_TYPE_ALL), 1, nil, &numberOfDevices)

var devices = [cl_device_id](count:Int(numberOfDevices), repeatedValue:cl_device_id())
err = clGetDeviceIDs(platform, cl_device_type(CL_DEVICE_TYPE_ALL), numberOfDevices, &devices, nil); e()
println("\(numberOfDevices) devices\n")

for dvc in devices {
	device = dvc
	var param = [CChar](count:100, repeatedValue:CChar(0))
	err = clGetDeviceInfo(device, cl_device_info(CL_DEVICE_NAME), 100, &param, nil); e()
	let name = String.stringWithBytes(param, encoding: NSUTF8StringEncoding)!
	println("Run on device \(name)...")

	var context  = clCreateContext(nil, 1, &device, nil, nil, &err); e()
	var commands = clCreateCommandQueue(context, device, 0, &err); e()

	let KernelSource = "\n" +
		"__kernel void square( __global float* input, __global float* output, const unsigned int count) {\n" +
		"   int i = get_global_id(0);\n" +
		"   if(i < count)\n" +
		"       output[i] = input[i] * input[i];\n" +
	"}"

	let kernelChars = KernelSource.cStringUsingEncoding(NSUTF8StringEncoding)!
	var source = [ UnsafePointer<Int8>(kernelChars) ]

	program  = clCreateProgramWithSource(context, 1, &source, nil, &err); e()
	err          = clBuildProgram(program, 0, nil, nil, nil, nil); e()
	var kernel   = clCreateKernel(program, "square".cStringUsingEncoding(NSUTF8StringEncoding), &err); e()

	var n = UInt(numberOfDataElements)
	
	var results:[cl_float] = Array(count:Int(n), repeatedValue:cl_float(0.0))
	var input  = clCreateBuffer(context, cl_mem_flags(CL_MEM_READ_ONLY),  n * USize(cl_float), nil, nil)
	var output = clCreateBuffer(context, cl_mem_flags(CL_MEM_WRITE_ONLY), n * USize(cl_float), nil, nil)

	var data = [cl_float](count:numberOfDataElements, repeatedValue:cl_float(0.0))
	for i in 0..<n {
		data[Int(i)] = cl_float(random()) / cl_float(RAND_MAX)
	}

	var size:size_t = 0, ret_size:size_t = 0, psize:size_t = 0, local:size_t = 0, global:size_t = size_t(numberOfDataElements)

	let t3 = mach_absolute_time()
	err  = clEnqueueWriteBuffer    (commands, input, cl_bool(CL_TRUE), 0, n * USize(cl_float), data, 0, nil, nil); e()
	err  = clSetKernelArg          (kernel, 0, USize(cl_mem), &input); e()
	err |= clSetKernelArg          (kernel, 1, USize(cl_mem), &output); e()
	err |= clSetKernelArg          (kernel, 2, USize(cl_int), &n); e()
	err  = clGetKernelWorkGroupInfo(kernel, device, cl_kernel_work_group_info(CL_KERNEL_WORK_GROUP_SIZE), USize(size_t), &local, nil); e()
	err  = clEnqueueNDRangeKernel  (commands, kernel, 1, nil, &global, nil, 0, nil, nil); e()
	err  = clFinish                (commands); e()
	err  = clEnqueueReadBuffer     (commands, output, cl_bool(CL_TRUE), 0, n * USize(cl_float), &results, 0, nil, nil); e()
	let t4 = mach_absolute_time()-t3

	println("\nData Used: \((data[0...3]).map{$0*$0})...")
	println("Results  : \(results[0...3])...\n")

	var longLoop = [cl_float](count:numberOfDataElements, repeatedValue:cl_float(0.0))
	let t1 = mach_absolute_time()
	for j in 0..<n {
		let i = Int(j)
		longLoop[i] = data[i] * data[i]
	}
	let t2 = mach_absolute_time()-t1

	let t5 = mach_absolute_time()
	longLoop = data.map { $0 * $0 }
	let t6 = mach_absolute_time()-t5

	println(NSString(format: "%12tuns Single-threaded CPU Loop\n%12tuns Single-threaded CPU array mapping\n%12ins OpenCL\n", t2, t6, t4))
	println(NSString(format: "%12.1f times speed up over for loop", Double(t2)/Double(t4)))
	println(NSString(format: "%12.1f times speed up over array.map{ $0 * $0 }\n", Double(t6)/Double(t4)))

	var correct = 0
	for j in 0..<n {
		let i = Int(j)
		if abs(results[i] - longLoop[i]) < 0.0000000000001 {
			correct++
		}
	}
	println( "Computed \(correct) out of \(n) correct values!\n\n" )
}
*/

