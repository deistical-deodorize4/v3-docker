#!/bin/sh
# Use Alpine's built-in xtables-nft-multi (nftables backend).
# Bypasses the alternatives system which defaults to legacy.
# Pi OS Trixie 6.x has no ip_tables kernel module.
exec /usr/sbin/xtables-nft-multi "$(basename "$0")" "$@"
