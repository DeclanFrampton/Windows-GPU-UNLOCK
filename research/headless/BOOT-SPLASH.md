# Optional USB boot animation

The research USB wrapper can play a prerendered 1920×1080 animation before
attempting the unlock. Esc is available during the three-second countdown.
The final burst plays immediately before driver release. Existing machine
profiles, preflight checks and Windows handoff rules still apply.

Generate and pack the generic GPU artwork locally:

```powershell
python -m pip install numpy "pillow>=10.1" opencv-python imageio-ffmpeg lz4
python .\research\headless\render-splash.py
python .\research\headless\pack-splash.py .\splash-preview.mp4 .\SPLASH.BIN
```

Add `-SplashAsset .\SPLASH.BIN` to the existing
`research/headless/build-usb.ps1` invocation. Use the usual
`research/headless/stage-usb.ps1` workflow to copy the resulting package.
The wrapper pins the asset length and SHA-256 at build time. The default
build retains the existing text prompt.

The player decodes independent RGB565 frames. On a compatible 1920×1080
linear surface, it compares the initial GOP copy with streaming writes to
the framebuffer reported by GOP. It selects direct writes when measured
faster and skips unchanged pixel groups. Playback follows elapsed time and
can skip frames on slower firmware. Graphics activity and allocations end
before driver release.

Missing or invalid assets, unsupported displays and an unavailable timestamp
protocol fall back to the existing prompt. This is an experimental option
for the firmware's manual boot menu. The log reports the selected copy path
and the number of countdown frames presented.
