#!/bin/sh
FASTFETCH=/usr/bin/fastfetch
[ -x "$FASTFETCH" ] || { echo "fastfetch is not installed; run: sudo dpx install fastfetch" >&2; exit 127; }

config=/etc/fastfetch/config-compact.jsonc
if [ -t 1 ]; then
    dimensions=$(stty size < /dev/tty 2>/dev/null || echo '24 80')
    rows=${dimensions%% *}
    cols=${dimensions#* }
    case "$rows:$cols" in *[!0-9:]*|'') rows=24; cols=80 ;; esac
    if [ "$cols" -ge 115 ] && [ "$rows" -ge 30 ]; then
        config=/etc/fastfetch/config.jsonc
    elif [ "$cols" -ge 68 ] && [ "$rows" -ge 48 ]; then
        config=/etc/fastfetch/config-stacked.jsonc
    fi
fi
exec "$FASTFETCH" --config "$config" "$@"
