#pragma once
#ifndef CUDA_CACHE_UTIL
#define CUDA_CACHE_UTIL

#include "mLibCuda.h"

struct CUDACachedFrame {
	void alloc(unsigned int width, unsigned int height) {
		MLIB_CUDA_SAFE_CALL(cudaMalloc(&d_depthDownsampled, sizeof(float) * width * height));
		MLIB_CUDA_SAFE_CALL(cudaMalloc(&d_colorDownsampled, sizeof(uchar4) * width * height));
		MLIB_CUDA_SAFE_CALL(cudaMalloc(&d_cameraposDownsampled, sizeof(float4) * width * height));
		MLIB_CUDA_SAFE_CALL(cudaMalloc(&d_normalsDownsampled, sizeof(float4) * width * height));
	}
	void free() {
		MLIB_CUDA_SAFE_FREE(d_depthDownsampled);
		MLIB_CUDA_SAFE_FREE(d_colorDownsampled);
		MLIB_CUDA_SAFE_FREE(d_cameraposDownsampled);
		MLIB_CUDA_SAFE_FREE(d_normalsDownsampled);
	}

	float* d_depthDownsampled;
	uchar4* d_colorDownsampled;
	float4* d_cameraposDownsampled;
	float4* d_normalsDownsampled;
};

#endif //CUDA_CACHE_UTIL