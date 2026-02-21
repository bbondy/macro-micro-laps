# Macro Lap (BYU) Connect IQ Data Field

Macro Lap is a Connect IQ data field that adds virtual "macro laps" for Backyard Ultra while keeping Garmin micro laps untouched.

## Behavior

- Macro starts automatically at activity start (Macro Lap 1).
- Double-lap press (two lap events within the threshold) starts the next macro at the second press.
- Single lap presses remain normal Garmin laps and are recorded as usual.

## Display

The data field shows:

- Macro lap number
- Macro elapsed time
- Macro average pace (M:SS per mi/km)
- Time left to the target loop time
- Macro distance and distance left
- Projected full-distance time (PROJ)

## Settings

Settings are available in Garmin Connect Mobile / Express:

- Enable custom targets (default off)
- Target time minutes/seconds
- Target distance (x1000, e.g. 4167 = 4.167)
- Target distance unit (miles/km)
- Double-tap threshold seconds

Defaults: 59:59, 4.1666666667 mi, 3 seconds.

## Install

1. Open the project in the Connect IQ SDK.
2. Build and install the data field to your watch.
3. Add the data field to an activity screen.

### Build with Make

You can also build from the terminal:

```sh
make
```

Optional overrides:

```sh
make DEVICE=fenix7_sim
make SDK_ROOT="~/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.0-2025-12-03-5122605dc"
```

By default, the Makefile reads `~/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg` to find the active SDK.

### Run in Simulator

Start the Connect IQ Simulator first, then run:

```sh
make sim DEVICE=enduro
```

To start the simulator from a terminal (and see logs/crash output), run:

```sh
make sim-console
```

### Package for Watch

Build a signed `.iq` package:

```sh
make package DEVICE=enduro DEV_KEY="$HOME/Library/Application Support/Garmin/ConnectIQ/keys/developer_key.der"
```

`make package` creates an export package for dashboard upload and validates that it is a real `.iq` bundle.

If you only want a local signed artifact (not for dashboard upload), use:

```sh
make package-local
```

Install the `.iq` using Garmin Express or the Connect IQ mobile app (developer mode):

```sh
make install
```

### Developer Key (Local Build)

The compiler requires a developer key. You can generate one locally:

```sh
make key
```

This writes `developer_key.der` to `~/Library/Application Support/Garmin/ConnectIQ/keys/` and will copy it to the path set in `DEV_KEY` (from `.envrc`) if different. Then build:

```sh
make
```

## Use

Start your activity and run as normal. At the loop start, double-press Lap within the threshold to begin the next macro lap. The field will flash "MACRO START" for ~2 seconds to confirm the marker.
