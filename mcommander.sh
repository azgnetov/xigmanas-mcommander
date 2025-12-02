#!/bin/sh
# filename:     mcommander.sh
# purpose:      Install Midnight Commander on XigmaNAS 14 (embedded)
# author:       Dan Merschi, Graham Inggs, Alexander Zgnetov
#
# Notes:
#  - Script must reside in a persistent storage (/mnt/...).
#  - Run ONLY via full absolute path: /mnt/.../mcommander.sh
#  - Symlinks are recreated on every boot if used as PostInit script.
#

###############################################################################
# Helper functions
###############################################################################

msg() {
  echo "$1"
  exit ${2:-0}
}

ensure_full_path() {
  case "$0" in
    /*) : ;;  # ok: absolute path
    *) msg "ERROR: Run this script ONLY using its full absolute path: /mnt/.../mcommander.sh" 1 ;;
  esac
}

###############################################################################
# Initialization
###############################################################################

ensure_full_path

DIR="$(dirname "$0")"
cd "$DIR" || msg "ERROR: Cannot enter script directory." 1

PKG_DIR="${DIR}/All/Hashed"
MC_DIR="${DIR}/usr/local"

mkdir -p "$PKG_DIR"

###############################################################################
# Function: fetch_and_extract <pkgname>
###############################################################################
fetch_and_extract() {
  PKG="$1"

  echo "==> Processing package: ${PKG}"

  # fetch if no pkg files found
  if ! ls "${PKG_DIR}/${PKG}-"*.pkg >/dev/null 2>&1; then
    echo "   Fetching package via pkg fetch..."
    pkg fetch -o "${DIR}" -y "${PKG}" || msg "ERROR: Failed to fetch ${PKG}" 1
  fi

  # extract pkg archives
  for f in "${PKG_DIR}/${PKG}-"*.pkg; do
    echo "   Extracting ${f}..."
    tar -xf "$f" -C "${DIR}" || msg "ERROR: Failed to extract ${f}" 1
  done
}

###############################################################################
# Fetch and extract required packages
###############################################################################

# Midnight Commander
if [ ! -f "${MC_DIR}/bin/mc" ]; then
  fetch_and_extract "mc"
  # remove unneeded package files
  rm -f "${DIR}/+MANIFEST" "${DIR}/+COMPACT_MANIFEST" 2>/dev/null
  rm -rf "${DIR}/usr/local/man" 2>/dev/null
fi

# libslang2
if [ ! -f "${MC_DIR}/lib/libslang.so" ]; then
  fetch_and_extract "libslang2"
  rm -f "${DIR}/+MANIFEST" 2>/dev/null
  rm -rf "${DIR}/usr/local/include" "${DIR}/usr/local/man" "${DIR}/usr/local/libdata" 2>/dev/null
  rm -f "${DIR}/usr/local/lib/"*.a 2>/dev/null
fi

# libssh2
if [ ! -f "${MC_DIR}/lib/libssh2.so" ]; then
  fetch_and_extract "libssh2"
  rm -f "${DIR}/+MANIFEST" 2>/dev/null
  rm -rf "${DIR}/usr/local/include" "${DIR}/usr/local/man" "${DIR}/usr/local/libdata" 2>/dev/null
  rm -f "${DIR}/usr/local/lib/"*.a 2>/dev/null
fi

###############################################################################
# Create symlinks (safe)
###############################################################################

echo "==> Creating symlinks to system directories..."

# mc share
[ ! -e /usr/local/share/mc ] &&
  ln -s "${MC_DIR}/share/mc" /usr/local/share/mc

# mc libexec
[ ! -e /usr/local/libexec/mc ] &&
  ln -s "${MC_DIR}/libexec/mc" /usr/local/libexec/mc

# mc config
[ ! -e /usr/local/etc/mc ] &&
  ln -s "${MC_DIR}/etc/mc" /usr/local/etc/mc

# binaries
for bin in "${MC_DIR}/bin/"*; do
  base="$(basename "$bin")"
  [ ! -e "/usr/local/bin/${base}" ] &&
    ln -s "$bin" "/usr/local/bin/${base}"
done

# libraries
for lib in "${MC_DIR}/lib/"*.so* "${MC_DIR}/lib/"*.so; do
  [ -e "$lib" ] || continue
  base="$(basename "$lib")"
  [ ! -e "/usr/local/lib/${base}" ] &&
    ln -s "$lib" "/usr/local/lib/${base}"
done

# locales
if [ -d "${MC_DIR}/share/locale" ]; then
  for loc in "${MC_DIR}/share/locale/"*; do
    locname="$(basename "$loc")"
    if [ ! -e "/usr/local/share/locale/${locname}" ]; then
      ln -s "$loc" "/usr/local/share/locale/${locname}"
    else
      # ensure mc.mo exists inside LC_MESSAGES
      if [ -f "${loc}/LC_MESSAGES/mc.mo" ] &&
         [ ! -e "/usr/local/share/locale/${locname}/LC_MESSAGES/mc.mo" ]; then
        ln -s "${loc}/LC_MESSAGES/mc.mo" \
              "/usr/local/share/locale/${locname}/LC_MESSAGES/mc.mo"
      fi
    fi
  done
fi

###############################################################################
# Done
###############################################################################

msg "Midnight Commander installed and ready! Start by typing: mc" 0
