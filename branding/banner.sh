#!/bin/sh
# /usr/local/bin/burmal-live-start
#
# Точка входа лайв-окружения
# Запускается на tty1 при загрузке с ISO/флешки

[ -r /etc/profile.d/00locale.sh ] && . /etc/profile.d/00locale.sh
export LANG=${LANG:-C.UTF-8}
export LC_ALL=${LC_ALL:-C.UTF-8}
if command -v setfont >/dev/null 2>&1; then
    for font in /usr/share/kbd/consolefonts/ter-c16n.psf.gz /usr/share/consolefonts/ter-c16n.psf.gz; do
        if [ -f "$font" ]; then setfont "$font" 2>/dev/null || true; break; fi
    done
fi

cols=$(stty size < /dev/tty 2>/dev/null | awk '{print $2}')
case "$cols" in ''|*[!0-9]*) cols=80 ;; esac
[ "$cols" -lt 40 ] 2>/dev/null && cols=80
printf '\033[3J\033[2J\033[H\033[1;32m'
awk -v target="$cols" '
    { art[NR] = $0; if (length($0) > max) max = length($0) }
    END {
        for (row = 1; row <= NR; row++) {
            line = art[row]
            while (length(line) < max) line = line " "
            for (col = 1; col <= target; col++) {
                source = int((col - 1) * max / target) + 1
                printf "%s", substr(line, source, 1)
            }
            printf "\n"
        }
    }
' <<'BANNER'
 ____  _   _ ____  __  __    _    _        ____   ___  ____
| __ )| | | |  _ \|  \/  |  / \  | |      |  _ \ / _ \/ ___|
|  _ \| | | | |_) | |\/| | / _ \ | |      | | | | | | \___ \
| |_) | |_| |  _ <| |  | |/ ___ \| |___   | |_| | |_| |___) |
|____/ \___/|_| \_\_|  |_/_/   \_\_____|  |____/ \___/|____/
BANNER
printf '\033[0m\n\n'
printf '\033[1;32mWelcome to BURMAL-DOS!\033[0m\n\n'
echo "The live system is ready."
echo
echo "  [1] Install BURMAL-DOS"
echo "  [2] Open a live console without installing"
echo
printf "Select an option [1]: "
read -r choice < /dev/tty
case "$choice" in
    2)
        export PS1='\u@\h:\w\$ '
        exec /bin/bash --noprofile --norc -i
        ;;
    *) exec sudo /usr/local/sbin/burmal-installer.sh ;;
esac
