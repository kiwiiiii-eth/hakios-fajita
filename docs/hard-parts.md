# The hard parts

[← README](../README.md) · [How it boots](how-it-boots.md) · [Hardware support](hardware.md) · [The hard parts](hard-parts.md) · [Building from source](building.md) · [Changelog](../CHANGELOG.md) · [繁體中文](hard-parts.zh-TW.md)

The bugs that took the longest, written down for the next SDM845 port:

| Problem | Cause | Fix |
|---|---|---|
| The kernel stopped right after the framebuffer came up | XNU hard-codes the EL1 virtual timer as interrupt 27; on SDM845 it is **19** | `gic_vtimer=` boot argument (`CONFIG_GIC_VTIMER=19` in `soc/configs/sdm845.config`) |
| Touch only worked with the USB cable unplugged | USB noise; the controller has a "charger connected" bit (F01 ctrl0 bit 5) | The driver reads USBIN from the PMIC every 0.5 s and sets the bit |
| GMU powered the GPU but never set the PLL | The A630's GMU firmware wants chip ID **0x06030200** (630.2), not the device tree's 0x06030000; RSCC/PDC must be programmed *before* the GMU starts | Both fixed; then DCVS votes, without which every GPU wait took 70–185 ms |
| The phone crashed to Qualcomm CrashDump 0.4 s after the modem's MBA got its header | Read the TrustZone diag log out of a CrashDump with EDL: a **NoC error** at `QDSP6SS_SLEEP`. Our own debug read touched QDSP6SS after the MBA had locked it with an XPU | No QDSP6SS access after the header is handed over (Linux never reads it either) |
| Modem up, but no Wi-Fi firmware service | The modem asserted when we pre-allocated the IPA SMEM item or mentioned IPA at all | GLINK SMEM items 478/479 allocated as Linux does, IPA left out entirely |
| Wi-Fi WMI timeouts, now and then | A NAPI poll racing the interrupt: a schedule arriving mid-poll was dropped and that copy engine's interrupt stayed masked | Linux's "missed" semantics in our NAPI |
| Joined, WPA2 done, but stuck at 169.254 | The `lx_transmit` entry point was still a placeholder returning `ENETDOWN` | Wired to the station's send path; DHCP, Safari |
| Battery drained while plugged in | ABL leaves the input limit at 500 mA and the charge current at **0** | Set both to 1 A (with read-back and a 45 °C cut-off) |
| Wi-Fi died about 2 minutes after LTE registered | The modem asserted in its LTE downlink (`ipa_dl_opt_lte.c: IPA Assert new_free_space > 0`): with no IPA set up it had nowhere to put packets, and the Wi-Fi firmware runs on the modem | Bring up the IPA; until it is, the modem stays offline by default |
| QCOM CrashDump right after TrustZone started the IPA firmware | The IPA init we started from writes **IPA v4.11** register offsets; the SDM845 has **v3.5.1**, the writes land elsewhere and hang the bus. Before that, TrustZone refused a `.mdt` that kept the mbn's padding between the program headers and the hash segment | v3.5.1 layouts throughout; a tight `.mdt`; Linux's bus votes before the authentication |
| Registered on LTE, but every data call refused with "no service" | Left in the modem from Android: the data switch **off** and the default data SIM on **slot 2** | Two DSD writes (with consent, in the modem's memory only); the SIM provisioned as postmarketOS does it, without a slot switch |
| Safari's pages spun for ever, though the network worked | `mobileactivationd` traps at every start on this phone and never answers what is queued for it; `apsd` asks it while starting, `amsaccountsd` asks `apsd`, and Safari's main thread waited on AppleMediaServices (found with a stackshot of Safari's threads) | The daemon is left out (`mkjobs.py` DENY); everything that asks it gets its error at once |
| A known Wi-Fi network was never joined again by itself | wifid reads the auto-join RSSI floor once from the driver (`APPLE80211_IOC_RSSI_BOUNDS`); refused, the floor stayed **0 dBm** and every network was "Below minimum RSSI threshold" — found by disassembling `wifid` | The driver answers it (-90 / -20 dBm, floor -80); and a power-on asked for before the radio is up is taken, not refused |
| Settings said the phone held 1 GB | `/private/var` was a memory filesystem (a quarter of the RAM), packed into `darwin` as the system shut down | An HFS Plus volume in `darwin` past the packed store's slots; the store moved into it once, and only when it comes back whole |
| iPhone Storage stayed empty | It counts the root's space, and the root is the read-only system image (2.6 GB, nothing free) | The root reports the data volume's space (`vfs_getattr`), as an iPhone's root shares its container's |
| The clock went back hours after a forced restart | The PMIC's real-time clock started counting from zero again after the phone was got out of a stuck loader, and the kept offset then pointed hours back | The offset is kept with its count; a count that went back, or a clock that would, leaves the time as the image has it |
| The carrier's name showed as four boxes | iOS draws it in PingFang's Medium weight, which the trimmed system font had dropped | Medium kept |
