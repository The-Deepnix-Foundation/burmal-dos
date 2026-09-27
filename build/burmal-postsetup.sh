#!/bin/sh
# Configure the rootfs produced by builder before its initramfs.
set -eu

ROOTFS="$1"
BURMAL_SRC="${BURMAL_SRC:-/work/burmal-dos}"
BURMAL_REPOSITORY="${BURMAL_REPOSITORY:-https://repo-default.voidlinux.org/current}"
BRANDING="$ROOTFS/usr/share/burmal-dos/branding"

mkdir -p "$ROOTFS/etc/fastfetch" "$ROOTFS/etc/dpx" "$ROOTFS/etc/xbps.d"
cp "$BRANDING/os-release" "$ROOTFS/usr/lib/os-release"
cp "$BRANDING/runit-1" "$ROOTFS/etc/runit/1"
chmod 755 "$ROOTFS/etc/runit/1"
cp "$BRANDING/vconsole.conf" "$ROOTFS/etc/vconsole.conf"
cp "$BRANDING/issue" "$ROOTFS/etc/issue"
cp "$BRANDING/issue" "$ROOTFS/etc/issue.net"
cp "$BRANDING/motd" "$ROOTFS/etc/motd"
install -d "$ROOTFS/etc/xbps.d"
sed "s|\${BURMAL_REPOSITORY}|$BURMAL_REPOSITORY|g" "$BRANDING/xbps-dpx-repositories" > "$ROOTFS/etc/xbps.d/20-burmal-channels.conf"
cp "$BRANDING/config.jsonc" "$ROOTFS/etc/fastfetch/config.jsonc"
cp "$BRANDING/config-stacked.jsonc" "$ROOTFS/etc/fastfetch/config-stacked.jsonc"
cp "$BRANDING/config-compact.jsonc" "$ROOTFS/etc/fastfetch/config-compact.jsonc"
cp "$BRANDING/fastfetch-logo.txt" "$ROOTFS/usr/share/burmal-dos/fastfetch-logo.txt"
cp "$BRANDING/fastfetch-logo-compact.txt" "$ROOTFS/usr/share/burmal-dos/fastfetch-logo-compact.txt"
printf 'burmal-dos\n' > "$ROOTFS/etc/hostname"
printf 'BURMAL_REPOSITORY=%s\n' "$BURMAL_REPOSITORY" > "$ROOTFS/etc/burmal-repository"
printf 'DPX_BACKEND=xbps\n' > "$ROOTFS/etc/dpx/dpx.conf"
printf 'repository=%s\n' "$BURMAL_REPOSITORY" > "$ROOTFS/etc/xbps.d/00-repository-main.conf"
touch "$ROOTFS/etc/burmal-live"

# Start the live menu without printing agetty's automatic-login notice or
# the upstream live issue. This agetty version invokes the shell login helper
# directly while preserving tty ownership and console job control.
mkdir -p "$ROOTFS/etc/sv/agetty-tty1"
cat > "$ROOTFS/etc/sv/agetty-tty1/conf" <<'GETTY'
GETTY_ARGS="--noclear --noissue --skip-login --login-program=/usr/local/sbin/burmal-live-login"
BAUD_RATE=38400
TERM_NAME=linux
GETTY

mkdir -p "$ROOTFS/usr/sbin"
cat > "$ROOTFS/usr/sbin/setup-b-d" <<'SETUP'
#!/bin/sh
exec /usr/local/sbin/burmal-installer.sh "$@"
SETUP
chmod 755 "$ROOTFS/usr/sbin/setup-b-d"

# Keep the live system's package database and network manager on BURMAL-DOS.
ln -snf /etc/sv/udevd "$ROOTFS/etc/runit/runsvdir/default/udevd"
ln -snf /etc/sv/dbus "$ROOTFS/etc/runit/runsvdir/default/dbus"
ln -snf /etc/sv/NetworkManager "$ROOTFS/etc/runit/runsvdir/default/NetworkManager"

# Run the selected keyboard map and console font on each boot.
mkdir -p "$ROOTFS/etc/sv/burmal-console"
cat > "$ROOTFS/etc/sv/burmal-console/run" <<'SERVICE'
#!/bin/sh
[ -r /etc/vconsole.conf ] && . /etc/vconsole.conf
[ -n "${KEYMAP:-}" ] && /usr/bin/loadkeys "$KEYMAP" >/dev/null 2>&1 || true
if [ -n "${FONT:-}" ] && command -v setfont >/dev/null 2>&1; then
    font=$(find /usr/share/kbd/consolefonts /usr/share/consolefonts -name "${FONT}.psf*" -print -quit 2>/dev/null)
    [ -n "$font" ] && setfont "$font" >/dev/null 2>&1 || true
fi
exec /usr/bin/sleep infinity
SERVICE
chmod 755 "$ROOTFS/etc/sv/burmal-console/run"
ln -snf /etc/sv/burmal-console "$ROOTFS/etc/runit/runsvdir/default/burmal-console"
