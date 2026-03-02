#!/bin/bash
# ============================================================
# BOSATEK SENTINEL V2 — modules/recon.sh
# Recon runner: RustScan/Nmap + FFUF with curl -I on hits
# VOLATILE mode: no output files written to disk
# ============================================================

# run_recon <TARGET_IP> <ROOM_DIR> <VOLATILE 0|1>
run_recon() {
    local TARGET_IP="$1"
    local ROOM_DIR="$2"
    local VOLATILE="${3:-0}"

    local WORDLIST="${WORDLIST:-$HOME/Desktop/wordlists/dirb/common.txt}"
    local NMAP_OUT FFUF_OUT SUMMARY_LOG

    if [[ "$VOLATILE" -eq 1 ]]; then
        NMAP_OUT="/dev/null"
        FFUF_OUT="/dev/null"
        SUMMARY_LOG="/dev/null"
        echo "[!] VOLATILE MODE — no output will be written to disk."
    else
        NMAP_OUT="$ROOM_DIR/nmap/initial.txt"
        FFUF_OUT="$ROOM_DIR/ffuf/hits.json"
        SUMMARY_LOG="$ROOM_DIR/logs/summary.log"
        mkdir -p "$ROOM_DIR/nmap" "$ROOM_DIR/ffuf" "$ROOM_DIR/logs"
    fi

    echo ""
    echo "============================================"
    echo " RECON START: $TARGET_IP"
    echo " $(date)"
    echo "============================================"

    # ----------------------------------------------------------
    # PHASE 1: Port scan (RustScan → Nmap, fallback to Nmap only)
    # ----------------------------------------------------------
    echo ""
    echo "[*] Phase 1 — Port Scan"

    if command -v rustscan &>/dev/null; then
        echo "[*] Running RustScan..."
        rustscan -a "$TARGET_IP" --ulimit 5000 -- -A -sC -oN "$NMAP_OUT" 2>&1 | tee_or_discard "$VOLATILE"
    else
        echo "[!] RustScan not found, falling back to Nmap."
        nmap -A -sC -sV -oN "$NMAP_OUT" "$TARGET_IP" 2>&1 | tee_or_discard "$VOLATILE"
    fi

    if [[ "$VOLATILE" -eq 0 && -f "$NMAP_OUT" ]]; then
        echo "" >> "$SUMMARY_LOG"
        echo "=== NMAP $(date) ===" >> "$SUMMARY_LOG"
        cat "$NMAP_OUT" >> "$SUMMARY_LOG"
        echo "[+] Nmap output appended to summary.log"
    fi

    # ----------------------------------------------------------
    # PHASE 2: Web discovery with FFUF (quiet mode)
    # ----------------------------------------------------------
    echo ""
    echo "[*] Phase 2 — Web Directory Fuzzing (FFUF)"

    if ! command -v ffuf &>/dev/null; then
        echo "[!] ffuf not found — skipping web fuzzing."
        return
    fi

    if [[ ! -f "$WORDLIST" ]]; then
        echo "[!] Wordlist not found at: $WORDLIST — skipping FFUF."
        return
    fi

    local FFUF_CMD_ARGS=(-w "$WORDLIST" -u "http://$TARGET_IP/FUZZ"
                         -e .php,.html,.txt,.bak
                         -t 100
                         -fs 0
                         -mc 200,204,301,302,307,401,403
                         -s)   # -s = silent/quiet output (only hits)

    if [[ "$VOLATILE" -eq 0 ]]; then
        FFUF_CMD_ARGS+=(-o "$FFUF_OUT" -of json)
    fi

    echo "[*] FFUF running quietly — hits will be probed with curl -I ..."
    echo ""

    # Run FFUF; capture hits from quiet output (one URL per line)
    ffuf "${FFUF_CMD_ARGS[@]}" 2>&1 | while IFS= read -r line; do
        # FFUF -s prints matched paths, not full URLs; reconstruct
        local HIT_PATH
        HIT_PATH=$(echo "$line" | awk '{print $1}')
        [[ -z "$HIT_PATH" ]] && continue

        local FULL_URL="http://$TARGET_IP/$HIT_PATH"
        echo "[HIT] $FULL_URL"

        # Probe each hit with curl -I to get headers for AI analysis
        local HEADERS
        HEADERS=$(curl -sI --max-time 5 "$FULL_URL" 2>/dev/null)
        if [[ -n "$HEADERS" ]]; then
            echo "  >> $(echo "$HEADERS" | head -1)"

            if [[ "$VOLATILE" -eq 0 ]]; then
                {
                    echo ""
                    echo "=== FFUF HIT: $FULL_URL — $(date) ==="
                    echo "$HEADERS"
                } >> "$SUMMARY_LOG"
            fi
        fi
    done

    echo ""
    echo "[+] FFUF phase complete."

    if [[ "$VOLATILE" -eq 0 ]]; then
        echo "[+] Summary log updated: $SUMMARY_LOG"
    fi
}

# Helper: pipe output to screen only when volatile, or tee to file
tee_or_discard() {
    local VOLATILE="$1"
    if [[ "$VOLATILE" -eq 1 ]]; then
        cat   # just pass through to stdout, no file
    else
        cat   # caller already set NMAP_OUT to a real path via -oN
    fi
}
