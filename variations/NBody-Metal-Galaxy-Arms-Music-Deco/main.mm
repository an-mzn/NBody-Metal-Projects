#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <cstdio>
#include <vector>
#include "Source/Renderer.hpp"
#include "Source/Sim.hpp"

static NSURL* metallibURLRelative(const char* rel) {
    NSString* cwd = [[NSFileManager defaultManager] currentDirectoryPath];
    NSString* path = [cwd stringByAppendingPathComponent:[NSString stringWithUTF8String:rel]];
    return [NSURL fileURLWithPath:path];
}

int main(int argc, const char** argv) {
    @autoreleasepool {
        uint32_t N = 50000; // default
        if (argc > 1) N = (uint32_t)std::max(1, atoi(argv[1]));
        float dt = 0.016f;

        id<MTLDevice> dev = MTLCreateSystemDefaultDevice();
        if (!dev) { printf("No Metal device.\n"); return 1; }

        NSURL* libURL = metallibURLRelative("Shaders/nbody.metallib");
        Renderer renderer(dev, libURL, N);

        auto init = makeInit(N);
        renderer.uploadInitialData(init.posXY.data(), init.velXY.data(), init.mass.data());

        // Warmup
        for (int i=0;i<30;++i) renderer.step(dt);

        // Measure
        const int steps = 300;
        double totalMs = 0.0;
        double p50=0, p95=0;
        std::vector<double> times;
        times.reserve(steps);
        for (int i=0;i<steps;++i) {
            double ms = renderer.step(dt);
            times.push_back(ms);
            totalMs += ms;
        }
        // Compute p50/p95
        std::sort(times.begin(), times.end());
        p50 = times[(int)(0.50 * times.size())];
        p95 = times[(int)(0.95 * times.size())];

        double avg = totalMs / steps;
        double fps = 1000.0 / avg;
        printf("Metal N-Body (N=%u)\n", N);
        printf("Avg frame: %.3f ms (FPS %.1f)  p50: %.3f ms  p95: %.3f ms\n", avg, fps, p50, p95);
        return 0;
    }
}