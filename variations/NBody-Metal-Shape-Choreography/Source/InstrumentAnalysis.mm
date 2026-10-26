#import "InstrumentAnalysis.hpp"
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>

namespace {
constexpr uint32_t cacheVersion = 3;
constexpr char cacheMagic[] = "NBMUSIC1";
static_assert(sizeof(MusicFrame) == 14 * sizeof(float), "Update the music cache when MusicFrame changes.");

void append(NSMutableData *data, const void *bytes, NSUInteger length) {
    [data appendBytes:bytes length:length];
}
MusicAnalysis readCachedAnalysis(NSString *path) {
    MusicAnalysis result;
    NSData *data = [NSData dataWithContentsOfFile:path];
    constexpr NSUInteger headerSize = sizeof(cacheMagic) - 1 + sizeof(uint32_t) + sizeof(uint64_t) + sizeof(double) + 3 * sizeof(float);
    if (data.length < headerSize) return result;
    const uint8_t *bytes = static_cast<const uint8_t *>(data.bytes);
    NSUInteger offset = 0;
    if (std::memcmp(bytes, cacheMagic, sizeof(cacheMagic)-1) != 0) return result;
    offset += sizeof(cacheMagic)-1;
    uint32_t version; uint64_t count;
    std::memcpy(&version, bytes+offset, sizeof(version)); offset += sizeof(version);
    std::memcpy(&count, bytes+offset, sizeof(count)); offset += sizeof(count);
    if (version != cacheVersion || count == 0 || count > 10'000'000 || data.length != headerSize + count*sizeof(MusicFrame)) return result;
    std::memcpy(&result.frameDuration, bytes+offset, sizeof(result.frameDuration)); offset += sizeof(result.frameDuration);
    std::memcpy(&result.bpm, bytes+offset, sizeof(result.bpm)); offset += sizeof(result.bpm);
    std::memcpy(&result.beatConfidence, bytes+offset, sizeof(result.beatConfidence)); offset += sizeof(result.beatConfidence);
    std::memcpy(&result.referenceEnergy, bytes+offset, sizeof(result.referenceEnergy)); offset += sizeof(result.referenceEnergy);
    if (!(result.frameDuration > 0) || !std::isfinite(result.frameDuration)) return MusicAnalysis{};
    result.frames.resize(size_t(count));
    std::memcpy(result.frames.data(), bytes+offset, count*sizeof(MusicFrame));
    return result;
}
void writeCachedAnalysis(const MusicAnalysis& analysis, NSString *path) {
    if (analysis.frames.empty()) return;
    NSMutableData *data = [NSMutableData data];
    append(data, cacheMagic, sizeof(cacheMagic)-1);
    append(data, &cacheVersion, sizeof(cacheVersion));
    const uint64_t count = analysis.frames.size();
    append(data, &count, sizeof(count));
    append(data, &analysis.frameDuration, sizeof(analysis.frameDuration));
    append(data, &analysis.bpm, sizeof(analysis.bpm));
    append(data, &analysis.beatConfidence, sizeof(analysis.beatConfidence));
    append(data, &analysis.referenceEnergy, sizeof(analysis.referenceEnergy));
    append(data, analysis.frames.data(), analysis.frames.size()*sizeof(MusicFrame));
    [data writeToFile:path options:NSDataWritingAtomic error:nil];
}
}

MusicAnalysis analyzeInstruments(NSURL *url) {
    MusicAnalysis result;
    NSString *runtime = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/NBody/instruments/bin/python3"];
    NSString *script = [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:@"Tools/separate_instruments.py"];
    if (![[NSFileManager defaultManager] isExecutableFileAtPath:runtime]) {
        result.error = @"Run Tools/setup_instruments.sh in the Shape Choreography folder, then reload the track.";
        return result;
    }
    NSTask *task = [NSTask new];
    task.executableURL = [NSURL fileURLWithPath:runtime];
    task.arguments = @[script, url.path];
    NSPipe *output = [NSPipe pipe];
    task.standardOutput = output;
    NSString *log = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"nbody-separation-%@.log", NSUUID.UUID.UUIDString]];
    [[NSFileManager defaultManager] createFileAtPath:log contents:nil attributes:nil];
    NSFileHandle *errors = [NSFileHandle fileHandleForWritingAtPath:log];
    task.standardError = errors;
    NSError *error = nil;
    if (![task launchAndReturnError:&error]) {
        [errors closeFile];
        [[NSFileManager defaultManager] removeItemAtPath:log error:nil];
        result.error = error.localizedDescription;
        return result;
    }
    NSData *data = [output.fileHandleForReading readDataToEndOfFile];
    [task waitUntilExit];
    [errors closeFile];
    if (task.terminationStatus != 0) {
        result.error = [NSString stringWithFormat:@"Instrument separation failed. Details: %@", log];
        return result;
    }
    [[NSFileManager defaultManager] removeItemAtPath:log error:nil];
    NSString *directory = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *analysisPath = [directory stringByAppendingPathComponent:@"analysis-v3.bin"];
    result = readCachedAnalysis(analysisPath);
    NSURL *sampleURL = url;
    if (!result.frames.empty()) { result.sampleURL = sampleURL; return result; }

    result = analyzeMusic(url);
    if (result.error) return result;
    NSArray<NSString *> *names = @[@"vocals", @"drums", @"bass", @"guitar", @"piano", @"other"];
    float MusicFrame::*outputs[] = {&MusicFrame::vocals, &MusicFrame::drums, &MusicFrame::instrumentBass, &MusicFrame::guitar, &MusicFrame::piano, &MusicFrame::other};
    for (NSUInteger source = 0; source < names.count; ++source) {
        NSURL *stemURL = [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:[names[source] stringByAppendingPathExtension:@"wav"]]];
        auto stem = analyzeMusic(stemURL);
        if (stem.error || stem.frames.empty()) {
            result.error = stem.error ?: @"Separated instrument contains no audio.";
            return result;
        }
        for (size_t i = 0; i < result.frames.size(); ++i) {
            const double position = i * result.frameDuration / stem.frameDuration;
            const size_t a = std::min(size_t(position), stem.frames.size()-1);
            const size_t b = std::min(a+1, stem.frames.size()-1);
            const float fraction = position - std::floor(position);
            const float energy = stem.rawEnergy[a] * (1-fraction) + stem.rawEnergy[b] * fraction;
            // Never normalize stems independently: that promoted quiet reverb
            // and made classifier confidence act as a proxy for loudness.
            result.frames[i].*outputs[source] = std::clamp(
                energy / std::max(result.referenceEnergy, 1e-8f), 0.0f, 1.0f);
        }
    }
    result.sampleURL = sampleURL;
    writeCachedAnalysis(result, analysisPath);
    return result;
}
