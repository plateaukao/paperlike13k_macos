# Paperlike 13K 2025 Color — macOS Init Script

Open-source macOS init script for the DASUNG Paperlike 13K 2025 color e-ink display.
Replaces the proprietary PaperLikeClient app with a standalone Python script.

## Requirements

- Python 3 + pyserial (`pip install pyserial`)
- CH34x VCP driver (often built-in on modern macOS, or from WCH website)

## Setup

```bash
pip install pyserial
```

## Usage

```bash
# Init and keep display alive (recommended):
./paperlike_init_macos.py --daemon

# Single-shot init (display will deactivate without keepalive):
./paperlike_init_macos.py

# Adjust display settings (can combine multiple):
./paperlike_init_macos.py --mode 3              # Display mode 1-6
./paperlike_init_macos.py --brightness 32       # Brightness 0-64
./paperlike_init_macos.py --speed 5             # Speed 1-8
./paperlike_init_macos.py --temperature 3       # Color temperature 0-5
./paperlike_init_macos.py --front-light 1       # Front light (0=off, 1=warm, 2=cold)
./paperlike_init_macos.py --dither off          # MCU dithering (on/off)
./paperlike_init_macos.py --refresh             # Force full refresh
./paperlike_init_macos.py --query               # Query device info
./paperlike_init_macos.py --mode 3 --brightness 32 --daemon  # Combine
./paperlike_init_macos.py --send 0x02 0x03      # Send raw command
```

### Display modes

| Mode | Name    |
|------|---------|
| 1    | Fast    |
| 2    | Fast+   |
| 3    | Balance |
| 4    | Text    |
| 5    | Text+   |
| 6    | Read    |

### Daemon control socket

When the daemon is running, commands from other instances are automatically
forwarded via a Unix socket (e.g. `/var/folders/.../T/paperlike.sock`). No need to
stop the daemon to change settings:

```bash
./paperlike_init_macos.py --daemon &      # start daemon
./paperlike_init_macos.py --brightness 50  # forwarded to daemon
./paperlike_init_macos.py --mode 1         # forwarded to daemon
./paperlike_init_macos.py --query          # forwarded to daemon
```

### Disconnect/reconnect

In daemon mode, the script handles USB disconnect and reconnect automatically.
When the display is unplugged, it waits for the device to reappear (the serial
port path may change, e.g. `cu.usbserial-1410` -> `cu.usbserial-1420`) and re-runs the full init.

## Native app on macOS Tahoe 26.6+

The bundled `PaperlikeNative.app` connects to the display over the same CH340 serial
port. Two macOS security changes introduced during the Tahoe 26.x cycle can make it
"connect once then disconnect" on other machines even though it works on the machine
it was built on:

1. **Gatekeeper quarantine.** A downloaded build is quarantined and blocked (the app is
   ad-hoc signed, not notarized). On the target Mac, clear it once:
   ```bash
   xattr -dr com.apple.quarantine PaperlikeNative.app
   ```
   (or right-click the app → **Open** the first time).

2. **"Allow accessories to connect"** (Apple Silicon laptops). The default *"Ask for new
   accessories"* can tear the USB serial device down right after it connects. Go to
   **System Settings → Privacy & Security → Allow accessories to connect** and choose
   **Automatically When Unlocked**, then re-plug the display. When the app keeps losing
   the connection it now shows this hint and a shortcut button to that settings pane.

The app detects the device being torn down (the `/dev/cu.*` node disappearing or a write
failing) and automatically reconnects once the device is available and approved.

## Hardware

- **Display**: Paperlike 13K 2025 Color, 3200x2400 @ 37Hz
- **Connection**: USB-C (DisplayPort Alt Mode + USB data)
- **Control**: CH340 serial (VID:PID 0x1a86:0x7523) at 115200 8N1

## Serial protocol

24 ASCII hex characters, **UPPERCASE** (MCU is case-sensitive):

```
5FF5 CC OO PPPPPPPPPPPP A0FA
     |  |  |            └ trailer
     |  |  └ payload (6 bytes, usually zeros)
     |  └ option byte
     └ command byte
```

### Commands

| CMD  | OPT   | Description |
|------|-------|-------------|
| 0x01 | 1-8   | Set speed/threshold |
| 0x02 | 1-6   | Set display mode |
| 0x03 | 1     | Force refresh |
| 0x07 | 0-2   | Set front light mode (0=off, 1=warm, 2=cold) |
| 0x08 | 0-5   | Set color temperature |
| 0x09 | 0-64  | Set brightness |
| 0x0A | *     | Query (opt selects parameter) |
| 0x20 | 0/1   | Dithering control (0=enable/deactivate, 1=disable/activate) |

The display stays active only with periodic `0x20 0x01` commands (~10s interval).
On shutdown, send `0x20 0x00` to deactivate cleanly.
