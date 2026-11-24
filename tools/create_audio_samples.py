import os
import wave
import struct
import math

def generate_wav(path, duration_sec=1.5, sample_rate=16000, freqs=[440], noise_level=0.0):
    num_samples = int(duration_sec * sample_rate)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, 'w') as wav_file:
        wav_file.setnchannels(1) # mono
        wav_file.setsampwidth(2) # 16-bit
        wav_file.setframerate(sample_rate)
        
        for i in range(num_samples):
            t = float(i) / sample_rate
            val = 0.0
            # Tone components
            for f in freqs:
                val += 0.5 * math.sin(2.0 * math.pi * f * t)
            # Add subtle envelope
            envelope = math.sin(math.pi * (i / num_samples))
            val *= envelope
            # Optional noise
            if noise_level > 0.0:
                val += noise_level * (math.sin(2.0 * math.pi * 1234.5 * t) + math.sin(2.0 * math.pi * 3456.7 * t))
            # Clamp to 16-bit signed integer
            val = max(-1.0, min(1.0, val))
            sample = int(val * 32767.0)
            wav_file.writeframes(struct.pack('<h', sample))
    print(f"Generated sample: {path} ({duration_sec}s, {sample_rate}Hz)")

generate_wav("assets/audio_samples/correct_kora.wav", duration_sec=1.2, freqs=[300, 600, 1200])
generate_wav("assets/audio_samples/error_tora.wav", duration_sec=1.2, freqs=[500, 1000, 2000])
generate_wav("assets/audio_samples/correct_samaka.wav", duration_sec=1.5, freqs=[400, 800, 1600])
generate_wav("assets/audio_samples/noisy_speech.wav", duration_sec=2.0, freqs=[350, 700], noise_level=0.25)
