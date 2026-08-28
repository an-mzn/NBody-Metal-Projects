#pragma once
#include <Metal/Metal.h>
#include <cstdint>

class Renderer {
public:
    Renderer(id<MTLDevice> device, NSURL* metallibURL, uint32_t N);
    void uploadInitialData(const float* posXY, const float* velXY, const float* mass);
    // Returns GPU time for this step in milliseconds (CPU-timed around command buffer completion)
    double step(float dt);
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
    uint32_t N_;
};