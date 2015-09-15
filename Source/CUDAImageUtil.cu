
#include "CUDAImageUtil.h"

#include "mlibCuda.h"

#define T_PER_BLOCK 16
#define MINF __int_as_float(0xff800000)




template<class T> void CUDAImageUtil::copy(T* d_output, T* d_input, unsigned int width, unsigned int height) {
	MLIB_CUDA_SAFE_CALL(cudaMemcpy(d_output, d_input, sizeof(T)*width*height, cudaMemcpyDeviceToDevice));
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Resample Float Map
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

inline __device__ float bilinearInterpolationFloat(float x, float y, const float* d_input, unsigned int imageWidth, unsigned int imageHeight)
{
	const int2 p00 = make_int2(floor(x), floor(y));
	const int2 p01 = p00 + make_int2(0.0f, 1.0f);
	const int2 p10 = p00 + make_int2(1.0f, 0.0f);
	const int2 p11 = p00 + make_int2(1.0f, 1.0f);

	const float alpha = x - p00.x;
	const float beta = y - p00.y;

	float s0 = 0.0f; float w0 = 0.0f;
	if (p00.x < imageWidth && p00.y < imageHeight) { float v00 = d_input[p00.y*imageWidth + p00.x]; if (v00 != MINF) { s0 += (1.0f - alpha)*v00; w0 += (1.0f - alpha); } }
	if (p10.x < imageWidth && p10.y < imageHeight) { float v10 = d_input[p10.y*imageWidth + p10.x]; if (v10 != MINF) { s0 += alpha *v10; w0 += alpha; } }

	float s1 = 0.0f; float w1 = 0.0f;
	if (p01.x < imageWidth && p01.y < imageHeight) { float v01 = d_input[p01.y*imageWidth + p01.x]; if (v01 != MINF) { s1 += (1.0f - alpha)*v01; w1 += (1.0f - alpha); } }
	if (p11.x < imageWidth && p11.y < imageHeight) { float v11 = d_input[p11.y*imageWidth + p11.x]; if (v11 != MINF) { s1 += alpha *v11; w1 += alpha; } }

	const float p0 = s0 / w0;
	const float p1 = s1 / w1;

	float ss = 0.0f; float ww = 0.0f;
	if (w0 > 0.0f) { ss += (1.0f - beta)*p0; ww += (1.0f - beta); }
	if (w1 > 0.0f) { ss += beta *p1; ww += beta; }

	if (ww > 0.0f) return ss / ww;
	else		  return MINF;
}

//template<class T>
//__global__ void resample_Kernel(T* d_output, T* d_input, unsigned int inputWidth, unsigned int inputHeight, unsigned int outputWidth, unsigned int outputHeight)
//{
//	const unsigned int x = blockIdx.x*blockDim.x + threadIdx.x;
//	const unsigned int y = blockIdx.y*blockDim.y + threadIdx.y;
//
//	if (x < outputWidth && y < outputHeight)
//	{
//		const float scaleWidth = (float)(inputWidth - 1) / (float)(outputWidth - 1);
//		const float scaleHeight = (float)(inputHeight - 1) / (float)(outputHeight - 1);
//
//		const unsigned int xInput = (unsigned int)(x*scaleWidth + 0.5f);
//		const unsigned int yInput = (unsigned int)(y*scaleHeight + 0.5f);
//
//		if (xInput < inputWidth && yInput < inputHeight)
//		{
//			if (std::is_same<T, float>::value) {
//				d_output[y*outputWidth + x] = (T)bilinearInterpolationFloat(x*scaleWidth, y*scaleHeight, (float*)d_input, inputWidth, inputHeight);
//			}
//			else if (std::is_same<T, uchar4>::value) {
//				d_output[y*outputWidth + x] = d_input[yInput*inputWidth + xInput];
//			}
//			else {
//				//static_assert(false, "bla");
//			}
//		}
//	}
//}
//
//template<class T> void CUDAImageUtil::resample(T* d_output, unsigned int outputWidth, unsigned int outputHeight, T* d_input, unsigned int inputWidth, unsigned int inputHeight) {
//
//	const dim3 gridSize((outputWidth + T_PER_BLOCK - 1) / T_PER_BLOCK, (outputHeight + T_PER_BLOCK - 1) / T_PER_BLOCK);
//	const dim3 blockSize(T_PER_BLOCK, T_PER_BLOCK);
//
//	resample_Kernel << <gridSize, blockSize >> >(d_output, d_input, inputWidth, inputHeight, outputWidth, outputHeight);
//
//#ifdef _DEBUG
//	MLIB_CUDA_SAFE_CALL(cudaDeviceSynchronize());
//	MLIB_CUDA_CHECK_ERR(__FUNCTION__);
//#endif
//}


__global__ void resampleFloat_Kernel(float* d_output, unsigned int outputWidth, unsigned int outputHeight, const float* d_input, unsigned int inputWidth, unsigned int inputHeight)
{
	const unsigned int x = blockIdx.x*blockDim.x + threadIdx.x;
	const unsigned int y = blockIdx.y*blockDim.y + threadIdx.y;

	if (x < outputWidth && y < outputHeight)
	{
		const float scaleWidth = (float)(inputWidth - 1) / (float)(outputWidth - 1);
		const float scaleHeight = (float)(inputHeight - 1) / (float)(outputHeight - 1);

		const unsigned int xInput = (unsigned int)(x*scaleWidth + 0.5f);
		const unsigned int yInput = (unsigned int)(y*scaleHeight + 0.5f);

		if (xInput < inputWidth && yInput < inputHeight) {
			d_output[y*outputWidth + x] = d_input[yInput*inputWidth + xInput];
			//d_output[y*outputWidth + x] = bilinearInterpolationFloat(x*scaleWidth, y*scaleHeight, d_input, inputWidth, inputHeight);
		}
	}
}

void CUDAImageUtil::resampleFloat(float* d_output, unsigned int outputWidth, unsigned int outputHeight, const float* d_input, unsigned int inputWidth, unsigned int inputHeight) {

	const dim3 gridSize((outputWidth + T_PER_BLOCK - 1) / T_PER_BLOCK, (outputHeight + T_PER_BLOCK - 1) / T_PER_BLOCK);
	const dim3 blockSize(T_PER_BLOCK, T_PER_BLOCK);

	resampleFloat_Kernel << <gridSize, blockSize >> >(d_output, outputWidth, outputHeight, d_input, inputWidth, inputHeight);

#ifdef _DEBUG
	MLIB_CUDA_SAFE_CALL(cudaDeviceSynchronize());
	MLIB_CUDA_CHECK_ERR(__FUNCTION__);
#endif
}


__global__ void resampleUCHAR4_Kernel(uchar4* d_output, unsigned int outputWidth, unsigned int outputHeight, const uchar4* d_input, unsigned int inputWidth, unsigned int inputHeight)
{
	const unsigned int x = blockIdx.x*blockDim.x + threadIdx.x;
	const unsigned int y = blockIdx.y*blockDim.y + threadIdx.y;

	if (x < outputWidth && y < outputHeight)
	{
		const float scaleWidth = (float)(inputWidth - 1) / (float)(outputWidth - 1);
		const float scaleHeight = (float)(inputHeight - 1) / (float)(outputHeight - 1);

		const unsigned int xInput = (unsigned int)(x*scaleWidth + 0.5f);
		const unsigned int yInput = (unsigned int)(y*scaleHeight + 0.5f);

		if (xInput < inputWidth && yInput < inputHeight) {
			d_output[y*outputWidth + x] = d_input[yInput*inputWidth + xInput];
		}
	}
}

void CUDAImageUtil::resampleUCHAR4(uchar4* d_output, unsigned int outputWidth, unsigned int outputHeight, const uchar4* d_input, unsigned int inputWidth, unsigned int inputHeight) {

	const dim3 gridSize((outputWidth + T_PER_BLOCK - 1) / T_PER_BLOCK, (outputHeight + T_PER_BLOCK - 1) / T_PER_BLOCK);
	const dim3 blockSize(T_PER_BLOCK, T_PER_BLOCK);

	resampleUCHAR4_Kernel << <gridSize, blockSize >> >(d_output, outputWidth, outputHeight, d_input, inputWidth, inputHeight);

#ifdef _DEBUG
	MLIB_CUDA_SAFE_CALL(cudaDeviceSynchronize());
	MLIB_CUDA_CHECK_ERR(__FUNCTION__);
#endif
}

__host__ __device__
float convertToIntensity(const uchar4& c) {
	return (0.299f*c.x + 0.587f*c.y + 0.114f*c.z) / 255.0f;
}

__global__ void resampleToIntensity_Kernel(float* d_output, unsigned int outputWidth, unsigned int outputHeight, const uchar4* d_input, unsigned int inputWidth, unsigned int inputHeight)
{
	const unsigned int x = blockIdx.x*blockDim.x + threadIdx.x;
	const unsigned int y = blockIdx.y*blockDim.y + threadIdx.y;

	if (x < outputWidth && y < outputHeight)
	{
		const float scaleWidth = (float)(inputWidth - 1) / (float)(outputWidth - 1);
		const float scaleHeight = (float)(inputHeight - 1) / (float)(outputHeight - 1);

		const unsigned int xInput = (unsigned int)(x*scaleWidth + 0.5f);
		const unsigned int yInput = (unsigned int)(y*scaleHeight + 0.5f);

		if (xInput < inputWidth && yInput < inputHeight) {
			d_output[y*outputWidth + x] = convertToIntensity(d_input[yInput*inputWidth + xInput]);
		}
	}
}

void CUDAImageUtil::resampleToIntensity(float* d_output, unsigned int outputWidth, unsigned int outputHeight, uchar4* d_input, unsigned int inputWidth, unsigned int inputHeight) {

	const dim3 gridSize((outputWidth + T_PER_BLOCK - 1) / T_PER_BLOCK, (outputHeight + T_PER_BLOCK - 1) / T_PER_BLOCK);
	const dim3 blockSize(T_PER_BLOCK, T_PER_BLOCK);

	resampleToIntensity_Kernel << <gridSize, blockSize >> >(d_output, outputWidth, outputHeight, d_input, inputWidth, inputHeight);

#ifdef _DEBUG
	MLIB_CUDA_SAFE_CALL(cudaDeviceSynchronize());
	MLIB_CUDA_CHECK_ERR(__FUNCTION__);
#endif
}







////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Convert Depth to Camera Space Positions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

__global__ void convertDepthFloatToCameraSpaceFloat4_Kernel(float4* d_output, float* d_input, float4x4 intrinsicsInv, unsigned int width, unsigned int height)
{
	const unsigned int x = blockIdx.x*blockDim.x + threadIdx.x;
	const unsigned int y = blockIdx.y*blockDim.y + threadIdx.y;

	if (x < width && y < height) {
		d_output[y*width + x] = make_float4(MINF, MINF, MINF, MINF);

		float depth = d_input[y*width + x];

		if (depth != MINF)
		{
			float4 cameraSpace(intrinsicsInv*make_float4((float)x*depth, (float)y*depth, depth, depth));
			d_output[y*width+x] = make_float4(cameraSpace.x, cameraSpace.y, cameraSpace.w, 1.0f);
			//d_output[y*width + x] = make_float4(depthCameraData.kinectDepthToSkeleton(x, y, depth), 1.0f);
		}
	}
}

void CUDAImageUtil::convertDepthFloatToCameraSpaceFloat4(float4* d_output, float* d_input, const float4x4& intrinsicsInv, unsigned int width, unsigned int height)
{
	const dim3 gridSize((width + T_PER_BLOCK - 1) / T_PER_BLOCK, (height + T_PER_BLOCK - 1) / T_PER_BLOCK);
	const dim3 blockSize(T_PER_BLOCK, T_PER_BLOCK);

	convertDepthFloatToCameraSpaceFloat4_Kernel<< <gridSize, blockSize >> >(d_output, d_input, intrinsicsInv, width, height);

#ifdef _DEBUG
	MLIB_CUDA_SAFE_CALL(cudaDeviceSynchronize());
	MLIB_CUDA_CHECK_ERR(__FUNCTION__);
#endif
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Compute Normal Map
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

__global__ void computeNormals_Kernel(float4* d_output, float4* d_input, unsigned int width, unsigned int height)
{
	const unsigned int x = blockIdx.x*blockDim.x + threadIdx.x;
	const unsigned int y = blockIdx.y*blockDim.y + threadIdx.y;

	if(x >= width || y >= height) return;

	d_output[y*width+x] = make_float4(MINF, MINF, MINF, MINF);

	if(x > 0 && x < width-1 && y > 0 && y < height-1)
	{
		const float4 CC = d_input[(y+0)*width+(x+0)];
		const float4 PC = d_input[(y+1)*width+(x+0)];
		const float4 CP = d_input[(y+0)*width+(x+1)];
		const float4 MC = d_input[(y-1)*width+(x+0)];
		const float4 CM = d_input[(y+0)*width+(x-1)];

		if(CC.x != MINF && PC.x != MINF && CP.x != MINF && MC.x != MINF && CM.x != MINF)
		{
			const float3 n = cross(make_float3(PC)-make_float3(MC), make_float3(CP)-make_float3(CM));
			const float  l = length(n);

			if(l > 0.0f)
			{
				d_output[y*width+x] = make_float4(n/-l, 1.0f);
			}
		}
	}
}

void CUDAImageUtil::computeNormals(float4* d_output, float4* d_input, unsigned int width, unsigned int height)
{
	const dim3 gridSize((width + T_PER_BLOCK - 1)/T_PER_BLOCK, (height + T_PER_BLOCK - 1)/T_PER_BLOCK);
	const dim3 blockSize(T_PER_BLOCK, T_PER_BLOCK);

	computeNormals_Kernel<<<gridSize, blockSize>>>(d_output, d_input, width, height);

#ifdef _DEBUG
	cutilSafeCall(cudaDeviceSynchronize());
	cutilCheckMsg(__FUNCTION__);
#endif
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Joint Bilateral Filter
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

inline __device__ float gaussD(float sigma, int x, int y)
{
	return exp(-((x*x+y*y)/(2.0f*sigma*sigma)));
}
inline __device__ float gaussR(float sigma, float dist)
{
	return exp(-(dist*dist)/(2.0*sigma*sigma));
}

__global__ void bilateralFilterUCHAR4_Kernel(uchar4* d_output, uchar4* d_color, float* d_depth, float sigmaD, float sigmaR, unsigned int width, unsigned int height)
{
	const int x = blockIdx.x*blockDim.x + threadIdx.x;
	const int y = blockIdx.y*blockDim.y + threadIdx.y;

	if(x >= width || y >= height) return;

	const int kernelRadius = (int)ceil(2.0*sigmaD);

	d_output[y*width+x] = d_color[y*width+x];

	float3 sum = make_float3(0.0f, 0.0f, 0.0f);
	float sumWeight = 0.0f;

	//const uchar4 center = d_color[y*width+x];
	const float depthCenter = d_depth[y*width+x];
	if(depthCenter != MINF)
	{
		for(int m = x-kernelRadius; m <= x+kernelRadius; m++)
		{
			for(int n = y-kernelRadius; n <= y+kernelRadius; n++)
			{		
				if(m >= 0 && n >= 0 && m < width && n < height)
				{
					const uchar4 cur = d_color[n*width+m];
					const float currentDepth = d_depth[n*width+m];

					if (currentDepth != MINF) {
						const float weight = gaussD(sigmaD, m-x, n-y)*gaussR(sigmaR, currentDepth-depthCenter);

						sumWeight += weight;
						sum += weight*make_float3(cur.x, cur.y, cur.z);
					}
				}
			}
		}

		if (sumWeight > 0.0f) {
			float3 res = sum / sumWeight;
			d_output[y*width + x] = make_uchar4((uchar)res.x, (uchar)res.y, (uchar)res.z, 255);
		}
	}
}

void CUDAImageUtil::jointBilateralFilterFloatMap(uchar4* d_output, uchar4* d_input, float* d_depth, float sigmaD, float sigmaR, unsigned int width, unsigned int height)
{
	const dim3 gridSize((width + T_PER_BLOCK - 1)/T_PER_BLOCK, (height + T_PER_BLOCK - 1)/T_PER_BLOCK);
	const dim3 blockSize(T_PER_BLOCK, T_PER_BLOCK);

	bilateralFilterUCHAR4_Kernel<<<gridSize, blockSize>>>(d_output, d_input, d_depth, sigmaD, sigmaR, width, height);
#ifdef _DEBUG
	cutilSafeCall(cudaDeviceSynchronize());
	cutilCheckMsg(__FUNCTION__);
#endif
}