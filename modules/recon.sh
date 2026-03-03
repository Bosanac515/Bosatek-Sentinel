#!/bin/bash
# ============================================================
# BOSATEK SENTINEL V3 — modules/recon.sh
# Separate functions — each tmux pane in Tab 1 runs its own phase:
#   run_nmap  → Pane 1 (top-right)   : RustScan / Nmap
#   run_ffuf  → Pane 2 (bottom-right): FFUF -s -ic -mc 200,301,302
# VOLATILE mode: no output files written to disk.
# ============================================================

# run_nmap <TARGET_IP> <ROOM_DIR> <VOLATILE 0|1>
run_nmap() {
    local TARGET_IP="$1"
    local ROOM_DIR="$2"
    local VOLATILE="${3:-0}"
    local NMAP_OUT SUMMARY_LOG

    if [[ "$VOLATILE" -eq 1 ]]; then
        NMAP_OUT="/dev/null"
        SUMMARY_LOG="/dev/null"
        echo "[!] VOLATILE — nmap output discarded."
    else
        NMAP_OUT="$ROOM_DIR/nmap/initial.txt"
        SUMMARY_LOG="$ROOM_DIR/logs/summary.log"
        mkdir -p "$ROOM_DIR/nmap" "$ROOM_DIR/logs"
    fi

    echo "============================================"
    echo " PORT SCAN — $TARGET_IP"
    echo " $(date)"
    echo "============================================"
    echo ""

    if command -v rustscan &>/dev/null; then
        echo "[*] RustScan → Nmap -A -sC"
        rustscan -a "$TARGET_IP" --ulimit 5000 -- -A -sC -oN "$NMAP_OUT"
    else
        echo "[!] RustScan not found — falling back to Nmap."
        nmap -A -sC -sV -oN "$NMAP_OUT" "$TARGET_IP"
    fi

    if [[ "$VOLATILE" -eq 0 && -f "$NMAP_OUT" ]]; then
        {
            echo ""
            echo "=== NMAP $(date) ==="
            cat "$NMAP_OUT"
        } >> "$SUMMARY_LOG"
        echo ""
        echo "[+] Saved  → $NMAP_OUT"
        echo "[+] Logged → $SUMMARY_LOG"
    fi

    echo ""
    echo "[*] Port scan complete. Press Enter to reuse this pane."
    read -r
}

# run_ffuf <TARGET_IP> <ROOM_DIR> <VOLATILE 0|1>
#
# Flags:
#   -s               silent — suppresses banner and progress bar entirely
#   -ic              ignore wordlist comment lines (lines starting with #)
#   -mc 200,301,302  match only real hits; all other codes dropped
#   curl -I          fires on every hit to capture response headers for AI
run_ffuf() {
    local TARGET_IP="$1"
    local ROOM_DIR="$2"
    local VOLATILE="${3:-0}"
    local WORDLIST="${WORDLIST:-$HOME/Desktop/wordlists/dirb/common.txt}"
    local FFUF_OUT SUMMARY_LOG

    if [[ "$VOLATILE" -eq 1 ]]; then
        FFUF_OUT=""
        SUMMARY_LOG="/dev/null"
        echo "[!] VOLATILE — FFUF output discarded."
    else
        FFUF_OUT="$ROOM_DIR/ffuf/hits.json"
        SUMMARY_LOG="$ROOM_DIR/logs/summary.log"
        mkdir -p "$ROOM_DIR/ffuf" "$ROOM_DIR/logs"
    fi

    echo "============================================"
    echo " WEB FUZZ (FFUF) — http://$TARGET_IP/"
    echo " $(date)"
    echo "============================================"
    echo ""

    if ! command -v ffuf &>/dev/null; then
        echo "[!] ffuf not installed — skipping."
        echo "[*] Press Enter to reuse this pane."
        read -r; return 1
    fi

    if [[ ! -f "$WORDLIST" ]]; then
        echo "[!] Wordlist not found: $WORDLIST"
        echo "[!] Set WORDLIST env var or install SecLists."
        echo "[*] Press Enter to reuse this pane."
        read -r; return 1
    fi

    echo "[*] Wordlist : $WORDLIST"
    echo "[*] Target   : http://$TARGET_IP/FUZZ"
    echo "[*] Flags    : -s -ic -mc 200,301,302"
    echo ""

    # Build FFUF argument array
    # -s              : silent — no banner, no progress bar, hits only
    # -ic             : ignore wordlist comments (skip lines starting with #)
    # -mc 200,301,302 : match only these HTTP status codes; all else dropped
    local FFUF_ARGS=(
        -w "$WORDLIST"
        -u "http://$TARGET_IP/FUZZ"
        -e .php,.html,.txt,.bak
        -t 100
        -mc 200,301,302
        -ic
        -s
    )

    if [[ "$VOLATILE" -eq 0 ]]; then
        FFUF_ARGS+=(-o "$FFUF_OUT" -of json)
    fi

    # Pipe FFUF hits through the handler (fires curl -I on each match)
    ffuf "${FFUF_ARGS[@]}" 2>/dev/null | _handle_ffuf_hits "$TARGET_IP" "$SUMMARY_LOG" "$VOLATILE"

    echo ""
    echo "[+] FFUF complete."
    [[ "$VOLATILE" -eq 0 ]] && echo "[+] JSON hits → $FFUF_OUT"
    echo ""
    echo "[*] Press Enter to reuse this pane."
    read -r
}

# _handle_ffuf_hits <TARGET_IP> <SUMMARY_LOG> <VOLATILE>
# Reads ffuf -s output line-by-line; fires curl -I on each match
# and appends headers to summary.log for the AI-Brain loop to pick up.
_handle_ffuf_hits() {
    local TARGET_IP="$1"
    local SUMMARY_LOG="$2"
    local VOLATILE="${3:-0}"

    while IFS= read -r line; do
        # ffuf -s output format: "path [Status: 200, Size: ...]"
        # Extract first token (the path).
        local HIT_PATH
        HIT_PATH=$(echo "$line" | awk '{print $1}')
        [[ -z "$HIT_PATH" ]] && continue

        local FULL_URL="http://$TARGET_IP/${HIT_PATH#/}"
        echo "[HIT] $FULL_URL"

        local HEADERS
        HEADERS=$(curl -sI --max-time 5 "$FULL_URL" 2>/dev/null)
        if [[ -n "$HEADERS" ]]; then
            local STATUS_LINE
            STATUS_LINE=$(echo "$HEADERS" | head -1 | tr -d '\r')
            echo "  └─ $STATUS_LINE"

            if [[ "$VOLATILE" -eq 0 ]]; then
                {
                    echo ""
                    echo "=== FFUF HIT: $FULL_URL — $(date) ==="
                    echo "$HEADERS"
                } >> "$SUMMARY_LOG"
            fi
        fi
    done
}
