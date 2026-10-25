#import "MusicAnalysis.hpp"
#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>
#include <algorithm>
#include <array>
#include <cmath>
#include <numeric>

namespace {
constexpr size_t bandCount = 32, chromaCount = 12;
struct Spectrum {
    std::array<float, bandCount + chromaCount> features{};
    MusicFrame music;
};
float percentile(std::vector<float> values, float fraction) {
    if (values.empty()) return 0;
    size_t index = std::min(values.size()-1, size_t(fraction * (values.size()-1)));
    std::nth_element(values.begin(), values.begin()+index, values.end());
    return values[index];
}
void normalize(std::vector<MusicFrame>& frames, float MusicFrame::*field) {
    std::vector<float> values;
    for (const auto& frame : frames) values.push_back(frame.*field);
    const float reference = std::max(1e-8f, percentile(values, 0.95f));
    for (auto& frame : frames) frame.*field = std::clamp(frame.*field / reference, 0.0f, 1.0f);
}
}

MusicAnalysis analyzeMusic(NSURL *url) {
    MusicAnalysis result;
    NSError *error = nil;
    AVAudioFile *file = [[AVAudioFile alloc] initForReading:url error:&error];
    if (!file) { result.error = error.localizedDescription; return result; }
    const double rate = file.processingFormat.sampleRate;
    const unsigned channels = file.processingFormat.channelCount;
    const unsigned logSize = std::clamp((unsigned)std::lround(std::log2(rate * 0.046)), 9u, 14u);
    const unsigned size = 1u << logSize, hop = size / 4;
    result.frameDuration = double(hop) / rate;
    FFTSetup fft = vDSP_create_fftsetup(logSize, kFFTRadix2);
    if (!fft) { result.error = @"Could not create spectral analyzer."; return result; }
    AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:file.processingFormat frameCapacity:hop];
    std::vector<std::vector<float>> history(channels, std::vector<float>(size, 0));
    std::vector<float> window(size), input(size), real(size/2), imaginary(size/2), power(size/2);
    vDSP_hann_window(window.data(), size, vDSP_HANN_NORM);
    DSPSplitComplex split = {real.data(), imaginary.data()};
    std::vector<Spectrum> spectra;
    std::array<float, bandCount> previous{};
    const double highest = std::min(16000.0, rate * 0.49);
    const double frequencyRange = std::log(highest / 30.0);
    AVAudioFramePosition consumed = 0;
    float previousEnergy = 0;
    bool readFailed = false;
    // Centered windows: pad the head and tail so frame zero describes time zero.
    const AVAudioFramePosition paddedEnd = file.length + size/2;
    while (consumed < paddedEnd) {
        unsigned read = 0;
        if (file.framePosition < file.length) {
            if (![file readIntoBuffer:buffer error:&error] || !buffer.floatChannelData) { readFailed = true; break; }
            read = buffer.frameLength;
        }
        std::fill(power.begin(), power.end(), 0);
        for (unsigned channel = 0; channel < channels; ++channel) {
            auto& samples = history[channel];
            std::move(samples.begin()+hop, samples.end(), samples.begin());
            std::fill(samples.end()-hop, samples.end(), 0);
            for (unsigned i = 0; i < read; ++i) {
                const float value = buffer.floatChannelData[channel][i * buffer.stride];
                samples[size-hop+i] = value;
            }
            vDSP_vmul(samples.data(), 1, window.data(), 1, input.data(), 1, size);
            vDSP_ctoz(reinterpret_cast<const DSPComplex *>(input.data()), 2, &split, 1, size/2);
            vDSP_fft_zrip(fft, &split, 1, logSize, FFT_FORWARD);
            // FFT channels separately; opposite stereo phases must not cancel attacks.
            imaginary[0] = 0;
            for (unsigned k = 1; k < size/2; ++k) {
                power[k] += (real[k]*real[k] + imaginary[k]*imaginary[k]) / (float(size)*size*channels);
            }
        }
        consumed += hop;
        const double center = double(consumed) - size/2;
        if (center < 0 || center >= file.length) continue;
        Spectrum spectrum;
        double total = 0, centroid = 0, bass = 0, mid = 0, treble = 0;
        const float spectralFloor = *std::max_element(power.begin(), power.end()) * 1e-5f;
        for (unsigned k = 1; k < size/2; ++k) {
            const double frequency = double(k) * rate / size;
            if (frequency < 30 || frequency > highest) continue;
            const float amplitude = power[k];
            if (amplitude < spectralFloor) continue;
            const size_t band = std::min(bandCount-1, size_t(std::log(frequency / 30.0) / frequencyRange * bandCount));
            spectrum.features[band] += amplitude;
            total += amplitude;
            centroid += amplitude * frequency;
            if (frequency < 250) bass += amplitude;
            else if (frequency < 2500) mid += amplitude;
            else treble += amplitude;
            if (frequency >= 65 && frequency <= 5000) {
                const int note = int(std::lround(69.0 + 12.0*std::log2(frequency/440.0)));
                spectrum.features[bandCount + (note%12+12)%12] += amplitude;
            }
        }
        float flux = 0;
        for (size_t band = 0; band < spectrum.features.size(); ++band) {
            spectrum.features[band] = std::log1p(spectrum.features[band] * 100000.0f);
            if (band < bandCount) {
                flux += std::max(0.0f, spectrum.features[band] - previous[band]);
                previous[band] = spectrum.features[band];
            }
        }
        // RMS is taken from the centered spectrum's energy, not a later decode block.
        const float energy = std::sqrt(total);
        spectrum.music.energy = energy;
        spectrum.music.attack = spectra.empty() ? 0 : flux / bandCount + std::max(0.0f, energy-previousEnergy);
        spectrum.music.brightness = total > 1e-10 ? std::clamp(float(centroid/total/6000.0), 0.0f, 1.0f) : 0;
        spectrum.music.bass = bass > total*0.005 ? std::sqrt(bass) : 0;
        spectrum.music.mid = mid > total*0.005 ? std::sqrt(mid) : 0;
        spectrum.music.treble = treble > total*0.005 ? std::sqrt(treble) : 0;
        previousEnergy = energy;
        spectra.push_back(spectrum);
    }
    vDSP_destroy_fftsetup(fft);
    if (readFailed || spectra.empty()) {
        result.error = error ? error.localizedDescription : @"Audio contains no decodable samples.";
        return result;
    }
    const size_t count = spectra.size();
    result.frames.reserve(count);
    for (const auto& spectrum : spectra) result.frames.push_back(spectrum.music);
    // Spectral and pitch-class context on either side identifies transitions
    // between contrasting passages; it does not claim chorus/verse semantics.
    using Context = std::array<double, bandCount+chromaCount>;
    std::vector<Context> prefix(count+1);
    for (size_t i = 0; i < count; ++i)
        for (size_t band = 0; band < prefix[0].size(); ++band)
            prefix[i+1][band] = prefix[i][band] + spectra[i].features[band];
    const size_t context = std::max(size_t(1), size_t(2.0/result.frameDuration));
    for (size_t i = 1; i+1 < count; ++i) {
        size_t left = i > context ? i-context : 0, right = std::min(count, i+context);
        if (i-left < context/2 || right-i < context/2) continue;
        double product = 0, leftPower = 0, rightPower = 0;
        for (size_t band = 0; band < prefix[0].size(); ++band) {
            const double a = (prefix[i][band]-prefix[left][band]) / (i-left);
            const double b = (prefix[right][band]-prefix[i][band]) / (right-i);
            product += a*b; leftPower += a*a; rightPower += b*b;
        }
        result.frames[i].phrase = leftPower > 1e-8 && rightPower > 1e-8
            ? std::max(0.0, 1.0-product/std::sqrt(leftPower*rightPower)) : 0;
    }
    // Adaptive onset baseline rejects constant texture and emphasizes local attacks.
    std::vector<double> fluxPrefix(count+1, 0);
    for (size_t i = 0; i < count; ++i) fluxPrefix[i+1] = fluxPrefix[i] + result.frames[i].attack;
    const size_t neighborhood = std::max(size_t(1), size_t(0.20/result.frameDuration));
    for (size_t i = 0; i < count; ++i) {
        size_t left = i > neighborhood ? i-neighborhood : 0, right = std::min(count, i+neighborhood+1);
        const float baseline = (fluxPrefix[right]-fluxPrefix[left]) / (right-left);
        result.frames[i].attack = std::max(0.0f, result.frames[i].attack - baseline*0.8f - 0.01f);
    }
    for (auto field : {&MusicFrame::energy, &MusicFrame::attack, &MusicFrame::bass,
                       &MusicFrame::mid, &MusicFrame::treble, &MusicFrame::phrase}) normalize(result.frames, field);
    // Estimate a global tempo from onset autocorrelation, with a confidence gate.
    const size_t minimumLag = std::max(size_t(1), size_t(60.0/180/result.frameDuration));
    const size_t maximumLag = std::min(count/3, size_t(60.0/65/result.frameDuration));
    float best = 0; size_t bestLag = 0;
    for (size_t lag = minimumLag; lag <= maximumLag; ++lag) {
        double product = 0, aPower = 0, bPower = 0;
        for (size_t i = lag; i < count; ++i) {
            float a = result.frames[i].attack, b = result.frames[i-lag].attack;
            product += a*b; aPower += a*a; bPower += b*b;
        }
        float correlation = aPower*bPower > 1e-8 ? product/std::sqrt(aPower*bPower) : 0;
        if (correlation > best) { best = correlation; bestLag = lag; }
    }
    if (bestLag && best > 0.18f) {
        result.bpm = 60.0 / (bestLag * result.frameDuration);
        result.beatConfidence = std::clamp((best-0.18f)/0.55f, 0.0f, 1.0f);
        std::vector<float> phaseEnergy(bestLag, 0);
        for (size_t i = 0; i < count; ++i) phaseEnergy[i%bestLag] += result.frames[i].attack;
        const size_t phase = std::max_element(phaseEnergy.begin(), phaseEnergy.end())-phaseEnergy.begin();
        for (size_t i = 0; i < count; ++i) {
            const double cycles = (double(i)-phase) / bestLag;
            const double distance = std::abs(cycles-std::round(cycles)) * bestLag * result.frameDuration;
            // Only reinforce real attacks near the estimated beat, never invent hits.
            result.frames[i].beat = result.frames[i].attack * std::exp(-distance*distance/(2*0.09*0.09)) * result.beatConfidence;
        }
    }
    // Preserve short accents across display frames. Tempo detection above uses
    // the original narrow peaks; choreography gets a continuous decay envelope.
    float attackEnvelope = 0, beatEnvelope = 0;
    const float attackDecay = std::exp(-result.frameDuration / 0.16);
    const float beatDecay = std::exp(-result.frameDuration / 0.20);
    for (auto& frame : result.frames) {
        attackEnvelope = std::max(frame.attack, attackEnvelope * attackDecay);
        beatEnvelope = std::max(frame.beat, beatEnvelope * beatDecay);
        frame.attack = attackEnvelope;
        frame.beat = beatEnvelope;
    }
    NSLog(@"Spectral map: %zu frames, %.1f ms spacing, 32 bands + 12 pitch classes; tempo %.1f BPM (confidence %.2f).",
          count, result.frameDuration*1000, result.bpm, result.beatConfidence);
    return result;
}
