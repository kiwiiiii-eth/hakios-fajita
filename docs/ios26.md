# iOS 26 on the OnePlus 6T (debug build, in progress)

[繁體中文](ios26.zh-TW.md)

> [!WARNING]
> **A debug build for development, not a Beta for everyday use.** There is no kit and no `setup.sh`: it is booted from a
> Mac into RAM only. For a phone to use, take [iOS 16.5, Beta 0.8.1](../releases/v0.8.1-beta.md).

iOS **26.5.2** (23F84, the iPhone 11 IPSW) on the same open-source XNU: the kernel moved to xnu-12377.121.6, with every
6T driver carried over. Sources: the [`ios26` branch of hakios-xnu-kernel](https://github.com/kiwiiiii-eth/hakios-xnu-kernel/tree/ios26).

## Status (2026-11-28)

✅ works · 🟡 partly · ❌ not yet

| | Feature | | Notes |
|---|---|:---:|---|
| **System** | Boot, lock screen, home screen, Settings | ✅ | Booted from a Mac into RAM; the system image on `userdata` |
| | Start time | 🟡 | 2–3 minutes to the lock screen (the app database is rebuilt every time) |
| | Data kept | ❌ | `/private/var` is empty at every start |
| | Keychain | ✅ | Read and written |
| **Display** | Touch, buttons | ✅ | |
| | GPU | 🟡 | iOS 26 draws with Metal only; here its renderer is swapped for OpenGL ES (Mesa, Adreno 630) |
| | Flicker, glowing labels, green stripes | ✅ | Fixed |
| | Smoothness | 🟡 | Clearly laggy |
| | Some sheets | 🟡 | The Wi‑Fi password sheet is drawn incompletely |
| | Settings icons | 🟡 | Missing on the Wi‑Fi, Bluetooth, Hotspot, Battery and Camera rows |
| **Connectivity** | Wi‑Fi scan | ✅ | |
| | Wi‑Fi, open networks | ✅ | Joined, an address from DHCP (20 MHz) |
| | Wi‑Fi, WPA2 (password) | ❌ | "Incorrect password": iOS 26 gives up before it sends the join; being looked into |
| | Bluetooth | 🟡 | `bluetoothd` starts; pairing not tried yet |
| | Cellular | ❌ | Not started |
| **Other** | Audio | ❌ | The driver is there; not tried yet |
| | Cameras | ❌ | Not started |
| | Apple services | ❌ | Need an activated device; not a goal |

## What is different from 16.5

| | iOS 16.5 | iOS 26 |
|---|---|---|
| Compositing | QuartzCore supports OpenGL ES itself | Metal only; its renderer is swapped back for the OpenGL ES one it still carries |
| System programs | Run as they are | arm64e instructions rewritten first (our `pac_lower`): about 29 million in the system cache |
| Wi‑Fi interface | IO80211's old formats | Bigger scan, join and event structures, matched one by one |

## Next

1. Wi‑Fi with a password: find the request iOS 26 is refused before it gives up on the join
2. The incomplete password sheet; the lag
3. Bluetooth pairing, audio
4. Cellular (CommCenter), cameras
