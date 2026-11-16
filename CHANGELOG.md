# Changelog

Every release of HakiOS for the OnePlus 6T. The full notes, with the known issues of each, are in [`releases/`](releases/)
and on the [releases page](https://github.com/kiwiiiii-eth/hakios-fajita/releases). [繁體中文](CHANGELOG.zh-TW.md)

## [0.6.1-beta] — 2026-11-16

### Fixed
- **The Dynamic Island** (`ISLAND=1`) laid the phone out as one with a home button: no gestures, the old status bar,
  the island over the icons. The loader now gives `/buttons home-button-type` 2 (MobileGestalt's HomeButtonType), and
  `island=1` reports the 14 Pro's screen (1179 x 2556, scaled to the panel). Every install gets `/buttons`, so the
  notch layout no longer depends on an old cache either.

### Added
- `tel=1` (experimental): incoming SMS written to the log, read only; calls need VoLTE, which does not run here.

## [0.6-beta] — 2026-11-16

### Added
- **The cameras**: the main camera (IMX519) in the Camera app at about 30 frames a second, with autofocus and optical
  image stabilisation, and the front camera (IMX371); photographs, the sharpest of four frames. The colour comes from
  the phone's own tuning, which `setup.sh` takes from the phone with the cameras' other files (adb, or read through the
  loader). `cam_full=1` uses the main camera's whole 16 MP array; `cam_ois=0` leaves the stabiliser off.
- **TrollStore 2.1.1**, installed at the first start (`TROLLSTORE=0 ./setup.sh` leaves it out).
- **A Dynamic Island to choose**: `ISLAND=1 ./install.sh`, or `EXTRA="island=1" ./run.sh`.

### Changed
- Photographs are JPEG by default (Formats → Most Compatible) unless a format was chosen before.
- The GPU is kept fast while the camera runs; a hot phone makes fewer camera frames instead of holding the processors
  at full speed.

### Fixed
- The front camera's picture was purple; the camera knocked at every switch between front and back.

## [0.5-beta] — 2026-11-15

### Added
- **A 20 GB data volume** for `/private/var`: HFS Plus, journaled, in `darwin` from 12 GiB on. What iOS writes is on
  the flash at once.
- **A boot screen**: HakiOS, a progress bar while the system image is read and checked, and the boot's facts at the
  bottom. `DEBUG=1 ./install.sh` shows the loader's log there instead.
- The first start after installing or updating moves Beta 0.4's saved data into the volume, once, and only when it
  comes back whole.
- Location, experimental (`gnss=1`): satellites tracked indoors, Location Services turned on by itself, a position in
  Safari's geolocation.

### Changed
- Restarting from iOS takes under a minute (0.4 spent a minute saving `/private/var` first). A forced restart is safe.
- U-Boot no longer writes over the screen on an installed phone.
- `install.sh` makes the data volume (once, with macOS's `newfs_hfs`); `GIB=` takes 20 to 64. An update from 0.4 is
  `./install.sh` again.

### Fixed
- Settings → General → About showed about 1 GB; it shows 21 GB.
- Settings → General → iPhone Storage was empty; it counts the data volume.

## [0.4-beta] — 2026-11-15

### Added
- **Installing**: `./install.sh` puts HakiOS into the slot Android does not use, and the phone **starts iOS from its
  power button** with no Mac. `./switch.sh android|hakios` switches; `./uninstall.sh` puts everything back.
- A partition `darwin` made from the end of userdata (32 GiB by default; **erases Android's data**), checked by the
  loader against both copies of the partition table before it is written, and read back.
- A backup of everything the install changes, in `~/HakiOS-6T-backup/<serial>/`.
- `/private/var` saved into `darwin` as iOS shuts down or restarts, and back at the next start.
- The time from the phone's real-time clock while it was off; the time zone from the cellular network (NITZ).

### Changed
- Shut Down and Restart in iOS really power the phone off or restart it.
- Runs from the Mac last an hour by default and end in fastboot.

### Fixed
- The carrier's name showed as four boxes (a missing font weight).

## [0.3-beta] — 2026-11-15

### Added
- Location, experimental (`gnss=1`): the modem's GPS handed to Location Services.
- Diagnostics over SSH: `stacks`, `logdump`, `socks`.
- For developers: `/private/var` kept across reboots in a partition `darwin` (`ufs_write=1 var_store=1`).

### Changed
- Smoother screen and a quicker start: 55–60 fps when scrolling (from about 50), widgets kept in the background.

### Fixed
- **Safari loads pages**; they spun for ever although the network worked (`mobileactivationd` left out).
- **Wi‑Fi joins a known network again by itself** (auto-join's signal floor was 0 dBm).

## [0.2-beta] — 2026-11-14

### Added
- **The microphone**: Voice Memos records and plays back.
- **BLE keyboards type** once paired in Settings → Bluetooth.
- Ringtones confirmed on the phone (Settings → Sounds & Haptics → Ringtone).

### Changed
- Touch is read 120 times a second on a steady beat (about 80 before), and a touch raises the CPU and GPU to full speed.

## [0.1-beta] — 2026-11-14

The first release for testers: booted from a Mac over USB, the whole system in RAM.

### Added
- **Sound from the speaker** (limited to −20 dBFS).
- **Bluetooth** (`bt=4`): turned on, scans, pairs with a Mac.
- **LTE data** (`ipa8=11`), with the carrier's name and bars in the status bar.
- SSH with your own key, and `neofetch`.
- Ringtones in the system image.

### Fixed
- A panic when the kernel's I/O map ran out (grown from 8 to 128 MB).
- A panic's text saved before the hardware is quiesced; the modem stopped in order when a run ends.

[0.5-beta]: https://github.com/kiwiiiii-eth/hakios-fajita/releases/tag/v0.5-beta
[0.4-beta]: https://github.com/kiwiiiii-eth/hakios-fajita/releases/tag/v0.4-beta
[0.3-beta]: https://github.com/kiwiiiii-eth/hakios-fajita/releases/tag/v0.3-beta
[0.2-beta]: https://github.com/kiwiiiii-eth/hakios-fajita/releases/tag/v0.2-beta
[0.1-beta]: https://github.com/kiwiiiii-eth/hakios-fajita/releases/tag/v0.1-beta
