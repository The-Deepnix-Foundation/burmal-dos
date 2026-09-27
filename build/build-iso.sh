#!/bin/bash
# Build the BURMAL-DOS live ISO.
set -euo pipefail

ARCH="${ARCH:-x86_64}"
BURMAL_REPOSITORY="${BURMAL_REPOSITORY:-https://repo-default.voidlinux.org/current}"
BURMAL_SRC="${BURMAL_SRC:-$(cd "$(dirname "$0")/.." && pwd)}"
BURMAL_BUILDER="${BURMAL_BUILDER:-/opt/burmal-builder}"
REAL_OUTDIR="${OUTDIR:-$BURMAL_SRC/out}"
WORKDIR="${WORKDIR:-/tmp/burmal-build}"
INCLUDE_DIR="$WORKDIR/include"

[[ $(id -u) -eq 0 ]] || { echo "Build the BURMAL-DOS ISO as root (Docker does this automatically)." >&2; exit 1; }
[[ -x "$BURMAL_BUILDER/mklive.sh" ]] || { echo "BURMAL-DOS builder not found at $BURMAL_BUILDER" >&2; exit 1; }
[[ -d "$BURMAL_SRC" ]] || { echo "BURMAL_SRC not found: $BURMAL_SRC" >&2; exit 1; }
case "$WORKDIR" in
    /|/tmp|"$BURMAL_SRC"|"$BURMAL_BUILDER")
        echo "Unsafe build work directory: $WORKDIR" >&2
        exit 1 ;;
esac

rm -rf -- "$WORKDIR"
mkdir -p "$INCLUDE_DIR/usr/local/bin" \
    "$INCLUDE_DIR/usr/local/sbin" \
    "$INCLUDE_DIR/usr/share/burmal-dos/gui" \
    "$INCLUDE_DIR/usr/share/burmal-dos/branding" \
    "$INCLUDE_DIR/etc/profile.d" \
    "$REAL_OUTDIR"

install -m755 "$BURMAL_SRC/dpx/dpx" "$INCLUDE_DIR/usr/local/bin/dpx"
install -m755 "$BURMAL_SRC/branding/banner.sh" "$INCLUDE_DIR/usr/local/bin/burmal-live-start"
cat > "$INCLUDE_DIR/usr/local/sbin/burmal-live-login" <<'LOGIN'
#!/bin/sh
exec /bin/login -f burmal
LOGIN
chmod 755 "$INCLUDE_DIR/usr/local/sbin/burmal-live-login"
install -m755 "$BURMAL_SRC/branding/fastfetch.sh" "$INCLUDE_DIR/usr/local/bin/fastfetch"
install -m755 "$BURMAL_SRC/installer/burmal-installer.sh" "$INCLUDE_DIR/usr/local/sbin/burmal-installer.sh"
install -m644 "$BURMAL_SRC/gui/burmal-gui.py" "$INCLUDE_DIR/usr/share/burmal-dos/gui/burmal-gui.py"
install -m755 "$BURMAL_SRC/gui/burmal-gui" "$INCLUDE_DIR/usr/share/burmal-dos/gui/burmal-gui"
install -m755 "$BURMAL_SRC/gui/burmal-gui-session" "$INCLUDE_DIR/usr/share/burmal-dos/gui/burmal-gui-session"
install -m644 "$BURMAL_SRC/branding/fastfetch-config.jsonc" "$INCLUDE_DIR/usr/share/burmal-dos/branding/config.jsonc"
install -m644 "$BURMAL_SRC/branding/fastfetch-config-stacked.jsonc" "$INCLUDE_DIR/usr/share/burmal-dos/branding/config-stacked.jsonc"
install -m644 "$BURMAL_SRC/branding/fastfetch-config-compact.jsonc" "$INCLUDE_DIR/usr/share/burmal-dos/branding/config-compact.jsonc"
install -m644 "$BURMAL_SRC/branding/fastfetch-logo.txt" "$INCLUDE_DIR/usr/share/burmal-dos/branding/fastfetch-logo.txt"
install -m644 "$BURMAL_SRC/branding/fastfetch-logo-compact.txt" "$INCLUDE_DIR/usr/share/burmal-dos/branding/fastfetch-logo-compact.txt"
install -m644 "$BURMAL_SRC/branding/os-release" "$INCLUDE_DIR/usr/share/burmal-dos/branding/os-release"
install -m644 "$BURMAL_SRC/branding/motd" "$INCLUDE_DIR/usr/share/burmal-dos/branding/motd"
install -m644 "$BURMAL_SRC/branding/issue" "$INCLUDE_DIR/usr/share/burmal-dos/branding/issue"
install -m644 "$BURMAL_SRC/branding/burmal-splash-menu.png" "$INCLUDE_DIR/usr/share/burmal-dos/branding/burmal-splash-menu.png"
install -m644 "$BURMAL_SRC/branding/runit-1" "$INCLUDE_DIR/usr/share/burmal-dos/branding/runit-1"
install -m644 "$BURMAL_SRC/branding/vconsole.conf" "$INCLUDE_DIR/usr/share/burmal-dos/branding/vconsole.conf"
install -m644 "$BURMAL_SRC/branding/xbps-dpx-repositories" "$INCLUDE_DIR/usr/share/burmal-dos/branding/xbps-dpx-repositories"

# Use a plain green background for the BIOS/UEFI boot menus.
install -m644 "$BURMAL_SRC/branding/burmal-splash-menu.png" "$WORKDIR/burmal-splash-menu.png"

cat > "$INCLUDE_DIR/etc/profile.d/burmal-live.sh" <<'PROFILE'
if [ -r /etc/burmal-live ] && [ -z "${BURMAL_LIVE_MENU_SHOWN:-}" ] && [ "$(tty 2>/dev/null)" = /dev/tty1 ]; then
    export BURMAL_LIVE_MENU_SHOWN=1
    exec /usr/local/bin/burmal-live-start
fi
PROFILE
chmod 644 "$INCLUDE_DIR/etc/profile.d/burmal-live.sh"

export BURMAL_REPOSITORY BURMAL_SRC
export SPLASH_IMAGE="$WORKDIR/burmal-splash-menu.png"
LIVE_PACKAGES="base-system bash dialog parted e2fsprogs dosfstools btrfs-progs xfsprogs grub grub-i386-efi grub-x86_64-efi efibootmgr sudo shadow util-linux kbd terminus-font glibc-locales tzdata NetworkManager dbus wpa_supplicant xrandr spice-vdagent"
LIVE_SERVICES="dbus NetworkManager"

echo "==> Building the BURMAL-DOS live image"
echo "    architecture: $ARCH"
echo "    repository:   $BURMAL_REPOSITORY"

# The live image builder's default live.autologin option adds agetty's -a flag, which
# prints a visible automatic-login diagnostic. Use a quiet, prompt-free login
# program instead, and set the initramfs hostname to our own distribution.
LIVE_USER_HOOK="$BURMAL_BUILDER/dracut/vmklive/adduser.sh"
sed -i -E \
    's|echo [^ ]+ > \$\{NEWROOT\}/etc/hostname|echo burmal-dos > ${NEWROOT}/etc/hostname|' \
    "$LIVE_USER_HOOK"
grep -Fq 'echo burmal-dos > ${NEWROOT}/etc/hostname' "$LIVE_USER_HOOK" || {
    echo "ERROR: could not patch live hostname hook." >&2
    exit 1
}
# Brand the ISO filesystem label as well as both bootloader command lines.
# GNOME Boxes derives its VM title from this label on some versions.
sed -i 's/VOID_LIVE/BURMAL_DOS/g' \
    "$BURMAL_BUILDER/mklive.sh" \
    "$BURMAL_BUILDER/isolinux/isolinux.cfg.in"
# Remove upstream branding from generated GRUB configuration names and variables.
for part in pre post; do
    old="$BURMAL_BUILDER/grub/grub_void.cfg.$part"
    new="$BURMAL_BUILDER/grub/grub_burmal.cfg.$part"
    if [[ -f "$old" ]]; then mv "$old" "$new"; fi
    [[ -f "$new" ]] || { echo "Missing GRUB template: $new" >&2; exit 1; }
done
for grub_file in "$BURMAL_BUILDER/mklive.sh" "$BURMAL_BUILDER/grub/grub.cfg" \
    "$BURMAL_BUILDER/grub/grub_burmal.cfg.pre" "$BURMAL_BUILDER/grub/grub_burmal.cfg.post"; do
    sed -i -e 's/grub_void/grub_burmal/g' -e 's/voidlive/burmallive/g' "$grub_file"
done
# Expose the EFI loaders in the ISO filesystem too. The El Torito EFI image
# remains in place for optical boot, while firmware and USB writers that look
# for the removable-media path can use /EFI/BOOT/BOOTX64.EFI directly.
if ! grep -Fq '# BURMAL_EFI_TREE_COPY' "$BURMAL_BUILDER/mklive.sh"; then
awk '
$0 == "generate_iso_image" {
    print "# BURMAL_EFI_TREE_COPY"
    print "if [ -f \"$IMAGEDIR/boot/grub/efiboot.img\" ]; then"
    print "    EFI_TREE_TMPDIR=$(mktemp -d --tmpdir=\"$BUILDDIR\" burmal-efi.XXXXXX)"
    print "    mount -o loop,ro \"$IMAGEDIR/boot/grub/efiboot.img\" \"$EFI_TREE_TMPDIR\""
    print "    cp -a \"$EFI_TREE_TMPDIR/EFI\" \"$IMAGEDIR/\""
    print "    umount \"$EFI_TREE_TMPDIR\""
    print "    rmdir \"$EFI_TREE_TMPDIR\""
    print "fi"
}
{ print }
' "$BURMAL_BUILDER/mklive.sh" > "$WORKDIR/mklive.sh"
chmod --reference="$BURMAL_BUILDER/mklive.sh" "$WORKDIR/mklive.sh"
mv "$WORKDIR/mklive.sh" "$BURMAL_BUILDER/mklive.sh"
fi

cd "$BURMAL_BUILDER"
./mklive.sh \
    -a "$ARCH" \
    -k us \
    -l ru_RU.UTF-8 \
    -T BURMAL-DOS \
    -o "$WORKDIR/BURMAL-DOS.iso" \
    -p "$LIVE_PACKAGES" \
    -S "$LIVE_SERVICES" \
    -I "$INCLUDE_DIR" \
    -x "$BURMAL_SRC/build/burmal-postsetup.sh" \
    -C "quiet loglevel=3 live.autologin live.user=burmal"

# The image builder currently does not fail when loop mounts fail: it can emit an
# ISO containing a tiny, empty squashfs. Inspect the root filesystem payload
# before publishing the image.
xorriso -osirrox on -indev "$WORKDIR/BURMAL-DOS.iso" \
    -extract /LiveOS/squashfs.img "$WORKDIR/squashfs.img" >/dev/null 2>&1
SQUASHFS_BYTES=$(stat -c '%s' "$WORKDIR/squashfs.img")
if (( SQUASHFS_BYTES < 33554432 )); then
    echo "ERROR: Live root filesystem payload is unexpectedly small (${SQUASHFS_BYTES} bytes)." >&2
    echo "The BURMAL-DOS ISO was not copied to the output directory." >&2
    exit 1
fi

install -m644 "$WORKDIR/BURMAL-DOS.iso" "$REAL_OUTDIR/BURMAL-DOS.iso"
echo "==> Created $REAL_OUTDIR/BURMAL-DOS.iso"
ls -lh "$REAL_OUTDIR/BURMAL-DOS.iso"
