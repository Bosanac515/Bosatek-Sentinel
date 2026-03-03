#!/bin/bash
# ============================================================
# BOSATEK SENTINEL V3 — MVP MODE
# LinkedIn demo build — clean, stable, no AI Brain
# ============================================================

# --- CONFIGURATION ---
VPN_PATH="$HOME/Documents/THM.ovpn"
ENGAGEMENTS_BASE="$HOME/Documents/GitHub/Bosanac-Writeups"
WORDLIST="$HOME/Desktop/wordlists/dirb/common.txt"
BURP_EXE="/opt/BurpSuitePro/BurpSuitePro"
SESSION="sentinel"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- COLORS ---
GOLD='\033[1;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'
BOLD='\033[1m'

# ============================================================
# MASTER MENU
# ============================================================
master_menu() {
    clear
    echo -e "${GOLD}${BOLD}"
    echo "  ╔══════════════════════════════════════════════╗"
    echo "  ║    BOSATEK SENTINEL V3 - MVP MODE            ║"
    echo "  ╚══════════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo -e "  ${GREEN}[1]${RESET} New Engagement  (+ VPN)"
    echo -e "  ${GREEN}[2]${RESET} Resume Session  (+ VPN)"
    echo -e "  ${YELLOW}[3]${RESET} Tool Test       (No VPN)"
    echo -e "  ${RED}[4]${RESET} Quit"
    echo ""
    read -p "  Select option [1-4]: " CHOICE

    case "$CHOICE" in
        1) new_engagement ;;
        2) resume_session ;;
        3) tool_test ;;
        4) echo ""; echo "Goodbye."; exit 0 ;;
        *) echo -e "${RED}Invalid option.${RESET}"; sleep 1; master_menu ;;
    esac
}

# ============================================================
# OPTION 1: NEW ENGAGEMENT — asks Room Name, starts VPN
# ============================================================
new_engagement() {
    echo ""
    read -p "  Target IP  : " TARGET_IP
    read -p "  Room Name  : " ROOM_NAME

    if [[ -z "$TARGET_IP" || -z "$ROOM_NAME" ]]; then
        echo -e "${RED}[!] Target IP and Room Name are required.${RESET}"
        sleep 1; master_menu; return
    fi

    ROOM_DIR="$ENGAGEMENTS_BASE/$ROOM_NAME"
    mkdir -p "$ROOM_DIR/nmap" "$ROOM_DIR/ffuf"

    _start_vpn
    launch_tmux "$TARGET_IP" "$ROOM_NAME" "$ROOM_DIR" 0
}

# ============================================================
# OPTION 2: RESUME SESSION — asks Room Name, starts VPN
# ============================================================
resume_session() {
    if tmux has-session -t "$SESSION" 2>/dev/null; then
        echo -e "${GREEN}[*] Reattaching to session...${RESET}"
        tmux attach-session -t "$SESSION"
        return
    fi

    echo -e "${YELLOW}[!] No live session. Provide details to relaunch.${RESET}"
    echo ""
    read -p "  Target IP  : " TARGET_IP
    read -p "  Room Name  : " ROOM_NAME

    ROOM_DIR="$ENGAGEMENTS_BASE/$ROOM_NAME"
    if [[ ! -d "$ROOM_DIR" ]]; then
        echo -e "${RED}[!] Not found: $ROOM_DIR${RESET}"
        sleep 2; master_menu; return
    fi

    _start_vpn
    launch_tmux "$TARGET_IP" "$ROOM_NAME" "$ROOM_DIR" 0
}

# ============================================================
# OPTION 3: TOOL TEST — No VPN, date-stamped, volatile output
# ============================================================
tool_test() {
    echo ""
    echo -e "${YELLOW}[!] TOOL TEST — No VPN. Output is volatile (/tmp).${RESET}"
    echo ""
    read -p "  Target IP (test): " TARGET_IP

    ROOM_NAME="TEST_$(date +%Y%m%d_%H%M)"
    ROOM_DIR="/tmp/$ROOM_NAME"
    mkdir -p "$ROOM_DIR/nmap" "$ROOM_DIR/ffuf"

    echo -e "${YELLOW}[*] Room: $ROOM_NAME | Dir: $ROOM_DIR${RESET}"
    sleep 1

    launch_tmux "$TARGET_IP" "$ROOM_NAME" "$ROOM_DIR" 1
}

# ============================================================
# INTERNAL: start VPN in the background before launching tmux.
# OpenVPN output logs to ~/vpn.log — does not block the terminal.
# Requires passwordless sudo for openvpn OR user enters password here.
# ============================================================
_start_vpn() {
    echo ""
    echo -e "${GOLD}[*] Starting VPN → ${VPN_PATH}${RESET}"
    echo -e "    Log: ~/vpn.log"
    sudo openvpn "$VPN_PATH" > "$HOME/vpn.log" 2>&1 &
    echo -e "${GREEN}[*] VPN PID $! — connecting in background.${RESET}"
    echo -e "    Watch progress: tail -f ~/vpn.log"
    sleep 2
    echo ""
}

# ============================================================
# TMUX WORKSPACE LAUNCHER
# launch_tmux <TARGET_IP> <ROOM_NAME> <ROOM_DIR> <VOLATILE 0|1>
#
# ┌──────────────────────────────────────────────────────────┐
# │  Tab 1 [Recon]                                           │
# │  ┌───────────────────────────────────────────────────┐   │
# │  │  Pane 0 (top 60%)  — RustScan / Nmap              │   │
# │  ├───────────────────────────────────────────────────┤   │
# │  │  Pane 1 (bot 40%)  — FFUF -s -mc 200,301,302,403  │   │
# │  └───────────────────────────────────────────────────┘   │
# │                                                          │
# │  Tab 2 [Master]                                          │
# │  ┌───────────────────────────────────────────────────┐   │
# │  │  Full-screen interactive Zsh — type freely         │   │
# │  │  'sentinel-save' → saves notes & exits             │   │
# │  └───────────────────────────────────────────────────┘   │
# │                                                          │
# │  Tab 3 [Writeup]                                         │
# │  ┌───────────────────────────────────────────────────┐   │
# │  │  nano writeup.md                                   │   │
# │  └───────────────────────────────────────────────────┘   │
# └──────────────────────────────────────────────────────────┘
# ============================================================
launch_tmux() {
    local TARGET_IP="$1"
    local ROOM_NAME="$2"
    local ROOM_DIR="$3"
    local VOLATILE="$4"
    local WRITEUP_FILE="$ENGAGEMENTS_BASE/$ROOM_NAME/writeup.md"
    local NMAP_OUT="$ROOM_DIR/nmap/initial.txt"
    local FFUF_OUT="$ROOM_DIR/ffuf/hits.csv"

    tmux kill-session -t "$SESSION" 2>/dev/null
    tmux start-server 2>/dev/null || true

    # ----------------------------------------------------------
    # TMUX OPTIONS — bare essentials, zero custom mouse bindings
    # ----------------------------------------------------------
    # Prefix: Ctrl+a — double-tap sends literal C-a to the app
    tmux set -g prefix C-a
    tmux unbind C-b
    tmux bind C-a send-prefix

    # Mouse: ON — no custom drag or right-click bindings whatsoever
    tmux set -g mouse on

    # Status bar
    tmux set -g status-style          "bg=colour235,fg=colour250"
    tmux set -g status-left           "#[fg=colour220,bold] SENTINEL V3 #[fg=colour250]| "
    tmux set -g status-right          "#[fg=colour220] $ROOM_NAME #[fg=colour250]| %H:%M "
    tmux set -g window-status-current-style "fg=colour220,bold"

    # ----------------------------------------------------------
    # Write the sentinel-save function to a file so the Master
    # Terminal can source it. Variables are expanded NOW (write time):
    #   $WRITEUP_FILE, $NMAP_OUT, $FFUF_OUT, $SESSION are injected.
    # The \$(...) and \$VAR inside the function stay literal.
    # ----------------------------------------------------------
    mkdir -p "$(dirname "$WRITEUP_FILE")"
    cat > "$ROOM_DIR/.sentinel_env.sh" << FUNCEOF
# Bosatek Sentinel V3 — session environment
# Source this file to get the sentinel-save command.

sentinel-save() {
    local WU="$WRITEUP_FILE"
    local NMAP="$NMAP_OUT"
    local FFUF="$FFUF_OUT"

    echo ""
    echo "[sentinel-save] Saving session..."

    mkdir -p "\$(dirname "\$WU")"

    # Header
    echo ""                              >> "\$WU"
    echo "---"                           >> "\$WU"
    echo "## Session Saved: \$(date)"   >> "\$WU"
    echo ""                              >> "\$WU"

    # Port scan output
    if [[ -f "\$NMAP" ]]; then
        echo "### Port Scan — last 100 lines" >> "\$WU"
        echo ""                               >> "\$WU"
        tail -100 "\$NMAP"                   >> "\$WU"
        echo ""                               >> "\$WU"
    else
        echo "### Port Scan — no output file found" >> "\$WU"
        echo ""                                     >> "\$WU"
    fi

    # FFUF hits
    if [[ -f "\$FFUF" ]]; then
        echo "### FFUF Hits — last 100 lines" >> "\$WU"
        echo ""                               >> "\$WU"
        tail -100 "\$FFUF"                   >> "\$WU"
        echo ""                               >> "\$WU"
    else
        echo "### FFUF — no hits file found" >> "\$WU"
        echo ""                              >> "\$WU"
    fi

    echo "Session Ended: \$(date)" >> "\$WU"
    echo ""
    echo "[sentinel-save] Written to: \$WU"
    sleep 1
    tmux kill-session -t $SESSION 2>/dev/null
}

export -f sentinel-save
FUNCEOF

    # ----------------------------------------------------------
    # Initialise writeup.md with a header if it is brand new
    # ----------------------------------------------------------
    if [[ ! -s "$WRITEUP_FILE" ]]; then
        cat > "$WRITEUP_FILE" << MDEOF
# $ROOM_NAME

**Target:** $TARGET_IP
**Date:** $(date)

---

## Notes

MDEOF
    fi

    # ----------------------------------------------------------
    # TAB 1 [Recon] — horizontal (top/bottom) split
    #   Pane 0 (top 60%) : RustScan / Nmap
    #   Pane 1 (bot 40%) : FFUF  -s -mc 200,301,302,403
    # ----------------------------------------------------------
    tmux new-session -d -s "$SESSION" -n "Recon"

    # Common env export helper (sent to both panes)
    local ENV_EXPORT="export TARGET='$TARGET_IP' IP='$TARGET_IP' ROOM='$ROOM_NAME' ROOM_DIR='$ROOM_DIR' WORDLIST='$WORDLIST'"

    # Pane 0 — RustScan
    tmux send-keys -t "$SESSION:Recon.0" "$ENV_EXPORT" C-m
    if [[ "$VOLATILE" -eq 1 ]]; then
        tmux send-keys -t "$SESSION:Recon.0" \
            "echo '[Recon] RustScan starting...'; rustscan -a $TARGET_IP --ulimit 5000 --timeout 3000 --batch-size 500 -- -A -sC 2>&1" C-m
    else
        tmux send-keys -t "$SESSION:Recon.0" \
            "echo '[Recon] RustScan starting...'; rustscan -a $TARGET_IP --ulimit 5000 --timeout 3000 --batch-size 500 -- -A -sC -oN '$NMAP_OUT' 2>&1" C-m
    fi

    # Split top/bottom — bottom pane gets 40%
    tmux split-window -v -t "$SESSION:Recon.0" -p 40

    # Pane 1 — FFUF (exact command as specified, with optional save)
    tmux send-keys -t "$SESSION:Recon.1" "$ENV_EXPORT" C-m
    if [[ "$VOLATILE" -eq 1 ]]; then
        tmux send-keys -t "$SESSION:Recon.1" \
            "echo '[Recon] FFUF starting...'; ffuf -w '$WORDLIST' -u http://$TARGET_IP/FUZZ -s -mc 200,301,302,403" C-m
    else
        tmux send-keys -t "$SESSION:Recon.1" \
            "echo '[Recon] FFUF starting...'; ffuf -w '$WORDLIST' -u http://$TARGET_IP/FUZZ -s -mc 200,301,302,403 -o '$FFUF_OUT' -of csv" C-m
    fi

    # ----------------------------------------------------------
    # TAB 2 [Master] — single full-screen interactive Zsh
    # NO splits. NO background loops. 100% clean user terminal.
    # ----------------------------------------------------------
    tmux new-window -t "$SESSION" -n "Master"

    # Export env vars
    tmux send-keys -t "$SESSION:Master" "$ENV_EXPORT; clear" C-m

    # Simple echo banner — no printf, no escape sequences, no box chars
    tmux send-keys -t "$SESSION:Master" "echo ''" C-m
    tmux send-keys -t "$SESSION:Master" "echo 'BOSATEK SENTINEL V3 - MVP MODE'" C-m
    tmux send-keys -t "$SESSION:Master" "echo ''" C-m
    tmux send-keys -t "$SESSION:Master" "echo \"  Target : $TARGET_IP\"" C-m
    tmux send-keys -t "$SESSION:Master" "echo \"  Room   : $ROOM_NAME\"" C-m
    tmux send-keys -t "$SESSION:Master" "echo \"  Dir    : $ROOM_DIR\"" C-m
    tmux send-keys -t "$SESSION:Master" "echo ''" C-m

    # Source the sentinel-save function — user can now type 'sentinel-save'
    tmux send-keys -t "$SESSION:Master" "source '$ROOM_DIR/.sentinel_env.sh'" C-m
    tmux send-keys -t "$SESSION:Master" "echo '  Commands: sentinel-save'" C-m
    tmux send-keys -t "$SESSION:Master" "echo ''" C-m

    # ----------------------------------------------------------
    # TAB 3 [Writeup] — writeup.md in nano
    # File path: $ENGAGEMENTS_BASE/$ROOM_NAME/writeup.md
    # ----------------------------------------------------------
    tmux new-window -t "$SESSION" -n "Writeup"
    tmux send-keys -t "$SESSION:Writeup" "nano '$WRITEUP_FILE'" C-m

    # ----------------------------------------------------------
    # Land on Tab 2 [Master] — user is at a clean Zsh prompt
    # ----------------------------------------------------------
    tmux select-window -t "$SESSION:Master"
    tmux attach-session -t "$SESSION"
}

# ============================================================
# ENTRY POINT
# ============================================================
master_menu
