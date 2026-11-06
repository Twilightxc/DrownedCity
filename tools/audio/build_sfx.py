"""Audio pass 1 (PHASE1 1.5+ A1): cuts the approved CC0 packs into game-ready mono Ogg files.

usage: python tools/audio/build_sfx.py <raw_dir> [out_dir [sound ...]]

<raw_dir> holds the packs as downloaded and extracted (sources and licences: docs/audio/SOURCES.md):
    firearm/x/Prepared SFX Library/...   reload/*.wav   explosion/Chunky Explosion.mp3
    firestaff/x/...   fireloop/fire.wav   zomby/*.mp3   zombienoises/x/*.ogg   squish/x/impsplat/*.flac
    kenney/x/Audio/*.ogg   medieval/x/*.wav (Weapon Textures, both 7z parts extracted into one folder)
The raw packs are never committed; only this script and its output (assets/audio/*.ogg) are. Needs ffmpeg in
PATH and numpy. Every cut is a row of SOUNDS, so a different take is a one-line change.
"""
import os
import subprocess
import sys

import numpy as np

RATE = 44100
FIREARM = "firearm/x/Prepared SFX Library"
FIRESTAFF = "firestaff/x/LEGIT Audio_FIRE STAFF - FREE/Wavs"
KENNEY = "kenney/x/Audio"
MEDIEVAL = "medieval/x"

# out name: (source, start s or "onset", length s, options)
# options: fade (s, at the end), gain_db, af (extra ffmpeg filter before the cut), loop (crossfade s), rate
SOUNDS = {
    # guns: one near-distance shot each (Free Firearm Sound Library, the gun named in the folder)
    "shot_pistol": (f"{FIREARM}/Walther PPQ/X_39P.wav", "onset", 0.6, {"fade": 0.35}),
    "shot_pistol_silenced": (f"{FIREARM}/Walther PPQ/X_39P.wav", "onset", 0.28,
                             {"fade": 0.2, "gain_db": -9.0, "af": "highpass=f=350,lowpass=f=1600"}),
    "shot_ar": (f"{FIREARM}/AR-15/D_32P.wav", "onset", 0.5, {"fade": 0.3}),
    "shot_shotgun": (f"{FIREARM}/Nova/O_21P.wav", "onset", 0.9, {"fade": 0.5}),
    "shot_dmr": (f"{FIREARM}/Tikka/W_29P.wav", "onset", 0.6, {"fade": 0.35}),
    "reload_pistol": ("reload/gunreload1.wav", 0.0, 1.58, {"fade": 0.05}),
    "reload_rifle": ("reload/assaultriflereload1.wav", 0.0, 1.56, {"fade": 0.05}),
    "pump_shotgun": ("reload/shotguncock.wav", 0.0, 0.47, {"fade": 0.05}),
    "shell_insert": (f"{KENNEY}/impactMetal_light_002.ogg", "onset", 0.15,
                     {"fade": 0.08, "gain_db": -5.0, "af": "asetrate=44100*1.3,aresample=44100,lowpass=f=3500"}),
    "dry_click": (f"{KENNEY}/impactMetal_light_000.ogg", "onset", 0.08,
                  {"fade": 0.04, "gain_db": -6.0, "af": "asetrate=44100*1.7,aresample=44100,highpass=f=900"}),
    # blasts and fire
    "blast_frag": ("explosion/Chunky Explosion.mp3", "onset", 3.2, {"fade": 1.2}),
    "blast_incendiary": (f"{FIRESTAFF}/LEGIT_FIR_Fire_Staff 1-Audio.wav", "onset", 1.6, {"fade": 0.7}),
    "fire_loop": ("fireloop/fire.wav", 8.0, 4.0, {"loop": 0.5, "gain_db": -4.0}),
    # zombies (pitched per type at runtime)
    **{f"zombie_groan_{i + 1}": (f"zomby/{n}", "onset", 1.6, {"fade": 0.3, "rate": 22050})
       for i, n in enumerate(["01_zombey.mp3", "02_zombey.mp3", "03_zombey.mp3", "04_zombey_0.mp3",
                              "06_zombey.mp3", "07_zombey.mp3"])},
    **{f"zombie_moan_{i}": (f"zombienoises/x/zombienoise{i}.ogg", "onset", 2.2, {"fade": 0.3, "rate": 22050})
       for i in (1, 2, 3)},
    "zombie_alert": ("zombienoises/x/fastzombie1.ogg", "onset", 0.34, {"fade": 0.05, "rate": 22050}),
    "bloater_pop": ("squish/x/impsplat/impactsplat02.mp3.flac", "onset", 1.1, {"fade": 0.4, "gain_db": 2.0}),
    **{f"flesh_hit_{i}": (f"squish/x/impsplat/impactsplat0{i + 4}.mp3.flac", "onset", 0.25,
                          {"fade": 0.12, "gain_db": -6.0, "rate": 22050}) for i in (1, 2, 3)},
    # melee (J bug list 2026-11-05): two swing takes each from Medieval SFX Weapon Textures (Seax = the knife);
    # the axe's hit is a heavy punch pitched down (the knife's hit is flesh_hit)
    "swing_knife_1": (f"{MEDIEVAL}/Seax Swing.wav", 3.2, 0.45, {"fade": 0.2, "rate": 22050}),
    "swing_knife_2": (f"{MEDIEVAL}/Seax Swing.wav", 6.85, 0.45, {"fade": 0.2, "rate": 22050}),
    "swing_axe_1": (f"{MEDIEVAL}/Axe Swing.wav", 5.8, 0.7, {"fade": 0.3, "rate": 22050}),
    "swing_axe_2": (f"{MEDIEVAL}/Axe Swing.wav", 1.4, 0.7, {"fade": 0.3, "rate": 22050}),
    **{f"hit_axe_{i + 1}": (f"{KENNEY}/impactPunch_heavy_00{n}.ogg", "onset", 0.45,
                            {"fade": 0.2, "af": "asetrate=44100*0.78,aresample=44100,lowpass=f=2500", "rate": 22050})
       for i, n in enumerate((2, 3))},
    # impacts and steps (Kenney Impact Sounds)
    "helmet_clang": (f"{KENNEY}/impactMetal_heavy_001.ogg", "onset", 0.6, {"fade": 0.3}),
    "player_hit": (f"{KENNEY}/impactPunch_heavy_000.ogg", "onset", 0.4, {"fade": 0.15}),
    **{f"footstep_{i + 1}": (f"{KENNEY}/footstep_concrete_00{i}.ogg", "onset", 0.3,
                             {"fade": 0.1, "gain_db": -8.0, "rate": 22050}) for i in range(5)},
}

ONSET_DB = -30.0   # first sample this loud starts the cut
PEAK_DB = -1.0     # every sound is normalised to this peak, then gain_db applies


def decode(path, af=None):
    cmd = ["ffmpeg", "-v", "error", "-i", path]
    if af:
        cmd += ["-af", af]
    cmd += ["-ac", "1", "-ar", str(RATE), "-f", "f32le", "-"]
    return np.frombuffer(subprocess.run(cmd, check=True, capture_output=True).stdout, dtype=np.float32).copy()


def cut(samples, start, length, opts):
    if start == "onset":
        loud = np.nonzero(np.abs(samples) >= 10 ** (ONSET_DB / 20))[0]
        first = int(loud[0]) if loud.size else 0
        s = max(0, first - int(0.005 * RATE))  # keep 5 ms of attack
    else:
        s = int(start * RATE)
    x = samples[s:s + int(length * RATE)].copy()
    loop = opts.get("loop")
    if loop:  # crossfade the tail into the head so the file repeats without a click
        n = int(loop * RATE)
        extra = samples[s + len(x):s + len(x) + n]
        if len(extra) == n:
            ramp = np.linspace(0.0, 1.0, n, dtype=np.float32)
            x[:n] = x[:n] * ramp + extra * (1.0 - ramp)
    fade = opts.get("fade", 0.0)
    if fade and not loop:
        n = min(int(fade * RATE), len(x))
        x[-n:] *= np.linspace(1.0, 0.0, n, dtype=np.float32) ** 2
    peak = float(np.max(np.abs(x))) or 1.0
    x *= 10 ** ((PEAK_DB + opts.get("gain_db", 0.0)) / 20) / peak
    return x


def encode(x, path, rate):
    cmd = ["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(RATE), "-ac", "1", "-i", "-",
           "-ar", str(rate), "-c:a", "libvorbis", "-q:a", "3", path]
    subprocess.run(cmd, input=x.astype(np.float32).tobytes(), check=True)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    raw = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")
    os.makedirs(out, exist_ok=True)
    total = 0
    built = 0
    only = set(sys.argv[3:])  # optional: rebuild just these sounds
    for name, (src, start, length, opts) in SOUNDS.items():
        if only and name not in only:
            continue
        x = cut(decode(os.path.join(raw, src), opts.get("af")), start, length, opts)
        path = os.path.join(out, name + ".ogg")
        encode(x, path, opts.get("rate", RATE))
        size = os.path.getsize(path)
        total += size
        built += 1
        print(f"{name:24s} {len(x) / RATE:5.2f} s {size / 1024:6.1f} KB")
    print(f"{built} sounds, {total / 1024 / 1024:.2f} MB")


if __name__ == "__main__":
    main()
