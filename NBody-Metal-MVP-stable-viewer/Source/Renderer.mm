#import <Foundation/Foundation.h>
#import "Renderer.hpp"

Renderer::Renderer(id<MTLDevice> device, NSURL* metallibURL, uint32_t N)
: device_(device), N_(N) {
    NSError* err = nil;
    library_ = [device_ newLibraryWithURL:metallibURL error:&err];
    if (!library_) {
        NSLog(@"Failed to load metallib at %@: %@", metallibURL, err);
        abort();
    }
    id<MTLFunction> fForces = [library_ newFunctionWithName:@"nbody_forces"];
    id<MTLFunction> fIntegrate = [library_ newFunctionWithName:@"integrate"];
    psForces_ = [device_ newComputePipelineStateWithFunction:fForces error:&err];
    if (!psForces_) { NSLog(@"Failed to make pipeline (forces): %@", err); abort(); }
    psIntegrate_ = [device_ newComputePipelineStateWithFunction:fIntegrate error:&err];
    if (!psIntegrate_) { NSLog(@"Failed to make pipeline (integrate): %@", err); abort(); }

    queue_ = [device_ newCommandQueue];

    MTLResourceOptions opts = MTLResourceStorageModeShared; // unified memory on Apple Silicon
    bufPos_  = [device_ newBufferWithLength:sizeof(float)*2*N options:opts];
    bufVel_  = [device_ newBufferWithLength:sizeof(float)*2*N options:opts];
    bufMass_ = [device_ newBufferWithLength:sizeof(float)*N options:opts];
    bufAcc_  = [device_ newBufferWithLength:sizeof(float)*2*N options:opts];
}

void Renderer::uploadInitialData(const float* posXY, const float* velXY, const float* mass) {
    memcpy(bufPos_.contents, posXY, sizeof(float)*2*N_);
    memcpy(bufVel_.contents, velXY, sizeof(float)*2*N_);
    memcpy(bufMass_.contents, mass, sizeof(float)*N_);
}

static inline void dispatch1D(id<MTLComputeCommandEncoder> enc, id<MTLComputePipelineState> ps, uint32_t N) {
    NSUInteger w = ps.threadExecutionWidth;
    MTLSize tg = MTLSizeMake(w, 1, 1);
    NSUInteger gridCount = ((N + w - 1)/w)*w;
    MTLSize grid = MTLSizeMake(gridCount, 1, 1);
    [enc dispatchThreads:grid threadsPerThreadgroup:tg];
}

double Renderer::step(float dt) {
    NSDate* start = [NSDate date];
    id<MTLCommandBuffer> cb = [queue_ commandBuffer];

    // Pass 1: forces
    {
        id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];
        [enc setComputePipelineState:psForces_];
        [enc setBuffer:bufPos_  offset:0 atIndex:0];
        [enc setBuffer:bufMass_ offset:0 atIndex:1];
        [enc setBuffer:bufAcc_  offset:0 atIndex:2];
        [enc setBytes:&N_ length:sizeof(uint32_t) atIndex:3];
        dispatch1D(enc, psForces_, N_);
        [enc endEncoding];
    }
    // Pass 2: integrate
    {
        id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];
        [enc setComputePipelineState:psIntegrate_];
        [enc setBuffer:bufPos_ offset:0 atIndex:0];
        [enc setBuffer:bufVel_ offset:0 atIndex:1];
        [enc setBuffer:bufAcc_ offset:0 atIndex:2];
        [enc setBytes:&dt length:sizeof(float) atIndex:3];
        [enc setBytes:&N_  length:sizeof(uint32_t)  atIndex:4];
        dispatch1D(enc, psIntegrate_, N_);
        [enc endEncoding];
    }

    [cb commit];
    [cb waitUntilCompleted]; // fine for benchmarking a console MVP
    NSTimeInterval ms = [[NSDate date] timeIntervalSinceDate:start] * 1000.0;
    return (double)ms;
}