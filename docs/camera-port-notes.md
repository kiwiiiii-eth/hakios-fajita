# Camera port notes (working notes, OnePlus 6T)

Facts gathered for porting upstream's `drivers/camera/hakios.camera.c` (POCO X5 Pro, SM7325) to the 6T (SDM845).
Sources: the phone's own dtbo (slot a, overlay 10 = project 0x4971 rev 0x29 "PVT/MP"; the 6T's overlays are 06..12 and
their camera nodes are the same), LineageOS's fajita boot image (base DTB, SDM845 v2.1), mainline Linux
(`camcc-sdm845.c`, `camss-*`), OnePlus's msm-4.9 camera driver (LineageOS/android_kernel_oneplus_sdm845, read as data),
and the sensor module files of the phone's vendor partition (`/vendor/lib/camera/com.qti.sensormodule.*.bin`).
References are in `../ref-linux/camera/` (not in this repository).

## Sensors

| | rear 0 (main) | rear 1 (second) | front |
|---|---|---|---|
| Sensor | Sony IMX519, 16 MP, LiteOn module | Sony IMX376K, 20 MP | Sony IMX371, 16 MP |
| Module file | `liteon_imx519_lc898217xc_actuator` (or `_sa3103_`) | `liteon_imx376k_lc898217xc_actuator` (or `_sa3103_`) | `liteon_imx371` |
| Tuning | `semco_imx519` | `semco_imx376k` | `oflim_imx371` |
| CSIPHY | 0 | 1 | 2 |
| PHY | **C-PHY, 3 trios** | (see module) | D-PHY, 4 lanes |
| CCI master | 0 (GPIO 17 SDA, 18 SCL) | 1 (GPIO 19 SDA, 20 SCL) | 0 (GPIO 17/18) |
| MCLK | MCLK0, GPIO 13, 24 MHz | MCLK2, GPIO 15, 24 MHz | MCLK1, GPIO 14, 24 MHz |
| Reset | GPIO 28 | GPIO 23 | GPIO 9 |
| VANA enable | GPIO 27 (an LDO fed from BOB) | GPIO 78 | GPIO 104 |
| VDIG enable | GPIO 8 | GPIO 79 | GPIO 117 |
| VIO | PM8998 LVS1 (1.8 V switch, RPMh) | same | same |
| VAF (lens motor) | GPIO 31 switches a fixed 2.8 V regulator from BOB | GPIO 77, same | none |
| OIS | rear 0: CCI master 0, VAF from PM8998 L21 2.85 V, GPIO 40 | | |
| EEPROM | `imx519` OTP on CCI 0 | on CCI 1 | `imx371_cat24c32` on CCI 0 |
| Mount (roll/yaw) | 270 / 180 | 90 / 180 | 270 / 0 |

Every sensor's VANA and VDIG come from BOB (PMI8998, 3.312-3.6 V in the device tree) through a regulator switched by a
TLMM GPIO; Android also votes BOB's mode (the loads in the device tree). Pins: GPIO function 0, 2 mA, no pull; MCLK
pins function 1 (cam_mclk), 2 mA. CCI pins (base DTB) GPIO 17-20, function cci_i2c.

## Module files (CamX "Parameter Parser V1.1.0")

Upstream's `tools/camsensor.py` reads V3.0.1 (SM7325). The 6T's are V1.1.0:
- Header: at 0x9c the number of entries, at 0xa0 entries of 3 words { id, offset, size }: 0 the symbol table, 1 the data pool.
- A symbol is 0x40 bytes: { id u32, name[32], kind, ?, ?, ?, parent, offset, size } (V3: 0x38, two words fewer).
- Values in structures are symbol ids (strings, arrays), as in V3.
- `sensorDriverData` (392 bytes, pool+20): V3's words shifted by -2: w5 slave (8-bit), w6 address bytes, w7 data bytes,
  w8 id address, w9 id, w10 id mask, w11 I2C mode, w12/w13 power-up count/symbol, w14/w15 power-down; w16.. register
  addresses (frame length 0x340, line length 0x342, coarse integration 0x202, gain 0x204 ...), colour levels (white
  0x3ff, black 0x40), pixel array (IMX371: 4608 x 3456).
- `resolutionData`: 112 bytes per mode (V3: 196): w0 colour filter (CamX order), w1/w2 stream count/symbol
  (`streamConfiguration`, 32 bytes each: vc, data type, x, y, width, height, ...), w3 line length, w4 frame length,
  w7 output pixel clock, double at byte 40 fps, w12 lanes (trios with C-PHY), w14 settle, w15 C-PHY, w18/w19 the mode's
  register table count/symbol.
- Register tables: 40-byte elements as in V3; the order after `regToRealGain` (on, off, hold on, hold off),
  `initSettings` (init), `testPatternData` (tpg) as in V3.

## Camera subsystem (Titan 170, CPAS hw ver 0x170110)

| Block | Address | Notes |
|---|---|---|
| camcc | 0x0ad00000 | PLLs (Fabia) at 0x0, 0x1000, 0x2000, 0x3000 |
| titan top GDSC | camcc + 0xb134 | |
| CPAS (titan top) | 0x0ac40000 | |
| CCI | 0x0ac4a000 (0x4000) | two masters |
| CSIPHY 0/1/2 | 0x0ac65000, 0x0ac66000, 0x0ac67000 | "csiphy-v1.0" (3-phase: D-PHY and C-PHY); supply `mipi-csi-vdd` = PM8998 L1 at 0.88 V (the property csi-vdd-voltage says 1.2 V) and refgen (0xff1000), both shared with the display's DSI PHY: looked at, not switched |
| CSID 0 / 1 / lite | 0x0acb3000 / 0x0acba000 / 0x0acc8000 | |
| VFE 0 / 1 / lite | 0x0acaf000 / 0x0acb6000 / 0x0acc4000 | |

camcc (mainline camcc-sdm845.c):
- PLL0 L 0x1f alpha 0x4000 (600 MHz), PLL1 L 0x2a alpha 0x1556, PLL2 L 0x32 (960 MHz, out_even 480), PLL3 L 0x14 (384).
- MCLK0-3 RCG 0x4004 / 0x4024 / 0x4044 / 0x4064, branches 0x401c / 0x403c / 0x405c / 0x407c.
  24 MHz = PLL2 out_even (source 1? see the parent map), divider 10, M/N 1/2. 19.2 MHz = the crystal.
- csi0-3 phytimer RCG 0x5004 / 0x5028 / 0x504c / 0x5070 (19.2 or 240 MHz from PLL2 even /2, 269.3 from PLL1 even /3);
  their branches 0x501c / 0x5040 / 0x5064 / 0x5088; csiphy0-3 branches 0x5020 / 0x5044 / 0x5068 / 0x508c.
- cphy_rx RCG 0x9060 (384 MHz from PLL3 even).
- IFE lite RCG 0xb004 (480 MHz from PLL2 even, a rate of ftbl_cam_cc_ife_0_clk_src), IFE lite CSID RCG 0xb024 (384 from PLL3); branches ife_lite 0xb01c, ife_lite_csid 0xb03c, ife_lite_cphy_rx 0xb044.
- CCI RCG 0xb0d8 (37.5 MHz from PLL0 even /16), branch 0xb0f0.
- slow AHB RCG 0x6054, fast AHB RCG 0x6038; cpas_ahb 0xb11c, camnoc_axi 0xb124, soc_ahb 0xb13c.
- GDSCs: bps 0x6004, ipe0 0x7004, ipe1 0x8004, ife0 0x9004, ife1 0xa004, titan top 0xb134.
- The device tree's rates: csiphy timer 269.333 MHz ("turbo"), cphy_rx 384 MHz, CCI 37.5 MHz.

## The port (2026-11-15, compiled, not yet run on the phone)

| What | Where |
|---|---|
| The driver | `hakios-xnu-kernel/drivers/camera/hakios.camera845.c` (`CONFIG_HAKIOS_CAMERA845`, default n; `configs/fajita.config` has it on). hakios.camera.c's copy: the I2C by hand, the tables, CSID-lite, VFE-lite, the SMMU, the ring and `/dev/hakios-camera` are upstream's; the pins (three TLMM tiles), the supplies (GPIO-switched regulators, LVS1 and BOB through RPMh), camcc (Fabia PLL2/PLL3, SDM845's offsets), the CSIPHY (v1.0, D-PHY and C-PHY), the SMMU's streams and Sony's gain are the 6T's |
| Sensor indices | 0 the second rear (IMX376K), 1 the main (IMX519: the back camera Darwin takes), 2 the front (IMX371); `cam_sensor=main|second|front` |
| Module files → tables | `tools/camsensor.py` reads V1.1.0 too; `userland/build.sh` makes `camera-imx519.tab`, `camera-imx376k.tab`, `camera-imx371.tab` from `fw-camera/com.qti.sensormodule.<maker>_<sensor>*.bin` |
| Getting the module files | `pull-firmware.sh` (from a running Android, adb), or `scripts/pull-camera-modules.sh [a|b]` (through the loader: `oem readunit` of vendor_<slot> on unit 4 in 64 MB pieces, debugfs on the Mac; reads only). The developer's 6T has no Android boot image any more: vendor_b is at unit 4, blocks 408470..670613 |
| Preferred modes | main 2328x1746 (mode 10, 60 fps at most, C-PHY 3 trios), front 2304x1728 (mode 1, 30 fps, 4 lanes), second 2592x1940 (mode 0) |

## Running it (each level needs the user's OK: new TLMM, camcc, RPMh and SMMU writes from cam=2 on)

1. `scripts/pull-camera-modules.sh b` (reads only), then build userland so `fw/` carries the tables.
2. `cam=1`: reading only. Look at: LVS1 and BOB ready or not; DRV 2's votes on cx.lvl/mx.lvl/vsa1/bobb1 (the camera's
   TCS 1 must not overwrite somebody's); the SMMU's free match registers and contexts, and whether one covers the IFEs'
   streams; camcc's PLL2/PLL3 state (stopped, not in FSM mode); the pins.
3. `cam=2` (each sensor: `cam_sensor=main`, `front`, `second`): power-up, chip ID 0x0519 / 0x0371 / 0x0376, power-down.
4. `cam=3`: the CSID's test pattern into memory; `xl camera` and `tools/camraw.py` make a picture of it.
5. `cam=4 cam_sensor=front` (D-PHY first), then `main` (C-PHY): frames into memory. `cam_settle=N` if the PHY reports
   errors (`show_csiphy`'s status) or no packets come.
6. `cam=5`: Camera.app.

## Not known yet / not done

- The settle count: D-PHY from mainline's formula with the 240 MHz timer (the front camera's mode 1: 16, mode 0: 15; the
  second rear's: 15); C-PHY 0x12,
  Android's table's starting value. The module files' "14" is in CamX's units, not used.
- CX and MX are voted at NOM (conservative), from the sensor's power-up on (MCLK runs on PLL2) to the end, coordinated
  with the modem's and the audio DSP's boot votes in the same DRV (never lowered or removed; re-voted after their
  handover); MMNOC bandwidth is not voted (the display keeps the NOC up).
- LVS1 and BOB are voted only when found off, and given back only then (an apps-DRV vote somebody else made is never
  replaced by ours).
- The lens motor (LC898217XC or SA3103, CCI master 0) is not driven: fixed focus at the spring's position.
- Colour: the module files say RGGB for all three; no colour matrix or lens shading yet (the 6T's `com.qti.tuned.*.bin`
  are an older format than `tools/camtuning.py` reads). The sensors are mounted rotated (roll 270 / 90 / 270): the
  pictures may need turning.

## 2026-11-16: colour, focus, speed (r186-r199)

| What | Where it stands |
|---|---|
| Colour | the 6T's own tuning (com.qti.tuned.semco_imx519 / oflim_imx371 / semco_imx376k, in fw-camera/) through tools/camtuning.py: colour matrices, lens shading, the white balance's reference lights; the white balance may stay 0.15 (in logarithms) off the reference line, which bends on this phone |
| Front camera | the IMX371 is a Quad Bayer sensor: its whole array (4608x3456) is RRGG/RRGG/GGBB/GGBB, though its module file says RGGB (r189's raw frame), so only its binned 2304x1728 is used |
| Focus | the developer's main module has an SA3103 (0x0C on CCI master 0; 0x81 = 1, the position in 0x82/0x83, 12 bits); the LC898217XC modules' (0x72, 0x84, 11 bits) are tried first. VAF: GPIO 31 (main), GPIO 77 (second). A sweep (camera_test raw ... focus) peaks at 320-352 of 0-1023 for a wall 2-3 m off; the module's EEPROM (0x0000 on) holds values of 370-720 in the same units |
| Speed | the main camera's binned preview 29.9 frames a second (r199), its whole array (cam_full=1) about 20; photographs as JPEG (Settings, Camera, Formats, Most Compatible) 0.2 s to encode, HEVC 5 s |
| OIS | not driven: BU24218GWL at 0x3E (module file's 0x7C), PM8998 L21 2.85 V and GPIO 40; its init is a 2580-byte program at 0x0000-0x1DBF after 0xF010 = 0, then 38 bytes of calibration at 0x1DC0-0x1DE5 and 0xF006 from the module's EEPROM -- where in the EEPROM is not in the module file (OnePlus's library): not written |

