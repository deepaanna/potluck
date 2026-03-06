"""Generate placeholder SFX and BGM WAV files for Pot Luck.
Produces short, characteristic sounds using pure synthesis.
Replace with Kenney or licensed assets for production."""

import struct, math, random, wave, os

SAMPLE_RATE = 44100

def write_wav(filename, samples, sample_rate=SAMPLE_RATE):
    """Write mono 16-bit WAV file."""
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    with wave.open(filename, 'w') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(sample_rate)
        data = b''
        for s in samples:
            s = max(-1.0, min(1.0, s))
            data += struct.pack('<h', int(s * 32767))
        f.writeframes(data)
    print(f"  Created: {filename} ({len(samples)/sample_rate:.2f}s)")


def envelope(t, attack, decay, sustain_level, release, duration):
    """ADSR envelope."""
    if t < attack:
        return t / attack if attack > 0 else 1.0
    elif t < attack + decay:
        return 1.0 - (1.0 - sustain_level) * ((t - attack) / decay)
    elif t < duration - release:
        return sustain_level
    else:
        remaining = duration - t
        return sustain_level * (remaining / release) if release > 0 else 0.0


def gen_sizzle(duration=0.4):
    """Crackling sizzle — filtered noise bursts."""
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Bandpass-ish noise via multiple sine harmonics with random phase
        noise = 0
        for freq in [3000, 4500, 6000, 7500, 9000]:
            noise += math.sin(2 * math.pi * freq * t + random.random() * 6.28) * 0.15
        noise += random.uniform(-0.3, 0.3)  # broadband component
        env = envelope(t, 0.01, 0.05, 0.6, 0.15, duration)
        samples.append(noise * env * 0.5)
    return samples


def gen_bubble(duration=0.3):
    """Bubble pop — descending sine with resonance."""
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 800 * math.exp(-t * 8)  # rapid descent
        s = math.sin(2 * math.pi * freq * t) * 0.7
        # Add a click at the start
        if t < 0.005:
            s += random.uniform(-0.5, 0.5)
        env = envelope(t, 0.002, 0.05, 0.3, 0.1, duration)
        samples.append(s * env)
    return samples


def gen_explosion(duration=0.8):
    """Boilover explosion — noise burst with low rumble."""
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Noise burst
        noise = random.uniform(-1, 1)
        # Low frequency rumble
        rumble = math.sin(2 * math.pi * 60 * t) * 0.4
        rumble += math.sin(2 * math.pi * 90 * t) * 0.3
        # Mid crackle
        crackle = math.sin(2 * math.pi * 200 * t + random.random()) * 0.2
        env = envelope(t, 0.005, 0.15, 0.3, 0.4, duration)
        samples.append((noise * 0.5 + rumble + crackle) * env * 0.6)
    return samples


def gen_ding(duration=0.5):
    """Bright ding — bell-like tone."""
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Bell harmonics
        s = math.sin(2 * math.pi * 1200 * t) * 0.5
        s += math.sin(2 * math.pi * 2400 * t) * 0.25
        s += math.sin(2 * math.pi * 3600 * t) * 0.12
        s += math.sin(2 * math.pi * 4800 * t) * 0.06
        env = math.exp(-t * 6)  # exponential decay
        samples.append(s * env * 0.7)
    return samples


def gen_whoosh(duration=0.25):
    """Whoosh — filtered noise sweep."""
    n = int(SAMPLE_RATE * duration)
    samples = []
    prev = 0
    for i in range(n):
        t = i / SAMPLE_RATE
        # Sweep frequency of the "filter"
        sweep = 500 + 4000 * (t / duration)
        noise = random.uniform(-1, 1)
        # Simple low-pass via exponential smoothing (cutoff rises)
        alpha = min(1.0, sweep / SAMPLE_RATE * 2 * math.pi * 0.1)
        prev = prev + alpha * (noise - prev)
        # Volume envelope: quick ramp, sustain, quick drop
        env = envelope(t, 0.02, 0.03, 0.8, 0.08, duration)
        samples.append(prev * env * 2.0)
    return samples


def gen_draw(duration=0.2):
    """Card draw — short rising tone with noise."""
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 400 + 600 * (t / duration)  # rising
        s = math.sin(2 * math.pi * freq * t) * 0.3
        s += random.uniform(-0.15, 0.15)  # paper noise
        env = envelope(t, 0.01, 0.05, 0.7, 0.08, duration)
        samples.append(s * env)
    return samples


def gen_flick(duration=0.15):
    """Flick — quick snap downward."""
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 600 - 300 * (t / duration)  # descending
        s = math.sin(2 * math.pi * freq * t) * 0.4
        s += random.uniform(-0.2, 0.2)
        env = envelope(t, 0.005, 0.03, 0.5, 0.06, duration)
        samples.append(s * env)
    return samples


def gen_splash(duration=0.35):
    """Splash into pot — noise burst + bubbles."""
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Initial splash noise
        splash = random.uniform(-0.6, 0.6) * math.exp(-t * 12)
        # Bubble tones
        b1 = math.sin(2 * math.pi * 500 * math.exp(-t * 5) * t) * 0.3
        b2 = math.sin(2 * math.pi * 700 * math.exp(-t * 7) * t) * 0.2
        env = envelope(t, 0.003, 0.08, 0.3, 0.15, duration)
        samples.append((splash + b1 + b2) * env)
    return samples


def gen_combo(duration=0.4):
    """Combo trigger — ascending sparkle chord."""
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        s = 0
        # Ascending arpeggiated chord
        for j, freq in enumerate([800, 1000, 1200, 1500]):
            delay = j * 0.03
            if t > delay:
                tt = t - delay
                s += math.sin(2 * math.pi * freq * tt) * 0.2 * math.exp(-tt * 5)
        # Sparkle
        s += math.sin(2 * math.pi * 3000 * t) * 0.08 * math.exp(-t * 8)
        samples.append(s * 0.8)
    return samples


def gen_combo_penalty(duration=0.4):
    """Penalty combo — dissonant descending tones."""
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        freq1 = 400 - 150 * (t / duration)
        freq2 = 450 - 180 * (t / duration)  # slightly detuned
        s = math.sin(2 * math.pi * freq1 * t) * 0.35
        s += math.sin(2 * math.pi * freq2 * t) * 0.35
        s += random.uniform(-0.1, 0.1)
        env = envelope(t, 0.01, 0.1, 0.5, 0.15, duration)
        samples.append(s * env)
    return samples


def gen_serve(duration=0.6):
    """Serve dish — triumphant ascending chord."""
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        s = 0
        # Major chord sweep up
        for j, freq in enumerate([523, 659, 784, 1047]):  # C5, E5, G5, C6
            delay = j * 0.05
            if t > delay:
                tt = t - delay
                s += math.sin(2 * math.pi * freq * tt) * 0.2 * math.exp(-tt * 3)
        env = envelope(t, 0.01, 0.1, 0.6, 0.25, duration)
        samples.append(s * env)
    return samples


def gen_second_chance(duration=0.5):
    """Second chance — hopeful rising tone."""
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 300 + 500 * (t / duration) ** 0.5
        s = math.sin(2 * math.pi * freq * t) * 0.4
        s += math.sin(2 * math.pi * freq * 2 * t) * 0.15
        env = envelope(t, 0.02, 0.08, 0.6, 0.2, duration)
        samples.append(s * env)
    return samples


def gen_sizzle_loop(duration=2.0):
    """Continuous sizzle loop — designed for seamless looping."""
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Layered noise for consistent sizzle texture
        noise = 0
        for freq in [2000, 3500, 5000, 7000, 9500]:
            phase = freq * 0.1  # fixed phase offset per freq
            noise += math.sin(2 * math.pi * freq * t + phase +
                            math.sin(t * 13 + phase) * 2) * 0.12
        noise += random.uniform(-0.2, 0.2)
        # Subtle amplitude modulation for organic feel
        mod = 0.7 + 0.3 * math.sin(2 * math.pi * 3.5 * t)
        # Crossfade at loop boundaries for seamlessness
        fade = 1.0
        fade_time = 0.05
        if t < fade_time:
            fade = t / fade_time
        elif t > duration - fade_time:
            fade = (duration - t) / fade_time
        samples.append(noise * mod * fade * 0.35)
    return samples


def gen_menu_bgm(duration=16.0):
    """Chill ambient menu loop — gentle pad with subtle movement."""
    n = int(SAMPLE_RATE * duration)
    samples = []
    # Chord progression: Cmaj7 → Am7 → Fmaj7 → G7
    chords = [
        [261.6, 329.6, 392.0, 493.9],   # Cmaj7
        [220.0, 261.6, 329.6, 392.0],   # Am7
        [174.6, 220.0, 261.6, 329.6],   # Fmaj7
        [196.0, 246.9, 293.7, 349.2],   # G7
    ]
    chord_dur = duration / len(chords)

    for i in range(n):
        t = i / SAMPLE_RATE
        chord_idx = min(int(t / chord_dur), len(chords) - 1)
        chord_t = (t % chord_dur) / chord_dur  # 0-1 within chord
        freqs = chords[chord_idx]

        s = 0
        for j, freq in enumerate(freqs):
            # Gentle sine pad with slow vibrato
            vibrato = math.sin(2 * math.pi * 4.5 * t + j) * 2
            s += math.sin(2 * math.pi * (freq + vibrato) * t) * 0.08
            # Octave below for warmth
            s += math.sin(2 * math.pi * (freq / 2 + vibrato * 0.5) * t) * 0.04

        # Subtle LFO movement
        lfo = 0.8 + 0.2 * math.sin(2 * math.pi * 0.25 * t)
        s *= lfo

        # Loop crossfade
        fade = 1.0
        fade_time = 0.5
        if t < fade_time:
            fade = t / fade_time
        elif t > duration - fade_time:
            fade = (duration - t) / fade_time

        samples.append(s * fade * 0.6)
    return samples


def gen_game_bgm(duration=16.0):
    """Upbeat game loop — rhythmic pulse with tension."""
    n = int(SAMPLE_RATE * duration)
    samples = []
    bpm = 120
    beat_dur = 60.0 / bpm

    # Minor key progression for tension: Am → Dm → Em → Am
    bass_notes = [110.0, 146.8, 164.8, 110.0]  # A2, D3, E3, A2
    bars = len(bass_notes)
    bar_dur = duration / bars

    for i in range(n):
        t = i / SAMPLE_RATE
        bar_idx = min(int(t / bar_dur), bars - 1)
        beat_pos = (t % beat_dur) / beat_dur  # 0-1 within beat
        bar_pos = (t % bar_dur) / bar_dur

        s = 0
        bass_freq = bass_notes[bar_idx]

        # Pulsing bass
        bass_env = math.exp(-beat_pos * 4) * 0.8
        s += math.sin(2 * math.pi * bass_freq * t) * 0.12 * bass_env
        s += math.sin(2 * math.pi * bass_freq * 2 * t) * 0.06 * bass_env

        # Rhythmic hi-hat pattern (8th notes)
        eighth_pos = (t % (beat_dur / 2)) / (beat_dur / 2)
        hat = random.uniform(-0.08, 0.08) * math.exp(-eighth_pos * 15)
        s += hat

        # Pad harmony
        for harm in [1.0, 1.5, 2.0]:  # root, fifth, octave
            s += math.sin(2 * math.pi * bass_freq * harm * t) * 0.03

        # Subtle tension build within each bar
        tension = 0.7 + 0.3 * bar_pos
        s *= tension

        # Loop crossfade
        fade = 1.0
        fade_time = 0.3
        if t < fade_time:
            fade = t / fade_time
        elif t > duration - fade_time:
            fade = (duration - t) / fade_time

        samples.append(s * fade * 0.7)
    return samples


if __name__ == "__main__":
    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    sfx_dir = os.path.join(base, "assets", "audio", "sfx")
    music_dir = os.path.join(base, "assets", "audio", "music")

    print("Generating SFX...")
    write_wav(os.path.join(sfx_dir, "sizzle.wav"), gen_sizzle())
    write_wav(os.path.join(sfx_dir, "bubble.wav"), gen_bubble())
    write_wav(os.path.join(sfx_dir, "boilover.wav"), gen_explosion())
    write_wav(os.path.join(sfx_dir, "ding.wav"), gen_ding())
    write_wav(os.path.join(sfx_dir, "whoosh.wav"), gen_whoosh())
    write_wav(os.path.join(sfx_dir, "draw.wav"), gen_draw())
    write_wav(os.path.join(sfx_dir, "flick.wav"), gen_flick())
    write_wav(os.path.join(sfx_dir, "splash.wav"), gen_splash())
    write_wav(os.path.join(sfx_dir, "combo.wav"), gen_combo())
    write_wav(os.path.join(sfx_dir, "combo_penalty.wav"), gen_combo_penalty())
    write_wav(os.path.join(sfx_dir, "serve.wav"), gen_serve())
    write_wav(os.path.join(sfx_dir, "second_chance.wav"), gen_second_chance())
    write_wav(os.path.join(sfx_dir, "sizzle_loop.wav"), gen_sizzle_loop())

    print("\nGenerating BGM...")
    write_wav(os.path.join(music_dir, "menu_bgm.wav"), gen_menu_bgm())
    write_wav(os.path.join(music_dir, "game_bgm.wav"), gen_game_bgm())

    print("\nDone! All audio files generated.")
