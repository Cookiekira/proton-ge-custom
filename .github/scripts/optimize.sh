#!/usr/bin/env bash
# Trim the upstream build down to a 64-bit-only (WoW64) x86_64 build.
# Run from the root of a proton-ge-custom checkout, before configure.sh.
# Every edit is checked so the build fails loudly if upstream changes the code it targets.
set -euo pipefail

# Apply a sed expression to a file and fail if it changed nothing.
edit() {
    local file=$1 expr=$2 before
    before=$(sha1sum "$file")
    sed -i -e "$expr" "$file"
    if [ "$before" = "$(sha1sum "$file")" ]; then
        echo "::error::optimize.sh: '$expr' did not match anything in $file" >&2
        exit 1
    fi
}

# Drop the i386 Unix side. Wine is then configured with --enable-archs=x86_64,i386,
# so 32-bit PE modules are still built, but 32-bit programs run through WoW64.
edit Makefile.in 's/^\(\s*ARCHS += \)i386-unix x86_64-unix$/\1x86_64-unix/'

# With no wine-i386 build, point i386 consumers (lsteamclient, vrclient, ...) at the
# i386 PE import libraries and headers installed by the x86_64 (WoW64) wine build.
edit Makefile.in 's/^WINE_i386_LIBDIR = \$(WINE_i386_DST)\/lib$/WINE_i386_LIBDIR = $(WINE_x86_64_DST)\/lib\nWINE_i386_INCDIR = $(WINE_x86_64_DST)\/include/'

# Kaldi serializes its i386 and x86_64 builds with hardcoded ordering rules;
# with no kaldi-i386 the x86_64 configure would wait on a target that does not exist.
edit Makefile.in '/^\$(OBJ)\/\.kaldi-x86_64-configure: \$(OBJ)\/\.kaldi-i386-configure$/d; /^\$(OBJ)\/\.kaldi-i386-build: /d'

# VKD3D_PE_LIBS applies to every PE arch of a wine build, so the x86_64-only flags
# would break the i386 PE link. Let wine use its bundled vkd3d instead.
edit Makefile.in '/^WINE_x86_64_AUTOCONF_ARGS += \\$/,/^  VKD3D_PE_LIBS=/d'

# Default to WoW64 at runtime, since there is no 32-bit Unix side to fall back to.
edit proton 's/if "PROTON_USE_WOW64" in self.env and self.env\["PROTON_USE_WOW64"\] == "1" and platform.machine() == "x86_64":/if self.env.get("PROTON_USE_WOW64", "1") == "1" and platform.machine() == "x86_64":/'
