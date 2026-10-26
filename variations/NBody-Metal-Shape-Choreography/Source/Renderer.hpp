#pragma once
#include <Metal/Metal.h>
#include <dispatch/dispatch.h>
#include <cstdint>

class Renderer {
public:
    Renderer(id<MTLDevice> device, NSURL* metallibURL, uint32_t N);
    void uploadInitialData(const float* posXYZW, const float* velXYZW, const float* mass);
    // Returns GPU time for this step in milliseconds (CPU-timed around command buffer completion)
    double step(float dt, bool waitForCompletion = true, float gravityScale = 1.0f, float centralScale = 1.0f);
    uint32_t size() const { return N_; }
public:
    id<MTLBuffer> positionBuffer() const { return bufPos_; }
    id<MTLCommandQueue> commandQueue() const { return queue_; }
private:

    id<MTLDevice> device_;
    id<MTLCommandQueue> queue_;
    id<MTLLibrary> library_;
    id<MTLComputePipelineState> psForces_;
    id<MTLComputePipelineState> psIntegrate_;
    id<MTLBuffer> bufPos_;
    id<MTLBuffer> bufVel_;
    id<MTLBuffer> bufMass_;
    id<MTLBuffer> bufAcc_;
    dispatch_semaphore_t inFlightSteps_;
    uint32_t N_;
};
