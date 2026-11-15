# Hardware support

[← README](../README.md) · [How it boots](how-it-boots.md) · [Hardware support](hardware.md) · [The hard parts](hard-parts.md) · [Building from source](building.md) · [Changelog](../CHANGELOG.md) · [繁體中文](hardware.zh-TW.md)

What was seen on the phone in November 2026 (Beta 0.5), next to upstream HakiOS's reference phone (the POCO X5 Pro,
"redwood", Snapdragon 778G). The machine-readable list, with the kernel options behind each line, is
[`device.conf`](../device.conf). ✅ works · partial · ❌ not yet.

| Area | 6T | Upstream reference (redwood) | Notes |
|---|---|---|---|
| Lock screen, home screen, stock apps | ✅ | ✅ | SpringBoard, Settings, Safari (pages load: Beta 0.3), Health … |
| **Boots by itself (installed)** | ✅ | ✅ | `install.sh` (Beta 0.4): HakiOS in the boot partition of the slot Android does not use, the system image read from `darwin` behind a boot screen with a progress bar (Beta 0.5); Shut Down and Restart work; Android stays a `set_active` away |
| Clock and time zone | ✅ | — | The PMIC's real-time clock with a kept offset; the time zone from the cellular network (NITZ) |
| Touch, buttons | ✅ | ✅ | Synaptics S3706B (RMI4 over I2C), written for the 6T; read 120 times a second |
| All 8 CPU cores, frequency scaling | ✅ | ✅ | SDM845 OSM tables, load governor |
| GPU (OpenGL ES 3.2 via Mesa) | ✅ | ✅ | **Adreno 630 brought up from cold**, up to 60 fps |
| Wi-Fi | ✅ | ✅ | WCN3990 + Linux ath10k; join from Settings, **5 GHz ≈ 95–110 Mbps**; a known network is joined again by itself (auto-join) |
| Battery level | ✅ | ✅ | PMI8998 fuel gauge in the status bar |
| **Charging under this kernel** | ✅ | ❌ | 41 % → 64 % in one session, 1 A from USB |
| **Cellular: LTE registration and data** | ✅ | partial (no registration) | FarEasTone LTE, 4 bars, the carrier's name in the status bar; Safari over LTE, 88 MB down / 56 MB up with zero IPA errors (`ipa8=11`) |
| **Flashlight** | ✅ | partial | From Control Center's button |
| **Screen brightness** | ✅ | — | Settings and Control Center slider (DSI command mode) |
| Temperature guard | ✅ | partial | 21 sensors, GPU and CPU scale down with load |
| Vibration | ✅ | ✅ | PMI8998 LRA, on by default (stronger than an iPhone's; to be tuned) |
| **Storage** | ✅ | ✅ | `/private/var` is a 20 GB journaled HFS Plus volume in the partition `darwin` cut from userdata (Beta 0.5): kept on the flash, Settings shows the space and iPhone Storage counts it |
| Location | partial | — | The modem's GPS (QMI LOC) to Location Services (`gnss=1`): satellites tracked (23 in view indoors), Location Services turned on by itself, Safari's geolocation gets a position; Apple Maps needs an activated device |
| **Sound (speaker)** | ✅ | ✅ | iOS sounds, keyboard clicks, YouTube: ADSP → I2S → TFA9894 amplifier (bypass); limited to −20 dBFS for the speaker's safety; on by default |
| **Microphone** | ✅ | ✅ | Voice Memos records: the bottom microphone (AMIC4) → WCD9340 codec → SLIMbus → ADSP; powered only while something records |
| Cameras | ❌ | ✅ | Not started |
| Bluetooth | partial | ❌ | WCN3990 over UART: iOS turns Bluetooth on, scans and pairs with a Mac (`bt=4`); **BLE keyboards pair and type** (BTLEServer, HID over GATT); pairings are not kept across reboots |
| SSH | ✅ | ✅ | `sshd` with your own key (`RC_JOBS=rc.jobs.ssh6t`); `neofetch` preinstalled and shown at login |
