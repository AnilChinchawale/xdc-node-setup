#!/bin/sh
# Ensure XDC binary is available based on NETWORK env var
NETWORK="${NETWORK:-mainnet}"

# Map network names to binary names
case "$NETWORK" in
    mainnet) BIN="XDC-mainnet" ;;
    testnet|apothem) BIN="XDC-testnet" ;;
    devnet) BIN="XDC-devnet" ;;
    local) BIN="XDC-local" ;;
    *) BIN="XDC-mainnet" ;;
esac

if ! command -v XDC >/dev/null 2>&1; then
    if command -v "$BIN" >/dev/null 2>&1; then
        ln -sf "$(which "$BIN")" /usr/bin/XDC
        echo "Linked $BIN → /usr/bin/XDC (Network: $NETWORK)"
    else
        # Fallback to first available binary
        for bin in XDC-mainnet XDC-testnet XDC-devnet XDC-local; do
            if command -v "$bin" >/dev/null 2>&1; then
                ln -sf "$(which "$bin")" /usr/bin/XDC
                echo "Warning: $BIN not found, linked $bin → /usr/bin/XDC"
                break
            fi
        done
    fi
fi

if ! command -v XDC >/dev/null 2>&1; then
    echo "FATAL: No XDC binary found in image!"
    exit 1
fi

exec /work/start.sh "$@"
