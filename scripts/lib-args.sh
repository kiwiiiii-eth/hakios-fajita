# sourced by run-fajita.sh, run-darwin.sh, run-darwin-live.sh: the boot-arguments of a run, from the kernel repository $1
# and the kernel file $2. Sets ARGS and SOCARGS; returns 1 (a message on stderr) when the run must not go ahead.
#
# A kernel built with CONFIG_ARGS_BUILTIN=y carries the arguments only the kernel reads, and soc.args, inside itself,
# with a marker "hakios_builtin_args_sha=<16 hex>" that `strings` finds. The boot line then holds the others alone:
#   marker, same hash as `hakios-config.py builtin --sha` now  -> the retained arguments only, no SOCARGS
#   marker, other hash (or no way to compute one)             -> refused: the kernel's own words are not the configuration's,
#                                  and an argument the configuration dropped would still be there, so rebuild (make kernel)
#   no marker (an older kernel, or ARGS_BUILTIN off)          -> the whole line as before: `args --full` and SOCARGS
# A kernel repository without `builtin` or `--full` is an older one: its `args` already prints everything.
# Called as `resolve_args ... || exit 1`, where set -e does not reach into the function: every failure here is handled by hand.
resolve_args() {
	local k=$1 kernel=$2 line hash want
	ARGS=; SOCARGS=
	line=$(strings -a "$kernel" 2>/dev/null | grep -m1 '^hakios_builtin_args_sha=' || true)
	if [ -n "$line" ]; then
		hash=${line#hakios_builtin_args_sha=}
		want=$(cd "$k" && python3 tools/hakios-config.py builtin --sha 2>/dev/null) || want=
		[[ $want =~ ^[0-9a-f]{16}$ ]] || want=
		if [ -z "$want" ]; then
			echo "args: 核心內建了參數（hash ${hash}），但算不出目前設定應有的 hash（hakios-config.py builtin --sha 失敗或不存在），拒絕開跑：請在 ${k} 更新工具後 make kernel" >&2
			return 1
		fi
		if [ "$hash" != "$want" ]; then
			echo "args: 核心內建參數和目前設定不一致（核心 ${hash}，目前設定 ${want}），拒絕開跑：請先 make kernel" >&2
			return 1
		fi
		ARGS=$(cd "$k" && python3 tools/hakios-config.py args) || { echo "args: hakios-config.py args 失敗" >&2; return 1; }
		echo "args: 核心內建參數 hash ${hash} 與目前設定相符，boot line 只放保留參數"
	else
		ARGS=$(cd "$k" && python3 tools/hakios-config.py args --full 2>/dev/null) ||
			ARGS=$(cd "$k" && python3 tools/hakios-config.py args) || { echo "args: hakios-config.py args 失敗" >&2; return 1; }
		# the SoC's addresses (devices/fajita/soc.args, one name=value a line; # is a comment)
		SOCARGS=$(grep -v '^[[:space:]]*#' "$k/devices/fajita/soc.args" | tr '\n' ' ' | tr -s ' ')
		echo "args: 核心沒有內建參數標記，boot line 放完整參數＋soc.args"
	fi
	return 0
}
