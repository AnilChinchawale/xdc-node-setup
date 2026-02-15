#!/bin/sh
# Ensure XDC binary is available (image may have XDC-mainnet instead)
export PATH="/tmp:$PATH"

if ! command -v XDC >/dev/null 2>&1; then
    for bin in XDC-mainnet XDC-testnet XDC-devnet XDC-local; do
        BINPATH=$(which "$bin" 2>/dev/null)
        if [ -n "$BINPATH" ]; then
            cp "$BINPATH" /tmp/XDC 2>/dev/null || ln -sf "$BINPATH" /tmp/XDC 2>/dev/null || true
            chmod +x /tmp/XDC 2>/dev/null || true
            echo "Linked $bin → /tmp/XDC"
            break
        fi
    done
fi

if ! command -v XDC >/dev/null 2>&1; then
    echo "FATAL: No XDC binary found in image!"
    echo "Searched: XDC, XDC-mainnet, XDC-testnet, XDC-devnet, XDC-local"
    echo "PATH=$PATH"
    ls -la /usr/bin/XDC* /tmp/XDC 2>/dev/null
    exit 1
fi

echo "Using XDC binary: $(which XDC)"
exec /work/start.sh "$@"
