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
    id<MTLFunction> fForces = [library_ newFunctionWithName:@"nbody_forces_tiled"];
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
    id<MTLBuffer> stPos  = [device_ newBufferWithLength:sizeof(float)*2*N_ options:MTLResourceStorageModeShared];
    id<MTLBuffer> stVel  = [device_ newBufferWithLength:sizeof(float)*2*N_ options:MTLResourceStorageModeShared];
    id<MTLBuffer> stMass = [device_ newBufferWithLength:sizeof(float)*N_   options:MTLResourceStorageModeShared];
    memcpy(stPos.contents,  posXY, sizeof(float)*2*N_);
    memcpy(stVel.contents,  velXY, sizeof(float)*2*N_);
    memcpy(stMass.contents, mass,  sizeof(float)*N_);

    id<MTLCommandBuffer> cb = [queue_ commandBuffer];
    id<MTLBlitCommandEncoder> blit = [cb blitCommandEncoder];
    [blit copyFromBuffer:stPos sourceOffset:0 toBuffer:bufPos_ destinationOffset:0 size:sizeof(float)*2*N_];
    [blit copyFromBuffer:stVel sourceOffset:0 toBuffer:bufVel_ destinationOffset:0 size:sizeof(float)*2*N_];
    [blit copyFromBuffer:stMass sourceOffset:0 toBuffer:bufMass_ destinationOffset:0 size:sizeof(float)*N_];
    [blit endEncoding];
    [cb commit];
    [cb waitUntilCompleted];
}

static inline void dispatch1D(id<MTLComputeCommandEncoder> enc, id<MTLComputePipelineState> ps, uint32_t N) {
    NSUInteger w = ps.threadExecutionWidth;
    // Choose tg size as 8x the execution width (typ. 32) → 256; guard by maxThreadsPerThreadgroup.
    NSUInteger tg = w * 8;
    tg = MIN(tg, ps.maxTotalThreadsPerThreadgroup);
    if (tg == 0) tg = w;
    MTLSize tgs = MTLSizeMake(tg, 1, 1);
    NSUInteger gridCount = ((N + tg - 1)/tg)*tg;
    MTLSize grid = MTLSizeMake(gridCount, 1, 1);
    [enc dispatchThreads:grid threadsPerThreadgroup:tgs];
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