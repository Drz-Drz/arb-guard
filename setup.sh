#!/bin/sh
set -eu

GKI_ROOT="$(pwd)"
ARB_REPO="${ARB_GUARD_REPO:-https://github.com/Drz-Drz/arb-guard}"

echo "[+] Setting up ARB Guard (anti ARB-fuse burn)"

# locate security/ + include/
if [ -d "$GKI_ROOT/security" ]; then
    SECURITY_DIR="$GKI_ROOT/security"
elif [ -d "$GKI_ROOT/common/security" ]; then
    SECURITY_DIR="$GKI_ROOT/common/security"
else
    echo '[ERROR] "security/" directory not found.'
    exit 127
fi

if [ -d "$GKI_ROOT/include" ]; then
    INCLUDE_DIR="$GKI_ROOT/include"
elif [ -d "$GKI_ROOT/common/include" ]; then
    INCLUDE_DIR="$GKI_ROOT/common/include"
else
    echo '[ERROR] "include/" directory not found.'
    exit 127
fi

SECURITY_MAKEFILE="$SECURITY_DIR/Makefile"
SECURITY_KCONFIG="$SECURITY_DIR/Kconfig"
ARB_DIR="$GKI_ROOT/arb-guard"
ARB_SYMLINK="$SECURITY_DIR/arb-guard"

# clone the arb-guard repo if not already present
if [ ! -f "$ARB_DIR/arb_guard.c" ]; then
    echo "[+] Cloning arb-guard from $ARB_REPO"
    rm -rf "$ARB_DIR"
    git clone --depth=1 "$ARB_REPO" "$ARB_DIR" || true
fi

if [ ! -f "$ARB_DIR/arb_guard.c" ]; then
    echo '[ERROR] arb_guard.c not found after clone; aborting.'
    exit 1
fi

cd "$SECURITY_DIR"
if command -v realpath >/dev/null 2>&1; then
    rel="$(realpath --relative-to="$SECURITY_DIR" "$ARB_DIR" 2>/dev/null || true)"
else
    rel="$ARB_DIR"
fi
[ -z "$rel" ] && rel="$ARB_DIR"
ln -sfn "$rel" "$ARB_SYMLINK"
echo " - symlink created ($rel)"

if ! grep -q 'arb-guard/arb_guard.o' "$SECURITY_MAKEFILE"; then
    printf '\nobj-$(CONFIG_ARB_GUARD) += arb-guard/\n' >> "$SECURITY_MAKEFILE"
    echo " - Makefile updated"
fi

if ! grep -q 'security/arb-guard/Kconfig' "$SECURITY_KCONFIG"; then
    if grep -n '^endmenu[[:space:]]*$' "$SECURITY_KCONFIG" >/dev/null 2>&1; then
        awk '
          { a[NR]=$0 } END{
            last=0; for(i=1;i<=NR;i++) if(a[i] ~ /^endmenu[[:space:]]*$/) last=i;
            for(i=1;i<=NR;i++){
              if(i==last) print "source \"security/arb-guard/Kconfig\"";
              print a[i];
            }
          }' "$SECURITY_KCONFIG" > "$SECURITY_KCONFIG.tmp" && mv "$SECURITY_KCONFIG.tmp" "$SECURITY_KCONFIG"
    else
        printf '\nsource "security/arb-guard/Kconfig"\n' >> "$SECURITY_KCONFIG"
    fi
    echo " - Kconfig updated"
fi

echo "[+] ARB Guard setup done."
