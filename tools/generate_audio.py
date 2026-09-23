#!/usr/bin/env python3
"""Synthesize all original audio for Shadowfetch Blackjack (SFX, music loops, ambience).

Everything here is generated from code: oscillators, FM, modal (resonant-partial)
synthesis, filtered noise and a synthetic convolution reverb.  No samples,
recordings or downloaded audio are used, so the output is fully owned by the
project.  The mood target is an intimate, luxurious private card room at night:
warm, understated, classy.

Usage (from the repository root)::

    python3 tools/generate_audio.py                  # render everything
    python3 tools/generate_audio.py --only chip      # only files whose name contains "chip"
    python3 tools/generate_audio.py --show-harmony   # also print chord voicings / bass lines
    python3 tools/generate_audio.py --no-verify      # skip the ffprobe / loop checks

Requirements: Python 3, numpy >= 2, scipy >= 1.15, and ffmpeg built with libvorbis.

Output
------
All files go to ``assets/audio/`` as Ogg Vorbis (``-c:a libvorbis -q:a 5``) at 44.1 kHz.
SFX are mono; music and ambience are stereo.  Encoding uses ffmpeg's ``bitexact``
flags and every random generator has a fixed seed, so re-running the script
produces byte-identical files.

* Cards   - ``card_slide_{1..3}``, ``card_flip_{1,2}``, ``card_place_{1,2}``, ``shuffle``
* Chips   - ``chip_click_{1..3}``, ``chip_stack_{1,2}``, ``chips_payout``
* UI      - ``ui_hover``, ``ui_click``, ``ui_back``
* Results - ``win``, ``blackjack``, ``lose``, ``bust``, ``push``, ``insurance``,
            ``achievement``, ``coach_good``, ``coach_bad``
* Music   - ``music_lounge`` (32-bar swing trio in F), ``music_menu`` (16-bar nocturne in Bb)
* Ambience- ``ambience_room`` (48 s room tone + distant murmur + rare clinks)

Synthesis approach
------------------
Card sounds
    Band-passed white noise whose spectrum is "roughened" by a slowly varying
    random gain (felt friction), with a raised-cosine attack and exponential
    decay; the slide crossfades between a low and a high band to imitate a
    swish, and ends in a soft "tap" (damped ~230 Hz sine + low-passed noise).
    Flips are a high-passed noise snap plus a small resonance and 2-4 decaying
    paper-flutter micro clicks.  Placing a card is a muffled damped low sine
    plus low-passed noise.  The riffle shuffle is ~57 card-edge clicks whose
    spacing shrinks from ~26 to ~9 ms (accelerando), a flapping-noise "bridge"
    whose flap rate falls from ~70 to ~25 Hz, and two squaring taps.
Chips
    Modal synthesis: 5 inharmonic partials (roughly 2.3-11 kHz) with 8-30 ms
    decays, a ~1.1 kHz "clay body" knock, a 1 ms high-passed noise transient and
    a small bounce.  Stacks and payouts are randomized sequences of clacks with
    varying spacing/pitch; the payout follows a rising-then-settling intensity
    and pitch curve over a faint sliding-chip hiss.
UI
    Tiny woodblock-like modal clicks (two or three damped sines + noise tick),
    peak-normalized well below the table SFX so they stay gentle.
Result stingers
    Mallet instruments built additively: a vibraphone (partials 1:4:10 with a
    slow motor tremolo), a celesta (near-harmonic partials) and a bell (0.5,
    1, 2.76, 5.40, 8.93 ratios), plus the same FM electric piano as the music,
    all through a short synthetic room.  Harmony is in F major to match the
    lounge loop: win = F6/9 arpeggio, blackjack = two-octave Fmaj9 arpeggio +
    shimmering sustained F6/9(maj7) chord + celesta sparkle, lose = soft C->A
    minor third, bust = felt thump + muted A/Eb tritone, push = open fifth
    G->D (no third, so neither happy nor sad), insurance = single A5 bell,
    achievement = pentatonic chime run to F6.
Music
    Every note is an event rendered into a long buffer that starts with a
    pre-roll and ends with a generous tail.  The electric piano is 2-operator
    FM (1:1 "body" pair with a velocity dependent index + a 14:1 "tine" pair
    with a 22 ms index decay) with a stereo auto-pan tremolo.  Chords use
    rootless voicings chosen by a small search that minimizes voice movement
    between chords.  The upright bass is a sine with decaying 2nd-4th
    harmonics, a flat-to-pitch settle, occasional slides from chromatic
    approach notes and a pluck noise; its walking line is generated from chord
    tones with chromatic / dominant approach notes into every chord change.
    The ride cymbal is 56 inharmonic partials + high noise wash + stick tick
    (a bank of 4 pre-rendered strokes), played "ding, ding-da-ding" with swing;
    brushes are a continuous circular sweep (band-passed noise with a 2-beat
    periodic swell) plus slaps on 2 & 4, a hi-hat foot chick and a feathered
    bass drum.  Timing and velocity are humanized.  Buses are balanced by
    measured loudness (BS.1770), summed, sent to a convolution reverb whose
    impulse response is exponentially decaying stereo noise (with a faster
    decaying high band and a few early reflections).
    The menu nocturne reuses the same electric piano (rolled chords, a sparse
    hand-written melody), adds a three-voice detuned additive pad and soft
    root/fifth bass notes, and only a very quiet brush swell every two bars.
Ambience
    Brown + pink noise room tone, nine "voices" of noise shaped by two sets of
    formant-like band-passes (300-3000 Hz) that slowly morph, each with slow
    random syllable/phrase amplitude modulation, then low-passed and drowned in
    a long reverb so no speech is implied; plus seven faint distant chip / glass
    clinks at random times.

Seamless loops
    The music is an exact whole number of bars (the tempo is chosen so a beat is
    an integer number of samples: 30000 samples = 88.2 BPM for the lounge,
    47250 samples = 56 BPM for the menu).  After rendering, the buffer is
    *folded*: every sample at loop position p + k*N (k = -1, 1, 2, ...) is added
    to position p.  This is the exact steady state of the loop playing forever,
    so the reverb and ringing notes of the last bars (and humanized notes that
    land slightly before bar 1) continue across the loop point with no seam.
    Continuous noise layers (brush sweep, ambience beds) are rendered N + F
    samples long and their overrun is equal-power crossfaded into the head
    (``loop_crossfade``); ambience reverb and clinks are applied circularly, so
    the ambience is exactly periodic too.  All processing with memory is done
    before folding; only gain and a memoryless soft limiter happen after it.

Levels
    SFX are trimmed, faded and peak-normalized per sound (card/chip transients
    -3..-5 dBFS, result stingers -3.5..-9, coach cues -13, UI clicks -12/-13 and
    the hover tick -21 dBFS).  Both music loops are normalized to -20 LUFS
    (BS.1770 integrated, RMS about -22 dBFS) with peaks <= -3 dBFS guaranteed by
    a soft limiter; the ambience to -32 dBFS RMS.

Godot notes
    Import the music and ambience .ogg files with looping enabled (Import dock:
    Loop = on, Loop Offset = 0) or set ``AudioStreamOggVorbis.loop = true`` in
    code.  Short files are muxed with 10 ms Ogg pages because ffmpeg writes an
    imprecise end granule when a stream fits in a single page; with small pages
    every file decodes to exactly the rendered sample count (checked below).
"""
from __future__ import annotations

import argparse
import itertools
import json
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from scipy import signal

SR = 44100
TAU = 2.0 * np.pi
ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "audio"
SWING = 0.64  # swung off-beat position inside a beat (0.5 = straight, 0.667 = triplet)


# =============================================================================
# Generic helpers: units, envelopes, filters, noise, mixing
# =============================================================================

def n_of(seconds: float) -> int:
    return int(round(seconds * SR))


def t_axis(n: int) -> np.ndarray:
    return np.arange(n) / SR


def db_to_gain(db: float) -> float:
    return float(10.0 ** (db / 20.0))


def gain_to_db(g: float) -> float:
    return float(20.0 * np.log10(max(float(g), 1e-12)))


def peak(x) -> float:
    return float(np.max(np.abs(x))) if np.size(x) else 0.0


def rms(x) -> float:
    return float(np.sqrt(np.mean(np.square(x)))) if np.size(x) else 0.0


def midi_hz(m):
    return 440.0 * 2.0 ** ((np.asarray(m, dtype=float) - 69.0) / 12.0)


NOTE_NAMES = ("C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B")
PC = {name: i for i, name in enumerate(NOTE_NAMES)}


def note_name(m: int) -> str:
    return f"{NOTE_NAMES[m % 12]}{m // 12 - 1}"


def ramp_in(n: int, attack: float) -> np.ndarray:
    """Raised-cosine rise 0 -> 1 over `attack` seconds, then 1."""
    x = np.clip(t_axis(n) / max(attack, 1.0 / SR), 0.0, 1.0)
    return 0.5 - 0.5 * np.cos(np.pi * x)


def env_ad(n: int, attack: float, decay: float) -> np.ndarray:
    """Raised-cosine attack then exponential decay with time constant `decay` (s)."""
    t = t_axis(n)
    return ramp_in(n, attack) * np.exp(-np.maximum(t - attack, 0.0) / decay)


def env_release(n: int, start: float, release: float) -> np.ndarray:
    """1 until `start` s, raised-cosine fall to 0 over `release` s, then 0."""
    x = np.clip((t_axis(n) - start) / max(release, 1.0 / SR), 0.0, 1.0)
    return 0.5 + 0.5 * np.cos(np.pi * x)


def fade(x: np.ndarray, fade_in: float = 0.0, fade_out: float = 0.0) -> np.ndarray:
    """Raised-cosine fades; the first/last sample become exactly zero."""
    x = np.array(x, dtype=float, copy=True)
    n = x.shape[-1]
    if fade_in > 0:
        k = min(n, max(2, n_of(fade_in)))
        x[..., :k] *= 0.5 - 0.5 * np.cos(np.pi * np.arange(k) / k)
    if fade_out > 0:
        k = min(n, max(2, n_of(fade_out)))
        x[..., n - k:] *= 0.5 + 0.5 * np.cos(np.pi * (np.arange(k) + 1) / k)
    return x


def filt(x: np.ndarray, btype: str, freq, order: int = 2) -> np.ndarray:
    """Butterworth filter (scipy sosfilt) along the last axis."""
    sos = signal.butter(order, freq, btype=btype, fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=-1)


def unit(x: np.ndarray) -> np.ndarray:
    """Scale to unit peak (safe for silence)."""
    p = peak(x)
    return x / p if p > 0 else x


def colored_noise(rng: np.random.Generator, n: int, exponent: float) -> np.ndarray:
    """Noise with power spectrum ~ 1/f**exponent (1 = pink, 2 = brown), unit std."""
    spec = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    f[0] = f[1]
    spec *= f ** (-exponent / 2.0)
    spec[0] = 0.0
    x = np.fft.irfft(spec, n)
    return x / (np.std(x) + 1e-12)


def smooth_random(rng: np.random.Generator, n: int, cutoff: float, rate: float = 200.0) -> np.ndarray:
    """Slow random control signal (unit std) low-passed at `cutoff` Hz.

    Generated at a low control rate (with a filter warm-up) and linearly
    interpolated to audio rate, which keeps very low cutoffs numerically sane.
    """
    warm = int(rate * 4.0 / cutoff)
    nc = int(np.ceil(n * rate / SR)) + 4
    sos = signal.butter(2, cutoff, btype="lowpass", fs=rate, output="sos")
    c = signal.sosfilt(sos, rng.standard_normal(nc + warm))[warm:]
    c = (c - c.mean()) / (c.std() + 1e-12)
    return np.interp(np.arange(n) * rate / SR, np.arange(nc), c)


def as_stereo(x: np.ndarray) -> np.ndarray:
    return np.stack([x, x]) if x.ndim == 1 else x


def pan(sig: np.ndarray, p: float) -> np.ndarray:
    """Constant-power pan of a mono signal; p in [-1, 1], centre keeps unity per channel."""
    a = (float(np.clip(p, -1, 1)) + 1.0) * np.pi / 4.0
    return np.stack([np.cos(a) * sig, np.sin(a) * sig]) * np.sqrt(2.0)


def add_into(buf: np.ndarray, start: int, sig: np.ndarray) -> None:
    """Mix `sig` (mono or stereo) into `buf` at sample `start`, clipping to the buffer."""
    n, length = buf.shape[-1], sig.shape[-1]
    s0, s1 = max(start, 0), min(start + length, n)
    if s1 <= s0:
        return
    seg = sig[..., s0 - start:s1 - start]
    if buf.ndim == 2 and seg.ndim == 1:
        buf[:, s0:s1] += seg
    else:
        buf[..., s0:s1] += seg


def add_circular(buf: np.ndarray, start: int, sig: np.ndarray) -> None:
    """Mix `sig` into a loop buffer, wrapping around the end (sig shorter than buf)."""
    idx = (start + np.arange(sig.shape[-1])) % buf.shape[-1]
    if buf.ndim == 2 and sig.ndim == 1:
        buf[:, idx] += sig
    else:
        buf[..., idx] += sig


def modal(freqs, amps, decays, n: int, phases=None, attack: float = 0.0002) -> np.ndarray:
    """Sum of exponentially decaying sines (modal / resonant-partial synthesis)."""
    t = t_axis(n)
    y = np.zeros(n)
    for i, (f, a, d) in enumerate(zip(freqs, amps, decays)):
        if f >= 0.45 * SR:
            continue
        ph = 0.0 if phases is None else phases[i]
        y += a * np.exp(-t / d) * np.sin(TAU * f * t + ph)
    return y * ramp_in(n, attack)


# =============================================================================
# Reverb, loudness, normalization, loop helpers
# =============================================================================

def make_ir(rt60: float, seed: int, predelay: float = 0.012, damp_hz: float = 4500.0,
            early: int = 6, length: float | None = None) -> np.ndarray:
    """Synthetic stereo impulse response: exponentially decaying noise.

    Two independent noise channels (for width), split into a low band that
    decays with `rt60` and a high band that decays ~2.5x faster (air/furnishing
    damping), a 25 ms diffuse build-up, a few sparse early reflections and a
    pre-delay.  Normalized to unit energy per channel.
    """
    rng = np.random.default_rng(seed)
    length = length if length else min(rt60 * 1.1, 3.5)
    n = n_of(length)
    t = t_axis(n)
    ir = np.zeros((2, n))
    for ch in range(2):
        w = rng.standard_normal(n)
        low = filt(w, "lowpass", damp_hz, 2)
        high = filt(w, "highpass", damp_hz, 2)
        diffuse = low * 10 ** (-3 * t / rt60) + 0.5 * high * 10 ** (-3 * t / (0.4 * rt60))
        diffuse *= np.clip(t / 0.025, 0.1, 1.0)
        for _ in range(early):
            k = n_of(rng.uniform(0.003, 0.045))
            diffuse[k] += rng.choice([-1.0, 1.0]) * rng.uniform(2.0, 5.0) * 10 ** (-3 * t[k] / rt60)
        ir[ch] = fade(diffuse, 0.0, length * 0.1)
    ir = np.pad(ir, ((0, 0), (n_of(predelay), 0)))
    return ir / np.sqrt(np.mean(np.sum(ir ** 2, axis=1)))


def reverb_wet(x: np.ndarray, ir: np.ndarray, circular: bool = False) -> np.ndarray:
    """Wet-only stereo reverb.  Linear (output grows by len(ir)-1) or circular (same length)."""
    xs = as_stereo(x)
    if circular:
        n = xs.shape[1]
        assert ir.shape[1] <= n
        spec = np.fft.rfft(xs, n=n, axis=1) * np.fft.rfft(ir, n=n, axis=1)
        return np.fft.irfft(spec, n=n, axis=1)
    return np.stack([signal.oaconvolve(xs[c], ir[c]) for c in range(2)])


def reverb_mono(x: np.ndarray, rt60: float, wet: float, seed: int,
                predelay: float = 0.01, damp_hz: float = 5000.0) -> np.ndarray:
    """Mono dry + wet reverb for SFX (uses one channel of the stereo IR)."""
    ir = make_ir(rt60, seed, predelay, damp_hz)[0]
    out = wet * signal.oaconvolve(x, ir)
    out[:len(x)] += x
    return out


def _biquad_k_weighting():
    """ITU-R BS.1770 K-weighting pre-filter coefficients for SR (formula form)."""
    f0, g, q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    k = np.tan(np.pi * f0 / SR)
    vh = 10.0 ** (g / 20.0)
    vb = vh ** 0.4996667741545416
    a0 = 1 + k / q + k * k
    b1 = [(vh + vb * k / q + k * k) / a0, 2 * (k * k - vh) / a0, (vh - vb * k / q + k * k) / a0]
    a1 = [1.0, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0]
    f0, q = 38.13547087602444, 0.5003270373238773
    k = np.tan(np.pi * f0 / SR)
    a0 = 1 + k / q + k * k
    b2 = [1.0, -2.0, 1.0]
    a2 = [1.0, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0]
    return b1, a1, b2, a2


_KW = _biquad_k_weighting()


def lufs(x: np.ndarray) -> float:
    """Integrated loudness (BS.1770-4: K-weighting, 400 ms blocks, abs + relative gates)."""
    xs = np.atleast_2d(x)
    b1, a1, b2, a2 = _KW
    y = signal.lfilter(b2, a2, signal.lfilter(b1, a1, xs, axis=-1), axis=-1)
    sq = np.sum(y ** 2, axis=0)
    block, hop = n_of(0.4), n_of(0.1)
    if len(sq) < block:
        return -0.691 + 10 * np.log10(np.mean(sq) + 1e-20)
    cs = np.concatenate([[0.0], np.cumsum(sq)])
    starts = np.arange(0, len(sq) - block + 1, hop)
    z = (cs[starts + block] - cs[starts]) / block
    z = z[-0.691 + 10 * np.log10(z + 1e-20) > -70]
    if z.size == 0:
        return float("-inf")
    rel = -0.691 + 10 * np.log10(np.mean(z)) - 10
    z = z[-0.691 + 10 * np.log10(z) > rel]
    return float(-0.691 + 10 * np.log10(np.mean(z)))


def set_loudness(x: np.ndarray, target_lufs: float) -> np.ndarray:
    return x * db_to_gain(target_lufs - lufs(x))


def set_rms(x: np.ndarray, target_db: float) -> np.ndarray:
    return x * db_to_gain(target_db - gain_to_db(rms(x)))


def normalize_peak(x: np.ndarray, target_db: float) -> np.ndarray:
    return x * (db_to_gain(target_db) / (peak(x) + 1e-12))


def soft_limit(x: np.ndarray, ceiling_db: float = -3.0, knee_db: float = 3.0) -> np.ndarray:
    """Memoryless soft-knee limiter (tanh above the knee); never exceeds the ceiling.

    Because it has no memory it is safe to apply after loop folding.
    """
    c, k = db_to_gain(ceiling_db), db_to_gain(ceiling_db - knee_db)
    a = np.abs(x)
    over = a > k
    y = np.array(x, copy=True)
    y[over] = np.sign(x[over]) * (k + (c - k) * np.tanh((a[over] - k) / (c - k)))
    return y


def trim_silence(x: np.ndarray, thresh_db: float = -60.0, pad: float = 0.002) -> np.ndarray:
    a = np.abs(x) if x.ndim == 1 else np.max(np.abs(x), axis=0)
    idx = np.nonzero(a > a.max() * db_to_gain(thresh_db))[0]
    s = max(0, idx[0] - n_of(pad))
    e = min(a.size, idx[-1] + 1 + n_of(pad))
    return x[..., s:e]


def finish_sfx(x: np.ndarray, peak_db: float, fade_out: float = 0.015,
               max_len: float | None = None, thresh_db: float = -60.0) -> np.ndarray:
    """DC-block, trim silence, short click-free fades, peak-normalize."""
    x = filt(x, "highpass", 25.0, 2)
    x = trim_silence(x, thresh_db)
    if max_len is not None:
        x = x[..., :n_of(max_len)]
    x = fade(x, 0.0005, fade_out)
    return normalize_peak(x, peak_db).astype(np.float32)


def loop_fold(buf: np.ndarray, n_loop: int, preroll: int) -> np.ndarray:
    """Fold a rendered buffer into one seamless loop period.

    `buf[:, preroll]` is loop time 0.  Every sample at loop time p + k*n_loop
    (for any integer k, including the pre-roll at k = -1 and the tail at
    k >= 1) is summed into position p: the exact steady state of the loop
    repeating forever, so reverb tails and ringing notes wrap into the start.
    """
    b = np.atleast_2d(buf)
    front = (-preroll) % n_loop
    b = np.pad(b, ((0, 0), (front, 0)))
    b = np.pad(b, ((0, 0), (0, (-b.shape[1]) % n_loop)))
    return b.reshape(b.shape[0], -1, n_loop).sum(axis=1)


def loop_crossfade(x: np.ndarray, n_loop: int, n_fade: int) -> np.ndarray:
    """Make a continuous signal loop: equal-power crossfade its overrun into the head.

    `x` must hold at least n_loop + n_fade samples.  The result y has y[-1]
    followed by y[0] == x[n_loop - 1] followed by ~x[n_loop], i.e. continuous.
    (Equal power is right for uncorrelated material such as noise beds.)
    """
    y = np.array(x[..., :n_loop], copy=True)
    ph = (np.arange(n_fade) + 0.5) / n_fade * (np.pi / 2)
    y[..., :n_fade] = x[..., :n_fade] * np.sin(ph) + x[..., n_loop:n_loop + n_fade] * np.cos(ph)
    return y


def spectral_centroid(x: np.ndarray) -> float:
    m = x if x.ndim == 1 else x.mean(axis=0)
    spec = np.abs(np.fft.rfft(m * np.hanning(m.size)))
    f = np.fft.rfftfreq(m.size, 1.0 / SR)
    return float(np.sum(f * spec) / (np.sum(spec) + 1e-12))


# =============================================================================
# Instruments
# =============================================================================

def rhodes_note(midi: float, dur: float, vel: float, rng: np.random.Generator,
                bright: float = 1.0, release: float = 0.28) -> np.ndarray:
    """Electric piano (Rhodes-like) note via 2-operator FM pairs.

    * body: carrier:modulator 1:1, index = bark (velocity dependent, decays in
      ~0.25 s, the "bark") + a steady index of ~0.45 for a mellow sustain;
    * tine: carrier modulated at 14x (7x/3x for high notes to avoid aliasing)
      with a 22 ms index decay - the bell-ish attack "ping";
    * amplitude: fast + slow exponential decay (slower for low notes),
      2-6 ms attack, raised-cosine release after `dur`.
    """
    f = float(midi_hz(midi)) * 2.0 ** (rng.normal(0.0, 1.2) / 1200.0)
    n = n_of(dur + release + 0.02)
    t = t_axis(n)
    ph = TAU * f * t
    i_body = bright * (0.5 + 1.8 * vel ** 1.2) * np.exp(-t / 0.25) + 0.45 * bright
    body = np.sin(ph + i_body * np.sin(ph))
    ratio = 14.0 if 15 * f < 17000 else (7.0 if 8 * f < 17000 else 3.0)
    i_tine = bright * 1.6 * vel * min(1.0, np.sqrt(330.0 / f)) * np.exp(-t / 0.022)
    tine = np.sin(ph + i_tine * np.sin(ratio * ph))
    tau = 1.8 * (261.6 / f) ** 0.55
    amp = 0.3 * np.exp(-t / 0.15) + 0.7 * np.exp(-t / tau)
    env = amp * ramp_in(n, 0.002 + 0.004 * (1.0 - vel)) * env_release(n, dur, release)
    return (0.75 * body + 0.25 * tine) * env * vel ** 1.4


def bass_note(midi: float, dur: float, vel: float, rng: np.random.Generator,
              slide_from: float | None = None, bright: float = 1.0,
              sustain: float = 1.1, release: float = 0.07) -> np.ndarray:
    """Upright-bass-like pluck: sine + decaying 2nd/3rd/4th harmonics.

    The pitch settles from ~14 cents flat (string stretch on the pluck) and can
    slide in from `slide_from` (a MIDI note) over ~35 ms.  A short low-passed
    noise burst gives the finger "thump".
    """
    f = float(midi_hz(midi))
    n = n_of(dur + release + 0.01)
    t = t_axis(n)
    cents = -14.0 * np.exp(-t / 0.03) + rng.normal(0.0, 2.0)
    if slide_from is not None:
        cents = cents + (slide_from - midi) * 100.0 * np.exp(-t / 0.035)
    ph = TAU * np.cumsum(f * 2.0 ** (cents / 1200.0)) / SR
    y = (np.sin(ph)
         + bright * 0.42 * np.exp(-t / 0.30) * np.sin(2 * ph)
         + bright * 0.20 * np.exp(-t / 0.14) * np.sin(3 * ph)
         + bright * 0.08 * np.exp(-t / 0.07) * np.sin(4 * ph))
    amp = 0.35 * np.exp(-t / 0.08) + 0.65 * np.exp(-t / sustain)
    env = amp * ramp_in(n, 0.005) * env_release(n, dur, release)
    pluck = unit(filt(rng.standard_normal(n), "lowpass", 900.0)) * np.exp(-t / 0.012)
    return vel * (y * env + 0.12 * bright * pluck * ramp_in(n, 0.001))


def pad_note(midi: float, dur: float, vel: float, rng: np.random.Generator,
             attack: float = 1.0, release: float = 1.8, harmonics: int = 7) -> np.ndarray:
    """Warm stereo pad: three detuned additive saw-ish voices (L / C / R), soft rolloff."""
    f = float(midi_hz(midi))
    n = n_of(dur + release)
    t = t_axis(n)
    out = np.zeros((2, n))
    for det, p in ((-7.0, -0.6), (0.0, 0.0), (7.0, 0.6)):
        fv = f * 2.0 ** ((det + rng.normal(0.0, 1.5)) / 1200.0)
        y = np.zeros(n)
        for h in range(1, harmonics + 1):
            if fv * h > 9000:
                break
            y += (1.0 / h) * np.exp(-(h - 1) * 0.45) * np.sin(TAU * fv * h * t + rng.uniform(0, TAU))
        out += pan(y, p)
    wobble = 1.0 + 0.06 * np.sin(TAU * rng.uniform(0.15, 0.3) * t + rng.uniform(0, TAU))
    env = ramp_in(n, attack) * env_release(n, dur, release) * wobble
    return out * env * vel / 3.0


MALLETS = {
    # ratio, relative amplitude, relative decay
    "vibe": ((1.0, 1.0, 1.0), (4.0, 0.28, 0.16), (10.0, 0.05, 0.05)),
    "celesta": ((1.0, 1.0, 1.0), (2.0, 0.22, 0.45), (3.0, 0.07, 0.25), (5.2, 0.04, 0.1)),
    "bell": ((0.5, 0.12, 1.3), (1.0, 1.0, 1.0), (2.76, 0.38, 0.42), (5.40, 0.14, 0.2), (8.93, 0.06, 0.1)),
}


def mallet_note(midi: float, vel: float, length: float, rng: np.random.Generator,
                kind: str = "vibe", motor: float = 0.0, decay_scale: float = 1.0) -> np.ndarray:
    """Additive struck-bar instrument (vibraphone / celesta / bell) with a soft mallet."""
    f = float(midi_hz(midi))
    n = n_of(length)
    t = t_axis(n)
    base = {"vibe": 1.4 * (440 / f) ** 0.35, "celesta": 0.9 * (880 / f) ** 0.4,
            "bell": 0.9 * (880 / f) ** 0.3}[kind] * decay_scale
    y = np.zeros(n)
    for ratio, amp, dscale in MALLETS[kind]:
        fr = f * ratio
        if fr > 17000:
            continue
        a = amp * (vel ** 0.5 if ratio > 1.5 else 1.0)
        y += a * np.exp(-t / (base * dscale)) * np.sin(TAU * fr * t + rng.uniform(0, 0.3))
    if motor:
        y *= 1.0 - motor * (0.5 - 0.5 * np.cos(TAU * 5.2 * t))
    thump = unit(filt(rng.standard_normal(n), "lowpass", 1800.0)) * np.exp(-t / 0.004)
    return vel * (y * ramp_in(n, 0.004) + 0.08 * vel * thump)


def chip_clack(rng: np.random.Generator, f0: float | None = None, bounce: bool = True) -> np.ndarray:
    """One clay chip hitting another: inharmonic modes + clay knock + impact noise."""
    n = n_of(0.14)
    t = t_axis(n)
    f0 = f0 if f0 else rng.uniform(2300.0, 3300.0)
    ratios = np.array([1.0, 1.52, 2.07, 2.71, 3.36]) * np.r_[1.0, 1.0 + rng.normal(0, 0.03, 4)]
    amps = np.array([1.0, 0.7, 0.45, 0.25, 0.12]) * rng.uniform(0.6, 1.2, 5)
    decays = np.array([0.030, 0.022, 0.016, 0.011, 0.008]) * rng.uniform(0.8, 1.25, 5)
    y = modal(f0 * ratios, amps, decays, n, rng.uniform(0, TAU, 5))
    y += 0.5 * modal([rng.uniform(900.0, 1400.0)], [1.0], [0.010], n)
    y += 0.6 * unit(filt(rng.standard_normal(n), "highpass", 2500.0)) * np.exp(-t / 0.0012)
    if bounce:
        d = n_of(rng.uniform(0.006, 0.014))
        y[d:] += rng.uniform(0.2, 0.4) * y[:n - d]
    return y


def glass_clink(rng: np.random.Generator) -> np.ndarray:
    """Two glasses touching: a few long-ringing inharmonic modes plus a tick."""
    n = n_of(0.9)
    t = t_axis(n)
    f0 = rng.uniform(1700.0, 2600.0)
    y = modal(f0 * np.array([1.0, 2.32, 4.25, 6.63]), [1.0, 0.5, 0.25, 0.1],
              [0.45, 0.25, 0.12, 0.06], n, rng.uniform(0, TAU, 4))
    y += 0.3 * unit(filt(rng.standard_normal(n), "highpass", 3000.0)) * np.exp(-t / 0.001)
    return y


# =============================================================================
# Harmony: chord charts, voicing search, walking bass
# =============================================================================

# Rootless voicing tones (intervals above the root) per chord quality.
VOICING = {
    "maj9": (4, 7, 11, 2),   # 3 5 7 9
    "69": (4, 9, 2, 7),      # 3 6 9 5
    "m9": (3, 7, 10, 2),     # b3 5 b7 9
    "m7": (3, 7, 10, 5),     # b3 5 b7 11 (iii chord: no natural 9)
    "m6": (3, 7, 9, 2),      # b3 5 6 9
    "13": (4, 9, 10, 2),     # 3 13 b7 9
    "7b9": (4, 7, 10, 1),    # 3 5 b7 b9
    "9": (4, 7, 10, 2),      # 3 5 b7 9
    "9sus": (5, 10, 2, 7),   # 4 b7 9 5
}
# Walking-bass tones: (third, fifth, sixth-or-seventh, second)
BASS_TONES = {
    "maj9": (4, 7, 9, 2), "69": (4, 7, 9, 2), "m9": (3, 7, 10, 2), "m7": (3, 7, 10, 5),
    "m6": (3, 7, 9, 2), "13": (4, 7, 10, 2), "7b9": (4, 7, 10, 1), "9": (4, 7, 10, 2),
    "9sus": (5, 7, 10, 2),
}


@dataclass
class Seg:
    start: float  # beats from loop start
    beats: float
    root: int     # pitch class
    q: str        # quality key into VOICING
    bar: int

    @property
    def name(self) -> str:
        return f"{NOTE_NAMES[self.root]}{self.q}"


def chart_segments(chart) -> list[Seg]:
    segs, beat = [], 0.0
    for bar_i, bar in enumerate(chart):
        assert sum(b for _, _, b in bar) == 4, f"bar {bar_i + 1} is not 4 beats"
        for root, q, b in bar:
            segs.append(Seg(beat, b, PC[root], q, bar_i))
            beat += b
    return segs


def voice_chord(root: int, q: str, prev: list[int] | None, lo: int, hi: int,
                center: float, max_span: int = 15) -> list[int]:
    """Choose octaves for the chord tones: minimal total voice movement from `prev`,
    a pull toward `center`, and no minor-ninth rubs except in b9 chords."""
    options = [[m for m in range(lo, hi + 1) if m % 12 == (root + iv) % 12] for iv in VOICING[q]]
    best, best_cost = None, None
    for combo in itertools.product(*options):
        v = sorted(combo)
        if len(set(v)) < len(v) or v[-1] - v[0] > max_span:
            continue
        cost = 0.6 * abs(float(np.mean(v)) - center)
        if prev:
            cost += sum(abs(a - b) for a, b in zip(v, prev))
        if "b9" not in q:
            cost += 6.0 * sum(1 for a, b in itertools.combinations(v, 2) if b - a == 13)
        if best_cost is None or cost < best_cost:
            best, best_cost = v, cost
    assert best is not None, f"no voicing for {q}"
    return best


def place_note(pc: int, prev: int, lo: int, hi: int, home: float) -> int:
    """Octave of pitch class `pc` closest to `prev`, gently biased toward `home`."""
    cands = [m for m in range(lo, hi + 1) if m % 12 == pc % 12]
    return min(cands, key=lambda m: abs(m - prev) + 0.15 * abs(m - home))


def walking_bass(segs: list[Seg], rng: np.random.Generator, lo: int = 29, hi: int = 50,
                 start: int = 41, home: float = 38.0):
    """Quarter-note walking line: chord tones on strong beats and a chromatic,
    whole-step or dominant approach note into every chord change (the last beat
    approaches the first chord, so the line itself loops).  A chord that
    repeats the previous root starts on its fifth instead; approach notes aim
    at whatever note the next chord really starts on, and no note is repeated.
    Returns a list of (beat, midi, velocity, slide_from)."""
    templates4 = (("R", "T", "F", "A"), ("R", "N", "T", "A"), ("R", "F", "S", "A"),
                  ("R", "O", "F", "A"), ("R", "F", "T", "A"), ("R", "T", "N", "A"))
    approaches, weights = (-1, 1, 7, -2), (0.35, 0.3, 0.25, 0.1)

    def first_pc(i: int) -> int:
        s = segs[i % len(segs)]
        same_root = segs[(i - 1) % len(segs)].root == s.root
        return (s.root + (BASS_TONES[s.q][1] if same_root else 0)) % 12

    notes, prev, slide_next = [], start, False
    for i, s in enumerate(segs):
        third, fifth, sixth, second = BASS_TONES[s.q]
        target = first_pc(i + 1)
        if s.beats == 4:
            plan = templates4[rng.integers(len(templates4))]
        else:
            plan = ("R", "A") if rng.random() < 0.8 else ("R", "F")
        for k, step in enumerate(plan):
            slide = None
            if step == "R":
                pc = first_pc(i)
                if slide_next:
                    slide = prev          # slide in from the chromatic approach note
                slide_next = False
            elif step == "O":             # jump to the other octave of the root
                m = prev + 12 if prev + 12 <= hi else prev - 12
                notes.append((s.start + k, m, rng.uniform(0.74, 0.86), None))
                prev = m
                continue
            elif step == "A":             # approach note into the next chord
                for o in rng.choice(len(approaches), size=len(approaches), replace=False, p=weights):
                    pc = (target + approaches[o]) % 12
                    if pc != prev % 12:
                        break
                slide_next = approaches[o] in (-1, 1) and rng.random() < 0.3
            else:
                pc = s.root + {"T": third, "F": fifth, "S": sixth, "N": second}[step]
                if pc % 12 == prev % 12:
                    pc = s.root + (third if step == "F" else fifth)
                if k == len(plan) - 1 and pc % 12 == target:
                    pc = target - 1       # would repeat into the next chord: lead in chromatically
            m = place_note(pc % 12, prev, lo, hi, home)
            if slide is not None and abs(slide - m) != 1:
                slide = None              # only slide across a half step
            vel = rng.uniform(0.8, 0.9) if k % 2 == 0 else rng.uniform(0.74, 0.84)
            notes.append((s.start + k, m, vel, slide))
            prev = m
    return notes


def print_harmony(title: str, segs: list[Seg], voicings: list[list[int]], bass) -> None:
    print(f"\n{title}")
    by_beat = {round(b, 3): m for b, m, _, _ in bass}
    for s, v in zip(segs, voicings):
        bline = [note_name(by_beat[round(s.start + k, 3)]) for k in range(int(s.beats))
                 if round(s.start + k, 3) in by_beat]
        freqs = " ".join(f"{note_name(m)}({midi_hz(m):.1f})" for m in v)
        print(f"  bar {s.bar + 1:2d} beat {s.start % 4 + 1:.0f}  {s.name:8s} "
              f"voicing {freqs:52s} bass {' '.join(bline)}")


# =============================================================================
# SFX
# =============================================================================

def sfx_card_slide(seed: int, dur: float, center: float, tap_gain: float, sweep_up: bool) -> np.ndarray:
    rng = np.random.default_rng(seed)
    pre = 4096
    n = n_of(dur)
    t = t_axis(n)
    rough = filt(rng.standard_normal(n + pre), "lowpass", 180.0)
    src = rng.standard_normal(n + pre) * (1.0 + 0.35 * rough / np.std(rough))
    hi = filt(src, "bandpass", [center * 0.7, min(center * 2.2, 16000.0)])[pre:]
    lo = filt(src, "bandpass", [center * 0.25, center * 0.7])[pre:]
    hi, lo = hi / np.std(hi), lo / np.std(lo)
    s = t / dur
    w = s if sweep_up else 1.0 - s
    swish = (0.6 + 0.4 * w) * hi + 0.6 * (0.9 - 0.5 * w) * lo
    env = np.clip(t / 0.006, 0.0, 1.0) ** 1.5 * np.exp(-np.maximum(t - 0.006, 0.0) / (dur * 0.55))
    env *= (1.0 - s) ** 0.8
    y = np.zeros(n + n_of(0.06))
    y[:n] += swish * env
    tn = n_of(0.05)
    tt = t_axis(tn)
    tap = (np.sin(TAU * 230.0 * rng.uniform(0.85, 1.15) * tt) * np.exp(-tt / 0.010)
           + 0.6 * unit(filt(rng.standard_normal(tn), "lowpass", 1500.0)) * np.exp(-tt / 0.004))
    add_into(y, n_of(dur - rng.uniform(0.02, 0.035)), tap_gain * tap * ramp_in(tn, 0.0008))
    return filt(y, "lowpass", 9000.0)


def sfx_card_flip(seed: int, snap_f: float, flutters: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    n = n_of(0.14)
    y = np.zeros(n)
    an = n_of(0.03)
    air = filt(rng.standard_normal(an), "bandpass", [900.0, 3500.0])
    y[:an] += 0.18 * unit(air) * np.sin(np.pi * np.arange(an) / an) ** 2
    sn = n_of(0.05)
    st = t_axis(sn)
    snap = (unit(filt(filt(rng.standard_normal(sn), "highpass", 1800.0), "lowpass", 9000.0)) * np.exp(-st / 0.0035)
            + 0.5 * np.sin(TAU * snap_f * st) * np.exp(-st / 0.006))
    t0 = 0.022
    add_into(y, n_of(t0), snap * ramp_in(sn, 0.0003))
    rn = n_of(0.1)
    rustle = unit(filt(rng.standard_normal(rn), "bandpass", [1000.0, 4500.0])) * env_ad(rn, 0.003, 0.022)
    add_into(y, n_of(t0), 0.1 * rustle)
    for k, dt in enumerate((0.014, 0.03, 0.05, 0.075)[:flutters]):
        cn = n_of(0.01)
        click = unit(filt(rng.standard_normal(cn), "bandpass", [1500.0, 6000.0])) * np.exp(-t_axis(cn) / 0.0012)
        add_into(y, n_of(t0 + dt + rng.uniform(-0.002, 0.002)), 0.3 * 0.65 ** k * click)
    return y


def sfx_card_place(seed: int, f_body: float) -> np.ndarray:
    rng = np.random.default_rng(seed)
    n = n_of(0.1)
    t = t_axis(n)
    ph = TAU * np.cumsum(f_body * (1.0 + 0.25 * np.exp(-t / 0.01))) / SR
    body = np.sin(ph) * np.exp(-t / 0.016)
    thud = unit(filt(rng.standard_normal(n), "lowpass", 700.0)) * np.exp(-t / 0.008)
    slap = unit(filt(rng.standard_normal(n), "bandpass", [1000.0, 3000.0])) * np.exp(-t / 0.003)
    y = (0.6 * body + 0.5 * thud + 0.12 * slap) * ramp_in(n, 0.0015)
    return filt(y, "lowpass", 2500.0)


def sfx_chip_click(seed: int, f0: float) -> np.ndarray:
    rng = np.random.default_rng(seed)
    return chip_clack(rng, f0)


def sfx_chip_stack(seed: int, count: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    gaps = rng.uniform(0.035, 0.085, count - 1)
    gaps *= min(1.0, 0.31 / gaps.sum())
    times = np.r_[0.004, 0.004 + np.cumsum(gaps)]
    y = np.zeros(n_of(times[-1] + 0.16))
    for k, tt in enumerate(times):
        amp = 1.0 if k == 0 else rng.uniform(0.45, 0.85) * (1.0 - 0.05 * k)
        add_into(y, n_of(tt), amp * chip_clack(rng, rng.uniform(2300.0, 3400.0), bounce=rng.random() < 0.6))
    return y


def sfx_chips_payout(seed: int = 5100, count: int = 14) -> np.ndarray:
    rng = np.random.default_rng(seed)
    times = np.sort(rng.beta(1.6, 2.2, count))
    times = 0.005 + 0.72 * (times - times[0]) / (times[-1] - times[0])  # denser early-middle
    y = np.zeros(n_of(1.05))
    for tt in times:
        intensity = 0.5 + 0.5 * np.exp(-((tt - 0.3) / 0.22) ** 2)
        pitch = 1.0 + 0.12 * min(tt / 0.35, 1.0) - 0.08 * max(tt - 0.35, 0.0)
        amp = intensity * rng.uniform(0.8, 1.1)
        add_into(y, n_of(tt), amp * chip_clack(rng, rng.uniform(2300.0, 3000.0) * pitch))
        if rng.random() < 0.3:  # two chips landing together
            add_into(y, n_of(tt + rng.uniform(0.003, 0.007)),
                     0.6 * amp * chip_clack(rng, rng.uniform(2400.0, 3300.0) * pitch, bounce=False))
    t = t_axis(y.size)
    hiss = unit(filt(rng.standard_normal(y.size), "bandpass", [2000.0, 6000.0]))
    y += 0.05 * hiss * np.exp(-((t - 0.3) / 0.25) ** 2)
    return y


def sfx_shuffle(seed: int = 5200) -> np.ndarray:
    rng = np.random.default_rng(seed)
    y = np.zeros(n_of(1.7))
    t_all = t_axis(y.size)
    # 1) riffle: card-edge clicks, accelerating and slightly crescendoing
    tt, start, end = 0.04, 0.04, 0.95
    cn = n_of(0.006)
    ct = t_axis(cn)
    while tt < end:
        prog = (tt - start) / (end - start)
        click = unit(filt(rng.standard_normal(cn), "bandpass", [2000.0, 7000.0])) * np.exp(-ct / 0.0008)
        click += 0.4 * np.sin(TAU * rng.uniform(1800.0, 3000.0) * ct) * np.exp(-ct / 0.002)
        add_into(y, n_of(tt), rng.uniform(0.5, 1.0) * (0.6 + 0.4 * prog) * click)
        tt += (0.026 * (1.0 - prog) + 0.009 * prog) * rng.uniform(0.75, 1.25)
    bed = unit(filt(rng.standard_normal(y.size), "bandpass", [1500.0, 5000.0]))
    bed_env = np.clip((t_all - 0.1) / 0.85, 0, 1) * (t_all < 0.95) * np.clip((0.97 - t_all) / 0.02, 0, 1)
    y += 0.12 * bed * bed_env
    # 2) bridge "whirr": cards cascading back, flap rate falling from ~70 to ~25 Hz
    b0, b1 = 1.0, 1.42
    bn = n_of(b1 - b0)
    bt = t_axis(bn)
    rate = 70.0 - 45.0 * bt / (b1 - b0)
    flap = 0.5 + 0.5 * np.sin(TAU * np.cumsum(rate) / SR) ** 8
    whirr = unit(filt(rng.standard_normal(bn), "bandpass", [1000.0, 5000.0])) * flap
    whirr *= np.sin(np.pi * bt / (b1 - b0)) ** 1.5
    add_into(y, n_of(b0), 0.55 * whirr)
    # 3) squared tap: the deck knocked square on the felt (two quick taps)
    for when, g in ((1.48, 1.0), (1.555, 0.55)):
        tn = n_of(0.08)
        tt2 = t_axis(tn)
        tap = (np.sin(TAU * 190.0 * tt2) * np.exp(-tt2 / 0.015)
               + 0.7 * unit(filt(rng.standard_normal(tn), "lowpass", 1200.0)) * np.exp(-tt2 / 0.006))
        add_into(y, n_of(when), 0.65 * g * tap * ramp_in(tn, 0.001))
    return y


def sfx_ui(kind: str) -> np.ndarray:
    rng = np.random.default_rng({"hover": 6001, "click": 6002, "back": 6003}[kind])
    if kind == "hover":
        n = n_of(0.05)
        y = modal([3100.0, 5200.0], [1.0, 0.35], [0.0065, 0.004], n)
        y += 0.2 * unit(filt(rng.standard_normal(n), "highpass", 4000.0)) * np.exp(-t_axis(n) / 0.0006)
        return filt(y, "lowpass", 7000.0)
    n = n_of(0.08)
    if kind == "click":
        y = modal([1150.0, 2700.0, 450.0], [1.0, 0.45, 0.4], [0.011, 0.005, 0.009], n)
    else:
        y = modal([820.0, 1950.0, 340.0], [1.0, 0.4, 0.45], [0.013, 0.006, 0.011], n)
    y += 0.3 * unit(filt(rng.standard_normal(n), "lowpass", 5000.0)) * np.exp(-t_axis(n) / 0.0007)
    return y


def render_notes(events, length: float, rng: np.random.Generator) -> np.ndarray:
    """events: (time s, midi, vel, kind, extra-kwargs) for mallet notes."""
    y = np.zeros(n_of(length))
    for when, midi, vel, kind, kw in events:
        add_into(y, n_of(when), mallet_note(midi, vel, length - when, rng, kind, **kw))
    return y


def sfx_win() -> np.ndarray:
    rng = np.random.default_rng(7001)
    notes = [(0.00, 65, 0.55), (0.075, 69, 0.6), (0.15, 72, 0.65), (0.225, 74, 0.7), (0.30, 79, 0.8)]
    ev = [(w, m, v, "vibe", {"motor": 0.18}) for w, m, v in notes]
    ev += [(w + 0.004, m + 12, 0.25 * v, "celesta", {}) for w, m, v in notes]
    y = render_notes(ev, 1.0, rng)
    y = reverb_mono(y, 1.3, 0.3, seed=7101)[:n_of(0.9)]
    return fade(y, 0.0, 0.25)


def sfx_blackjack() -> np.ndarray:
    rng = np.random.default_rng(7002)
    length = 1.95
    arp = [65, 69, 72, 76, 79, 81, 84]
    ev = [(0.055 * i, m, 0.5 + 0.05 * i, "vibe", {"motor": 0.2}) for i, m in enumerate(arp)]
    for _ in range(9):  # sparkle
        ev.append((rng.uniform(0.38, 1.35), int(rng.choice([84, 86, 88, 91, 93, 96])),
                   rng.uniform(0.15, 0.3), "celesta", {}))
    y = render_notes(ev, length, rng)
    chord = [53, 60, 64, 67, 69, 74]  # F C E G A D: F6/9 with maj7
    c0 = n_of(0.30)
    shimmer = np.zeros(n_of(length))
    for m in chord:
        pad = pad_note(m, 0.9, 0.35, rng, attack=0.12, release=0.6).mean(axis=0)
        add_into(shimmer, c0, pad)
        add_into(shimmer, c0 + n_of(rng.uniform(0, 0.02)), rhodes_note(m, 0.9, 0.35, rng))
    tt = t_axis(shimmer.size)
    shimmer *= 1.0 - 0.12 * (0.5 - 0.5 * np.cos(TAU * 5.5 * tt))
    y += 0.9 * shimmer
    air = unit(filt(rng.standard_normal(y.size), "highpass", 7000.0))
    air *= smooth_random(rng, y.size, 18.0) ** 2 * np.clip((tt - 0.3) / 0.3, 0, 1) * np.exp(-np.maximum(tt - 0.6, 0) / 0.5)
    y += 0.02 * air
    y = reverb_mono(y, 1.8, 0.35, seed=7102)[:n_of(1.8)]
    return fade(y, 0.0, 0.4)


def sfx_lose() -> np.ndarray:
    rng = np.random.default_rng(7003)
    y = np.zeros(n_of(0.8))
    add_into(y, 0, rhodes_note(60, 0.16, 0.45, rng, bright=0.5))
    add_into(y, n_of(0.2), rhodes_note(57, 0.32, 0.4, rng, bright=0.5))
    y = filt(y, "lowpass", 1800.0)
    y = reverb_mono(y, 1.0, 0.15, seed=7103)[:n_of(0.6)]
    return fade(y, 0.0, 0.12)


def sfx_bust() -> np.ndarray:
    rng = np.random.default_rng(7004)
    n = n_of(0.6)
    t = t_axis(n)
    ph = TAU * np.cumsum(55.0 + 40.0 * np.exp(-t / 0.03)) / SR
    thump = np.sin(ph) * np.exp(-t / 0.07) + 0.5 * unit(filt(rng.standard_normal(n), "lowpass", 300.0)) * np.exp(-t / 0.025)
    y = thump * ramp_in(n, 0.002)
    add_into(y, n_of(0.01), 0.8 * rhodes_note(45, 0.3, 0.5, rng, bright=0.4))   # A2
    add_into(y, n_of(0.018), 0.7 * rhodes_note(51, 0.3, 0.45, rng, bright=0.4))  # Eb3 (tritone)
    y = filt(y, "lowpass", 900.0)
    y = reverb_mono(y, 0.9, 0.12, seed=7104)[:n_of(0.5)]
    return fade(y, 0.0, 0.1)


def sfx_push() -> np.ndarray:
    rng = np.random.default_rng(7005)
    y = render_notes([(0.0, 67, 0.55, "vibe", {}), (0.16, 74, 0.55, "vibe", {})], 0.7, rng)
    y = filt(y, "lowpass", 5000.0)
    y = reverb_mono(y, 1.0, 0.15, seed=7105)[:n_of(0.5)]
    return fade(y, 0.0, 0.15)


def sfx_insurance() -> np.ndarray:
    rng = np.random.default_rng(7006)
    y = render_notes([(0.0, 81, 0.8, "bell", {})], 1.0, rng)
    y = reverb_mono(y, 1.5, 0.25, seed=7106)[:n_of(0.8)]
    return fade(y, 0.0, 0.25)


def sfx_achievement() -> np.ndarray:
    rng = np.random.default_rng(7007)
    run = [72, 74, 77, 79, 81, 84, 86, 89]  # F major pentatonic up to F6
    ev = [(0.055 * i, m, 0.45 + 0.05 * i, "celesta", {}) for i, m in enumerate(run)]
    ev += [(0.055 * i + 0.003, m - 12, 0.3, "vibe", {"motor": 0.15}) for i, m in enumerate(run)]
    last = 0.055 * (len(run) - 1)
    ev += [(last, 77, 0.55, "vibe", {"motor": 0.2})]
    for _ in range(6):
        ev.append((rng.uniform(0.3, 0.9), int(rng.choice([93, 96, 98, 101])), rng.uniform(0.1, 0.22), "celesta", {}))
    y = render_notes(ev, 1.35, rng)
    y = reverb_mono(y, 1.6, 0.3, seed=7107)[:n_of(1.2)]
    return fade(y, 0.0, 0.3)


def sfx_coach(good: bool) -> np.ndarray:
    rng = np.random.default_rng(7008 if good else 7009)
    if good:
        y = render_notes([(0.0, 88, 0.5, "celesta", {"decay_scale": 0.12}),
                          (0.035, 93, 0.6, "celesta", {"decay_scale": 0.12})], 0.15, rng)
        n = y.size
        y += 0.15 * unit(filt(rng.standard_normal(n), "highpass", 4000.0)) * np.exp(-t_axis(n) / 0.0008)
        return fade(y, 0.0, 0.04)
    n = n_of(0.2)
    t = t_axis(n)
    ph = TAU * np.cumsum(196.0 - 16.0 * t / 0.2) / SR
    y = (np.sin(ph) + 0.2 * np.sin(2 * ph)) * env_ad(n, 0.005, 0.06)
    return fade(filt(y, "lowpass", 1200.0), 0.0, 0.05)


# =============================================================================
# Music: "lounge" (table) - 32-bar swing trio in F
# =============================================================================

LOUNGE_CHART = [
    # A1
    [("F", "maj9", 4)], [("G", "m9", 2), ("C", "13", 2)], [("A", "m7", 2), ("D", "7b9", 2)],
    [("G", "m9", 2), ("C", "13", 2)], [("C", "m9", 2), ("F", "13", 2)], [("Bb", "maj9", 4)],
    [("A", "m7", 2), ("D", "7b9", 2)], [("G", "m9", 2), ("C", "7b9", 2)],
    # A2
    [("F", "maj9", 4)], [("G", "m9", 2), ("C", "13", 2)], [("A", "m7", 2), ("D", "7b9", 2)],
    [("G", "m9", 2), ("C", "13", 2)], [("C", "m9", 2), ("F", "13", 2)], [("Bb", "maj9", 2), ("Bb", "m6", 2)],
    [("G", "m9", 2), ("C", "13", 2)], [("F", "69", 4)],
    # B (bridge)
    [("C", "m9", 4)], [("F", "13", 4)], [("Bb", "maj9", 4)], [("Bb", "m9", 2), ("Eb", "13", 2)],
    [("A", "m7", 4)], [("D", "7b9", 4)], [("G", "m9", 4)], [("C", "13", 2), ("C", "7b9", 2)],
    # A3 (turnaround resolves into bar 1 across the loop point)
    [("F", "maj9", 4)], [("G", "m9", 2), ("C", "13", 2)], [("A", "m7", 2), ("D", "7b9", 2)],
    [("G", "m9", 2), ("C", "13", 2)], [("C", "m9", 2), ("F", "13", 2)], [("Bb", "maj9", 2), ("Bb", "m6", 2)],
    [("A", "m7", 2), ("D", "7b9", 2)], [("G", "m9", 2), ("C", "7b9", 2)],
]

# Sparse right-hand fills: (bar index 0-based, beat in bar, midi, length in beats, velocity)
LOUNGE_FILLS = [
    (7, 2 + SWING, 76, 0.45, 0.58), (7, 3.0, 73, 0.4, 0.55), (7, 3 + SWING, 70, 0.4, 0.52), (8, 0.0, 69, 1.6, 0.56),
    (15, 1 + SWING, 81, 0.4, 0.55), (15, 2.0, 79, 0.4, 0.52), (15, 2 + SWING, 77, 0.4, 0.5), (15, 3.0, 74, 1.4, 0.54),
    (23, 1 + SWING, 69, 0.35, 0.5), (23, 2.0, 70, 0.35, 0.5), (23, 2 + SWING, 73, 0.35, 0.52), (23, 3.0, 76, 0.4, 0.55),
    (23, 3 + SWING, 79, 0.4, 0.56), (24, 0.0, 81, 1.5, 0.58),
    (31, 1 + SWING, 77, 0.4, 0.55), (31, 2.0, 76, 0.4, 0.52), (31, 2 + SWING, 73, 0.4, 0.52), (31, 3.0, 70, 0.4, 0.5),
    (31, 3 + SWING, 67, 0.4, 0.5), (32, 0.0, 69, 1.8, 0.55),  # bar 33 == bar 1 of the next pass
]

# Comping rhythms: (chord slot in bar, beat, length in beats, velocity scale)
COMP_ONE = (
    ((0, 0.0, 1.4, 1.0), (0, 1 + SWING, 1.9, 0.85)),          # Charleston
    ((0, SWING, 1.6, 0.95), (0, 2 + SWING, 1.2, 0.8)),        # off-beats
    ((0, 0.0, 3.5, 0.9),),                                    # held
    ((0, 1.0, 0.7, 0.85), (0, 2 + SWING, 1.3, 0.9)),
    ((0, 0.0, 0.8, 1.0), (0, 2.0, 1.6, 0.8)),
)
COMP_TWO = (
    ((0, 0.0, 1.5, 1.0), (1, 2.0, 1.7, 0.9)),
    ((0, SWING, 1.2, 0.95), (1, 2 + SWING, 1.3, 0.9)),
    ((0, 0.0, 0.9, 1.0), (1, 1 + SWING, 2.2, 0.95)),          # pushes chord 2
    ((0, 0.0, 1.2, 0.95), (1, 2.0, 0.6, 0.8), (1, 3.0, 0.8, 0.7)),
)


def drum_banks(seed: int):
    """Pre-rendered ride strokes, brush slaps, hi-hat chicks and a feathered kick."""
    rng = np.random.default_rng(seed)
    n = n_of(2.4)
    t = t_axis(n)
    freqs = np.exp(rng.uniform(np.log(420.0), np.log(9800.0), 56))
    base_amp = rng.uniform(0.3, 1.0, 56) * (0.35 + np.exp(-(np.log(freqs / 3600.0) / 0.75) ** 2))
    taus = np.clip(1.5 * (700.0 / freqs) ** 0.55, 0.12, 1.6)
    ride = []
    for _ in range(4):
        body = modal(freqs, base_amp * rng.uniform(0.7, 1.3, 56), taus, n, rng.uniform(0, TAU, 56))
        wash = unit(filt(rng.standard_normal(n), "bandpass", [3500.0, 11000.0])) * np.exp(-t / 0.45)
        stick = unit(filt(rng.standard_normal(n), "bandpass", [1800.0, 7000.0])) * np.exp(-t / 0.0025)
        ping = np.sin(TAU * rng.uniform(2600.0, 3000.0) * t) * np.exp(-t / 0.35)
        ride.append((0.55 * unit(body) + 0.35 * wash + 0.8 * stick + 0.12 * ping) * ramp_in(n, 0.0005))
    sn = n_of(0.35)
    st = t_axis(sn)
    slaps = []
    for _ in range(4):
        slap = unit(filt(rng.standard_normal(sn), "bandpass", [800.0, 6000.0])) * env_ad(sn, 0.004, 0.07)
        slap += 0.3 * unit(filt(rng.standard_normal(sn), "bandpass", [2500.0, 7000.0])) * env_ad(sn, 0.006, 0.14)
        slap += 0.15 * np.sin(TAU * 185.0 * st) * env_ad(sn, 0.002, 0.035)
        slaps.append(slap)
    hn = n_of(0.12)
    hats = [unit(filt(rng.standard_normal(hn), "bandpass", [6000.0, 12000.0])) * env_ad(hn, 0.001, 0.018)
            for _ in range(3)]
    kn = n_of(0.3)
    kt = t_axis(kn)
    kick = np.sin(TAU * np.cumsum(55.0 + 25.0 * np.exp(-kt / 0.02)) / SR) * env_ad(kn, 0.003, 0.09)
    return ride, slaps, hats, kick


def brush_sweep(n_loop: int, spb: int, rng: np.random.Generator) -> np.ndarray:
    """Continuous brush circles: band-passed noise with a swell every 2 beats,
    rendered long, then loop-crossfaded so it is seamless (stereo)."""
    warm, xf = SR, SR // 2
    length = warm + n_loop + xf
    common = rng.standard_normal(length)
    out = []
    for _ in range(2):
        src = 0.7 * common + 0.3 * rng.standard_normal(length)
        out.append(filt(filt(src, "bandpass", [1500.0, 7000.0]), "lowpass", 9000.0))
    x = np.stack(out)
    loop_pos = (np.arange(length) - warm) % (2 * spb) / (2 * spb)
    x *= 0.45 + 0.55 * np.sin(np.pi * loop_pos) ** 2
    return loop_crossfade(x[:, warm:], n_loop, xf)


def render_lounge(show: bool = False) -> np.ndarray:
    rng = np.random.default_rng(1001)
    spb, bars = 30000, 32                 # 30000 samples/beat = 88.2 BPM
    beat_s = spb / SR
    n_loop = spb * 4 * bars               # exactly 32 bars
    pre, tail = SR, 5 * SR
    m = pre + n_loop + tail
    segs = chart_segments(LOUNGE_CHART)

    def at(beat: float, jitter_ms: float, bias_ms: float = 0.0) -> int:
        j = float(np.clip(rng.normal(bias_ms, jitter_ms), bias_ms - 2.5 * jitter_ms, bias_ms + 2.5 * jitter_ms))
        return pre + int(round(beat * spb + j * SR / 1000.0))

    # --- harmony
    voicings, prev = [], [57, 60, 64, 67]
    for s in segs:
        prev = voice_chord(s.root, s.q, prev, 52, 74, center=62.0)
        voicings.append(prev)
    bass_line = walking_bass(segs, rng)
    if show:
        print_harmony("music_lounge: F major, 32 bars, 88.2 BPM swing (voicing = Rhodes, bass = walking line)",
                      segs, voicings, bass_line)

    # --- electric piano comping + fills
    piano = np.zeros((2, m))
    for bar in range(bars):
        idx = [i for i, s in enumerate(segs) if s.bar == bar]
        pats = COMP_ONE if len(idx) == 1 else COMP_TWO
        for slot, pos, length, vscale in pats[rng.integers(len(pats))]:
            if pos == 0.0 and rng.random() < 0.2:
                pos = SWING - 1.0          # anticipate the downbeat on the "and" of 4
            v = voicings[idx[slot]]
            vel = rng.uniform(0.42, 0.56) * vscale * (1.05 if 16 <= bar < 24 else 1.0)
            start = at(bar * 4 + pos, 7.0, 4.0)
            roll = rng.uniform(0.0, 0.012)
            for k, note in enumerate(v):
                nv = vel * (1.12 if k == len(v) - 1 else 0.95) * rng.uniform(0.92, 1.05)
                sig = rhodes_note(note, length * beat_s, nv, rng)
                add_into(piano, start + n_of(roll * k / len(v)), pan(sig, float(np.clip((note - 59) / 30, -0.35, 0.35))))
    for bar, pos, note, length, vel in LOUNGE_FILLS:
        sig = rhodes_note(note, length * beat_s, vel * rng.uniform(0.95, 1.05), rng, bright=1.05)
        add_into(piano, at(bar * 4 + pos, 8.0, 5.0), pan(sig, 0.1))

    # --- walking bass
    bass = np.zeros(m)
    for beat, note, vel, slide in bass_line:
        add_into(bass, at(beat, 5.0, -3.0), bass_note(note, 0.93 * beat_s, vel, rng, slide_from=slide))

    # --- drums: ride "ding, ding-da-ding", brushes, hat foot, feathered kick
    ride_bank, slaps, hats, kick = drum_banks(4242)
    ride, brush, hat, bd = np.zeros(m), np.zeros(m), np.zeros(m), np.zeros(m)
    ride_pat = ((0.0, 0.72), (1.0, 0.86), (1 + SWING, 0.5), (2.0, 0.72), (3.0, 0.86), (3 + SWING, 0.5))
    for bar in range(bars):
        b0 = bar * 4
        for pos, v in ride_pat:
            if pos % 1 and rng.random() < 0.12:
                continue
            add_into(ride, at(b0 + pos, 4.0, -1.0), v * rng.uniform(0.88, 1.08) * ride_bank[rng.integers(4)])
        if rng.random() < 0.12:
            add_into(ride, at(b0 + 2 + SWING, 4.0), 0.42 * ride_bank[rng.integers(4)])
        for pos in (1.0, 3.0):
            add_into(hat, at(b0 + pos, 3.0), rng.uniform(0.6, 0.8) * hats[rng.integers(3)])
            add_into(brush, at(b0 + pos, 5.0), rng.uniform(0.7, 0.9) * slaps[rng.integers(4)])
        for pos in (SWING, 2 + SWING):
            if rng.random() < 0.15:
                add_into(brush, at(b0 + pos, 5.0), rng.uniform(0.25, 0.35) * slaps[rng.integers(4)])
        if bar % 8 == 7:  # lift into the next section
            add_into(brush, at(b0 + 3 + SWING, 4.0), 0.7 * slaps[rng.integers(4)])
        for pos in (0.0, 2.0):
            add_into(bd, at(b0 + pos, 4.0), rng.uniform(0.4, 0.55) * kick)

    # --- bus processing (all LTI / time-based, done before folding)
    t_loop = (np.arange(m) - pre) / SR
    loop_s = n_loop / SR
    trem = 0.16 * np.sin(TAU * (round(3.6 * loop_s) / loop_s) * t_loop)  # whole cycles per loop
    piano = filt(filt(piano, "lowpass", 7500.0), "highpass", 90.0)
    piano[0] *= 1.0 + trem
    piano[1] *= 1.0 - trem
    bass = filt(bass, "lowpass", 1400.0)
    ride = filt(filt(ride, "highpass", 400.0), "lowpass", 10000.0)
    buses = {
        "piano": (piano, -20.0), "bass": (pan(bass, 0.0), -22.5), "ride": (pan(ride, 0.3), -31.5),
        "hat": (pan(hat, 0.25), -38.5), "brush": (pan(brush, -0.2), -33.5), "kick": (pan(bd, 0.0), -37.0),
    }
    staged = {k: set_loudness(sig, target) for k, (sig, target) in buses.items()}
    dry = sum(staged.values())
    send = 0.22 * staged["piano"] + 0.08 * staged["bass"] + 0.25 * (staged["ride"] + staged["brush"] + staged["hat"])
    wet = reverb_wet(send, make_ir(1.5, seed=1500, predelay=0.015, damp_hz=4500.0))[:, :m]
    mix = filt(filt(dry + wet, "highpass", 35.0), "lowpass", 13000.0)

    loop = loop_fold(mix, n_loop, pre)
    sweep = brush_sweep(n_loop, spb, rng)
    loop += set_loudness(sweep, -37.0)   # same staging scale as the buses above
    loop = set_loudness(loop, -20.0)
    return soft_limit(loop, -3.0).astype(np.float32)


# =============================================================================
# Music: "menu" nocturne - 16 bars in Bb, 56 BPM, no drums
# =============================================================================

MENU_CHART = [
    [("Bb", "maj9", 4)], [("G", "m9", 4)], [("Eb", "maj9", 4)], [("F", "9sus", 4)],
    [("D", "m7", 4)], [("G", "m9", 4)], [("C", "m9", 4)], [("F", "13", 4)],
    [("Eb", "maj9", 4)], [("Eb", "m9", 4)], [("D", "m7", 4)], [("G", "7b9", 4)],
    [("C", "m9", 4)], [("F", "13", 4)], [("Bb", "maj9", 4)], [("F", "9sus", 4)],
]

# (bar, beat, midi, beats, velocity) - a sparse, singing top line
MENU_MELODY = [
    (0, 1.0, 81, 1.5, 0.45), (0, 2.5, 77, 1.5, 0.40),
    (1, 0.5, 81, 2.0, 0.42), (1, 3.0, 74, 1.0, 0.38),
    (2, 0.0, 79, 2.0, 0.45), (2, 2.0, 77, 2.0, 0.40),
    (3, 0.0, 75, 1.5, 0.42), (3, 1.5, 72, 2.5, 0.38),
    (4, 1.0, 77, 2.0, 0.42), (4, 3.0, 72, 1.0, 0.38),
    (5, 0.0, 81, 3.0, 0.45),
    (6, 0.5, 79, 1.0, 0.40), (6, 1.5, 75, 1.0, 0.38), (6, 2.5, 74, 1.5, 0.40),
    (7, 0.0, 74, 2.0, 0.42), (7, 2.0, 69, 2.0, 0.36),
    (8, 1.0, 79, 1.0, 0.42), (8, 2.0, 82, 2.0, 0.46),
    (9, 0.0, 78, 2.0, 0.44), (9, 2.5, 77, 1.5, 0.40),
    (10, 0.5, 74, 1.5, 0.40), (10, 2.0, 72, 2.0, 0.38),
    (11, 0.0, 71, 1.5, 0.40), (11, 1.5, 68, 2.5, 0.36),
    (12, 0.0, 70, 1.0, 0.38), (12, 1.0, 74, 3.0, 0.42),
    (13, 0.5, 74, 1.0, 0.40), (13, 1.5, 75, 1.0, 0.40), (13, 2.5, 72, 1.5, 0.38),
    (14, 0.0, 74, 3.0, 0.40),
    (15, 1.0, 70, 1.0, 0.36), (15, 2.0, 72, 1.0, 0.38), (15, 3.0, 77, 1.0, 0.40),
]


def render_menu(show: bool = False) -> np.ndarray:
    rng = np.random.default_rng(2002)
    spb, bars = 47250, 16                 # 47250 samples/beat = 56 BPM
    beat_s = spb / SR
    n_loop = spb * 4 * bars
    pre, tail = SR, 6 * SR
    m = pre + n_loop + tail
    segs = chart_segments(MENU_CHART)

    def at(beat: float, jitter_ms: float = 5.0) -> int:
        j = float(np.clip(rng.normal(0.0, jitter_ms), -2.5 * jitter_ms, 2.5 * jitter_ms))
        return pre + int(round(beat * spb + j * SR / 1000.0))

    voicings, prev = [], [57, 62, 65, 69]
    for s in segs:
        prev = voice_chord(s.root, s.q, prev, 50, 72, center=61.0)
        voicings.append(prev)
    bass_line, pb = [], 46
    for s in segs:
        root = place_note(s.root, pb, 34, 50, 41.0)
        if rng.random() < 0.35:
            fifth = place_note(s.root + 7, root, 34, 50, 41.0)
            bass_line += [(s.start, root, 0.8, None, 2.9), (s.start + 3, fifth, 0.62, None, 0.95)]
        else:
            bass_line.append((s.start, root, 0.8, None, 3.9))
        pb = root
    if show:
        print_harmony("music_menu: Bb major, 16 bars, 56 BPM (voicing = Rhodes/pad, bass = roots)",
                      segs, voicings, [(b, mm, v, s) for b, mm, v, s, _ in bass_line])
        print("  melody: " + " ".join(f"{b + 1}.{p + 1:g}:{note_name(mm)}" for b, p, mm, _, _ in MENU_MELODY))

    rhodes, melody, pad = np.zeros((2, m)), np.zeros((2, m)), np.zeros((2, m))
    for s, v in zip(segs, voicings):
        start = at(s.start)
        spread = rng.uniform(0.18, 0.4)
        vel = rng.uniform(0.3, 0.38)
        for k, note in enumerate(v):
            sig = rhodes_note(note, s.beats * beat_s * 0.95, vel * rng.uniform(0.9, 1.05), rng, bright=0.9)
            add_into(rhodes, start + n_of(spread * k / (len(v) - 1)), pan(sig, (note - 64) / 30))
            add_into(pad, at(s.start - 0.25, 0.0), pad_note(note, s.beats * beat_s + 0.3, 0.5, rng))
        if rng.random() < 0.45:
            for note in v[-2:]:
                sig = rhodes_note(note, 1.2 * beat_s, 0.24, rng, bright=0.8)
                add_into(rhodes, at(s.start + 2.5), pan(sig, (note - 64) / 30))
    for bar, pos, note, length, vel in MENU_MELODY:
        sig = rhodes_note(note, length * beat_s, vel, rng, bright=1.1)
        add_into(melody, at(bar * 4 + pos, 8.0), pan(sig, -0.08))
    bass = np.zeros(m)
    for beat, note, vel, _, length in bass_line:
        add_into(bass, at(beat), bass_note(note, length * beat_s, vel, rng, bright=0.45, sustain=2.0, release=0.4))
    swells = np.zeros((2, m))
    sw_n = n_of(2.5 * beat_s)
    for bar in range(0, bars, 2):
        src = filt(rng.standard_normal((2, sw_n)), "bandpass", [2000.0, 7000.0])
        shape = np.sin(np.pi * np.arange(sw_n) / sw_n) ** 2 * np.linspace(0.6, 1.0, sw_n)
        add_into(swells, at(bar * 4 + 1.0), src * shape)

    t_loop = (np.arange(m) - pre) / SR
    loop_s = n_loop / SR
    trem = 0.12 * np.sin(TAU * (round(2.6 * loop_s) / loop_s) * t_loop)
    for bus in (rhodes, melody):
        bus[0] *= 1.0 + trem
        bus[1] *= 1.0 - trem
    pad = filt(pad, "lowpass", 1800.0)
    bass = filt(bass, "lowpass", 900.0)
    staged = {
        "rhodes": set_loudness(filt(rhodes, "highpass", 90.0), -21.0),
        "melody": set_loudness(melody, -23.0),
        "pad": set_loudness(pad, -24.5),
        "bass": set_loudness(pan(bass, 0.0), -25.0),
        "swells": set_loudness(swells, -41.0),
    }
    dry = sum(staged.values())
    send = 0.35 * (staged["rhodes"] + staged["melody"]) + 0.3 * staged["pad"] + 0.08 * staged["bass"] + 0.3 * staged["swells"]
    wet = reverb_wet(send, make_ir(2.6, seed=2500, predelay=0.025, damp_hz=3800.0))[:, :m]
    mix = filt(filt(dry + wet, "highpass", 35.0), "lowpass", 12000.0)
    loop = set_loudness(loop_fold(mix, n_loop, pre), -20.0)
    return soft_limit(loop, -3.0).astype(np.float32)


# =============================================================================
# Ambience: warm room, distant murmur, rare faint clinks (48 s, exactly periodic)
# =============================================================================

def render_ambience() -> np.ndarray:
    rng = np.random.default_rng(3003)
    n_loop = 48 * SR
    warm, xf = 6 * SR, 2 * SR
    length = warm + n_loop + xf

    # room tone: brown (low rumble) + pink (air), partly decorrelated L/R
    brown_c, pink_c = colored_noise(rng, length, 2.0), colored_noise(rng, length, 1.0)
    room = []
    for _ in range(2):
        b = 0.75 * brown_c + 0.66 * colored_noise(rng, length, 2.0)
        p = 0.75 * pink_c + 0.66 * colored_noise(rng, length, 1.0)
        room.append(filt(b, "lowpass", 220.0) + 0.25 * filt(p, "lowpass", 900.0))
    room = filt(np.stack(room), "highpass", 25.0)
    room = loop_crossfade(room[:, warm:], n_loop, xf)

    # murmur: noise "voices" through morphing formant bands with slow random AM
    murmur = np.zeros((2, length))
    for _ in range(9):
        src = rng.standard_normal(length)
        sets = []
        for _ in range(2):
            formants = (rng.uniform(320.0, 800.0), rng.uniform(950.0, 1900.0), rng.uniform(2250.0, 3000.0))
            sets.append(sum(g * filt(src, "bandpass", [f * 0.82, f * 1.22])
                            for f, g in zip(formants, (1.0, 0.55, 0.25))))
        vowel = 0.5 + 0.5 * np.tanh(1.5 * smooth_random(rng, length, 1.2))
        voice = sets[0] * vowel + sets[1] * (1.0 - vowel)
        syllables = 0.5 + 0.5 * np.tanh(1.8 * smooth_random(rng, length, 4.0))
        phrases = 0.5 + 0.5 * np.tanh(2.5 * (smooth_random(rng, length, 0.12) + 0.3))
        voice *= (0.3 + 0.7 * syllables) * phrases
        murmur += pan(filt(voice, "lowpass", 1800.0), rng.uniform(-0.7, 0.7)) * rng.uniform(0.6, 1.0)
    murmur = loop_crossfade(murmur[:, warm:], n_loop, xf)

    # faint distant clinks, placed circularly (they wrap around the loop point)
    clinks = np.zeros((2, n_loop))
    times = np.sort(rng.uniform(0, 48.0, 7))
    for i, when in enumerate(times):
        if i and when - times[i - 1] < 3.0:
            when += 3.0
        sig = chip_clack(rng) if rng.random() < 0.55 else glass_clink(rng)
        sig = filt(sig, "lowpass", 4500.0) * rng.uniform(0.4, 1.0)
        add_circular(clinks, n_of(when), pan(sig, rng.uniform(-0.8, 0.8)))

    # distant = mostly reverberant; circular convolution keeps it exactly periodic
    murmur = set_rms(murmur, -40.0)
    clinks = clinks * (db_to_gain(-33.0) / peak(clinks))
    ir = make_ir(2.4, seed=3500, predelay=0.03, damp_hz=3000.0)
    wet = reverb_wet(murmur + 0.8 * clinks, ir, circular=True)
    distant = 0.35 * murmur + 0.15 * clinks + wet
    mix = set_rms(room, -35.5) + set_rms(distant, -35.0) * 1.0
    return set_rms(mix, -32.0).astype(np.float32)


# =============================================================================
# Registry, encoding, verification
# =============================================================================

def build_registry():
    """name -> (builder, kind, peak dBFS or None)."""
    r = {}
    slides = ((2201, 0.22, 3200.0, 0.35, False), (2202, 0.26, 2600.0, 0.45, True), (2203, 0.19, 3800.0, 0.30, False))
    for i, args in enumerate(slides, 1):
        r[f"card_slide_{i}"] = (lambda a=args: sfx_card_slide(*a), "sfx", -4.0)
    r["card_flip_1"] = (lambda: sfx_card_flip(2301, 3200.0, 3), "sfx", -3.0)
    r["card_flip_2"] = (lambda: sfx_card_flip(2302, 2700.0, 4), "sfx", -3.0)
    r["card_place_1"] = (lambda: sfx_card_place(2401, 150.0), "sfx", -5.0)
    r["card_place_2"] = (lambda: sfx_card_place(2402, 170.0), "sfx", -5.0)
    for i, (seed, f0) in enumerate(((5001, 2600.0), (5002, 3050.0), (5003, 2350.0)), 1):
        r[f"chip_click_{i}"] = (lambda s=seed, f=f0: sfx_chip_click(s, f), "sfx", -3.0)
    r["chip_stack_1"] = (lambda: sfx_chip_stack(5011, 5), "sfx", -3.0)
    r["chip_stack_2"] = (lambda: sfx_chip_stack(5012, 7), "sfx", -3.0)
    r["chips_payout"] = (sfx_chips_payout, "sfx", -3.0)
    r["shuffle"] = (sfx_shuffle, "sfx", -3.5)
    r["ui_hover"] = (lambda: sfx_ui("hover"), "sfx", -21.0)
    r["ui_click"] = (lambda: sfx_ui("click"), "sfx", -12.0)
    r["ui_back"] = (lambda: sfx_ui("back"), "sfx", -13.0)
    r["win"] = (sfx_win, "sfx", -5.0)
    r["blackjack"] = (sfx_blackjack, "sfx", -3.5)
    r["lose"] = (sfx_lose, "sfx", -8.0)
    r["bust"] = (sfx_bust, "sfx", -6.0)
    r["push"] = (sfx_push, "sfx", -9.0)
    r["insurance"] = (sfx_insurance, "sfx", -7.0)
    r["achievement"] = (sfx_achievement, "sfx", -4.0)
    r["coach_good"] = (lambda: sfx_coach(True), "sfx", -13.0)
    r["coach_bad"] = (lambda: sfx_coach(False), "sfx", -13.0)
    r["music_lounge"] = (render_lounge, "loop", None)
    r["music_menu"] = (render_menu, "loop", None)
    r["ambience_room"] = (render_ambience, "loop", None)
    return r


def encode_ogg(x: np.ndarray, path: Path) -> None:
    x = np.asarray(x, dtype=np.float32)
    channels = 1 if x.ndim == 1 else x.shape[0]
    interleaved = x if x.ndim == 1 else x.T
    cmd = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
           "-f", "f32le", "-ar", str(SR), "-ac", str(channels), "-i", "pipe:0",
           "-map_metadata", "-1", "-c:a", "libvorbis", "-q:a", "5",
           "-fflags", "+bitexact", "-flags:a", "+bitexact"]
    if x.shape[-1] < 5 * SR:
        # ffmpeg's Ogg muxer writes an imprecise end granule when the whole stream
        # fits in one page (short SFX decode up to 128 samples long/short); 10 ms
        # pages make the decoded length sample-exact.
        cmd += ["-page_duration", "10000"]
    cmd.append(str(path))
    subprocess.run(cmd, input=np.ascontiguousarray(interleaved).astype("<f4").tobytes(), check=True)


def probe(path: Path) -> dict:
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries",
                          "stream=codec_name,channels,sample_rate:format=duration", "-of", "json", str(path)],
                         capture_output=True, text=True, check=True)
    info = json.loads(out.stdout)
    st = info["streams"][0]
    return {"codec": st["codec_name"], "channels": int(st["channels"]), "rate": int(st["sample_rate"]),
            "duration": float(info["format"]["duration"])}


def decode(path: Path, channels: int) -> np.ndarray:
    out = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le", "-ac", str(channels),
                          "-ar", str(SR), "pipe:1"], capture_output=True, check=True)
    a = np.frombuffer(out.stdout, dtype="<f4").astype(np.float64)
    return a if channels == 1 else a.reshape(-1, channels).T


def loop_report(x: np.ndarray, period: int) -> str:
    """Seam check for a loop.

    * level: RMS of the 50 ms after vs. before the loop point, compared with the
      same measurement at every internal boundary `period` samples apart (bar
      lines for music), since a downbeat is naturally louder than the bar end;
    * continuity: the sample step across the wrap vs. the 99th percentile of all
      sample-to-sample steps in the file.
    """
    xs = np.atleast_2d(x)
    n, k = xs.shape[1], n_of(0.05)

    def boundary(pos: int) -> float:
        after = xs[:, (pos + np.arange(k)) % n]
        before = xs[:, (pos - k + np.arange(k)) % n]
        return gain_to_db(rms(after)) - gain_to_db(rms(before))

    wrap = boundary(0)
    inner = np.abs([boundary(pos) for pos in range(period, n, period)])
    jump = float(np.max(np.abs(xs[:, 0] - xs[:, -1])))
    p99 = float(np.percentile(np.abs(np.diff(xs, axis=1)), 99))
    return (f"head-tail {wrap:+.1f} dB (internal boundaries: median {np.median(inner):.1f}, "
            f"max {inner.max():.1f} dB); wrap step {jump:.5f} = {jump / (p99 + 1e-12):.2f}x p99 step")


LOOP_PERIOD = {"music_lounge": 4 * 30000, "music_menu": 4 * 47250, "ambience_room": SR}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--only", help="render only files whose name contains this substring")
    ap.add_argument("--show-harmony", action="store_true", help="print chord voicings and bass lines")
    ap.add_argument("--no-verify", action="store_true", help="skip ffprobe/decode checks")
    args = ap.parse_args()

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    rows = []
    for name, (builder, kind, peak_db) in build_registry().items():
        if args.only and args.only not in name:
            continue
        if kind == "loop":
            x = builder(args.show_harmony) if name.startswith("music") else builder()
        else:
            x = finish_sfx(builder(), peak_db)
        assert np.all(np.isfinite(x)), name
        assert peak(x) < 1.0, f"{name} clips"
        path = OUT_DIR / f"{name}.ogg"
        encode_ogg(x, path)
        rows.append((name, kind, x, path))
        print(f"  wrote {path.relative_to(ROOT)}", flush=True)

    print(f"\n{'file':22s} {'dur s':>7s} {'ch':>3s} {'peak dBFS':>10s} {'RMS dBFS':>9s} {'LUFS':>7s} "
          f"{'centroid':>9s} {'KiB':>6s}")
    total = 0
    for name, kind, x, path in rows:
        size = path.stat().st_size
        total += size
        ch = 1 if x.ndim == 1 else x.shape[0]
        print(f"{name + '.ogg':22s} {x.shape[-1] / SR:7.3f} {ch:3d} {gain_to_db(peak(x)):10.1f} "
              f"{gain_to_db(rms(x)):9.1f} {lufs(x):7.1f} {spectral_centroid(x):8.0f}Hz {size / 1024:6.0f}")
    print(f"total size: {total / 1024 / 1024:.2f} MiB in {len(rows)} files")

    if args.no_verify:
        return 0
    print("\nverification (ffprobe + decode):")
    ok = True
    for name, kind, x, path in rows:
        info = probe(path)
        ch = 1 if x.ndim == 1 else x.shape[0]
        dec = decode(path, ch)
        n_dec = dec.shape[-1]
        good = (info["codec"] == "vorbis" and info["channels"] == ch and info["rate"] == SR
                and n_dec == x.shape[-1] and abs(info["duration"] - x.shape[-1] / SR) < 0.01)
        ok &= good
        line = (f"  {'OK ' if good else 'BAD'} {name + '.ogg':22s} {info['codec']} {info['channels']}ch "
                f"{info['duration']:.3f}s, {n_dec} samples (expected {x.shape[-1]})")
        if kind == "loop":
            per = LOOP_PERIOD[name]
            line += ("\n        float:   " + loop_report(x, per) + "\n        decoded: " + loop_report(dec, per)
                     + f"\n        decoded vs float max abs diff {np.max(np.abs(dec - x)):.4f}")
        print(line)
    print("all files OK" if ok else "SOME FILES FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
