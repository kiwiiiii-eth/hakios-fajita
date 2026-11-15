#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static struct { uint64_t base; uint32_t width, height, stride; } SCREEN;
static char log_buf[32768];
static uint32_t log_len;
static int screen_quiet;
static size_t str_len(const char *s) { return strlen(s); }
#include "bootscreen.c"
int main(int argc, char **argv)
{
	int mode = atoi(argv[1]);               /* 1 facts, 2 log */
	uint64_t total = 2665914368ULL;
	SCREEN.width = 1080; SCREEN.height = 2340; SCREEN.stride = 1080 * 4;
	SCREEN.base = (uint64_t)(uintptr_t)calloc(1, (size_t)SCREEN.stride * SCREEN.height);
	const char *lg = "ufs: unit 0: media 1, 30437376 blocks of 4096 (118896 MB), writable, align 4096\n"
	    "ufs: unit 0: GPT header crc right (b4d6ca6a), table of 32 entries crc right (2526d0b4)\n"
	    "ufs: part userdata: lba 1601344..22048255, 81787648 KB\n"
	    "ufs: part darwin: lba 22048256..30437370, 33556460 KB\n"
	    "sysimg: reading 2665914368 bytes from darwin\n";
	strcpy(log_buf, lg); log_len = strlen(lg);
	bs_info_set(BS_INFO_PHONE, "OnePlus 6T (fajita)"); bs_info_add(BS_INFO_PHONE, "  \x7f  slot a");
	bs_info_set(BS_INFO_STORAGE, "storage: LUN 0 "); bs_info_size(BS_INFO_STORAGE, 30437376ULL * 4096);
	bs_info_set(BS_INFO_KERNEL, "kernel "); bs_info_size(BS_INFO_KERNEL, 17248400);
	bs_info_add(BS_INFO_KERNEL, "  \x7f  root "); bs_info_size(BS_INFO_KERNEL, 4194304);
	bootscreen_begin(mode == 2 ? "bootscreen=log" : "", total);
	bootscreen_progress(0, total * 62 / 100, total);
	fwrite((void *)(uintptr_t)SCREEN.base, 1, (size_t)SCREEN.stride * SCREEN.height, stdout);
	return 0;
}
