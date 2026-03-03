#!/bin/bash
# ============================================================
# BOSATEK SENTINEL V2
# Main launcher — Master Menu + Tmux workspace
# ============================================================

# --- CONFIGURATION ---
VPN_PATH="$HOME/Documents/THM.ovpn"
WRITEUP_BASE="$HOME/Documents/GitHub/Bosanac-Writeups/TryHackMe"
WORDLIST="$HOME/Desktop/wordlists/dirb/common.txt"
SESSION="sentinel"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- COLORS ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ============================================================
# MASTER MENU
# ============================================================
master_menu() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║        BOSATEK SENTINEL V2               ║"
    echo "  ║        Tactical Recon Framework          ║"
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo -e "  ${GREEN}[1]${RESET} New Engagement"
    echo -e "  ${GREEN}[2]${RESET} Resume Session"
    echo -e "  ${YELLOW}[3]${RESET} Tool Test  (Volatile — no VPN, no saved output)"
    echo -e "  ${RED}[4]${RESET} Save & Exit"
    echo ""
    read -p "  Select option [1-4]: " CHOICE

    case "$CHOICE" in
        1) new_engagement ;;
        2) resume_session ;;
        3) tool_test ;;
        4) save_and_exit ;;
        *) echo -e "${RED}[!] Invalid option.${RESET}"; sleep 1; master_menu ;;
    esac
}

# ============================================================
# OPTION 1: NEW ENGAGEMENT
# ============================================================
new_engagement() {
    echo ""
    read -p "  Target IP   : " TARGET_IP
    read -p "  Room Name   : " ROOM_NAME

    if [[ -z "$TARGET_IP" || -z "$ROOM_NAME" ]]; then
        echo -e "${RED}[!] Target IP and Room Name are required.${RESET}"
        sleep 1; master_menu; return
    fi

    ROOM_DIR="$WRITEUP_BASE/$ROOM_NAME"
    mkdir -p "$ROOM_DIR/nmap" "$ROOM_DIR/ffuf" "$ROOM_DIR/logs"

    echo -e "${GREEN}[*] Launching workspace for: $ROOM_NAME ($TARGET_IP)${RESET}"
    launch_tmux "$TARGET_IP" "$ROOM_NAME" "$ROOM_DIR" 0
}

# ============================================================
# OPTION 2: RESUME SESSION
# ============================================================
resume_session() {
    if tmux has-session -t "$SESSION" 2>/dev/null; then
        echo -e "${GREEN}[*] Reattaching to existing session...${RESET}"
        tmux attach-session -t "$SESSION"
        return
    fi

    echo -e "${YELLOW}[!] No live session found. Provide target to relaunch.${RESET}"
    echo ""
    read -p "  Target IP   : " TARGET_IP
    read -p "  Room Name   : " ROOM_NAME

    ROOM_DIR="$WRITEUP_BASE/$ROOM_NAME"
    if [[ ! -d "$ROOM_DIR" ]]; then
        echo -e "${RED}[!] Room directory not found: $ROOM_DIR${RESET}"
        sleep 2; master_menu; return
    fi

    launch_tmux "$TARGET_IP" "$ROOM_NAME" "$ROOM_DIR" 0
}

# ============================================================
# OPTION 3: TOOL TEST — Volatile, no VPN, stays on Control tab
# ============================================================
tool_test() {
    echo ""
    echo -e "${YELLOW}[!] TOOL TEST MODE${RESET}"
    echo -e "    • Output is volatile — nothing saved to disk"
    echo -e "    • VPN module is skipped"
    echo -e "    • Dashboard stays on Tab 1 (Control)"
    echo ""
    read -p "  Target IP (test): " TARGET_IP

    ROOM_NAME="VOLATILE_$(date +%s)"
    ROOM_DIR="/tmp/$ROOM_NAME"
    mkdir -p "$ROOM_DIR/nmap" "$ROOM_DIR/ffuf" "$ROOM_DIR/logs"

    launch_tmux "$TARGET_IP" "$ROOM_NAME" "$ROOM_DIR" 1
}

# ============================================================
# OPTION 4: SAVE & EXIT
# ============================================================
save_and_exit() {
    echo ""
    if tmux has-session -t "$SESSION" 2>/dev/null; then
        LAST_DIR=$(tmux display-message -p -t "$SESSION" '#{pane_current_path}' 2>/dev/null)
        if [[ -n "$LAST_DIR" && -d "$LAST_DIR/logs" ]]; then
            echo "Session closed: $(date)" >> "$LAST_DIR/logs/session.log"
            echo -e "${GREEN}[*] Session log → $LAST_DIR/logs/session.log${RESET}"
        fi
        tmux kill-session -t "$SESSION"
        echo -e "${GREEN}[*] Tmux session terminated.${RESET}"
    else
        echo -e "${YELLOW}[*] No active session to close.${RESET}"
    fi
    echo -e "${CYAN}[*] Bosatek Sentinel V2 — goodbye.${RESET}"
    exit 0
}

# ============================================================
# TMUX WORKSPACE LAUNCHER
# launch_tmux <TARGET_IP> <ROOM_NAME> <ROOM_DIR> <VOLATILE 0|1>
#
# Tab 1 — Control  (3-pane dashboard)
#   Pane 0  Left (full height)  : Master Terminal — interactive
#   Pane 1  Top-Right           : RustScan / Nmap output
#   Pane 2  Bottom-Right        : FFUF output
#
# Tab 2 — AI-Brain
# Tab 3 — Network  (skipped in VOLATILE mode)
# Tab 4 — Monitor
# ============================================================
launch_tmux() {
    local TARGET_IP="$1"
    local ROOM_NAME="$2"
    local ROOM_DIR="$3"
    local VOLATILE="$4"

    tmux kill-session -t "$SESSION" 2>/dev/null

    # ----------------------------------------------------------
    # Global tmux options (applied before any window is created)
    # ----------------------------------------------------------
    # Prefix: Ctrl+a
    tmux start-server 2>/dev/null || true
    tmux set-option -gs prefix C-a
    tmux set-option -gs prefix2 None
    tmux bind-key -T prefix C-a send-prefix

    # Mouse + clipboard
    tmux set-option -gs mouse on
    tmux set-option -s set-clipboard on
    tmux set-option -gs mode-keys vi
    tmux bind-key -T copy-mode-vi MouseDragEnd1Pane \
        send-keys -X copy-pipe-and-cancel "xclip -se c -i"

    # ----------------------------------------------------------
    # TAB 1: Control — 3-pane layout
    #
    #  ┌──────────────┬──────────────┐
    #  │              │  Pane 1      │
    #  │   Pane 0     │  (RustScan)  │
    #  │   MASTER     ├──────────────┤
    #  │   TERMINAL   │  Pane 2      │
    #  │              │  (FFUF)      │
    #  └──────────────┴──────────────┘
    # ----------------------------------------------------------
    tmux new-session -d -s "$SESSION" -n "Control"

    # Status bar
    tmux set-option -g -t "$SESSION" status-bg colour235
    tmux set-option -g -t "$SESSION" status-fg colour250
    tmux set-option -g -t "$SESSION" status-left "#[fg=colour46,bold] SENTINEL V2 #[fg=colour250]| "
    tmux set-option -g -t "$SESSION" status-right "#[fg=colour220] $ROOM_NAME #[fg=colour250]| %H:%M "

    # Pane 0 is the left master terminal — set env and show header
    tmux send-keys -t "$SESSION:Control.0" \
        "export IP='$TARGET_IP' ROOM='$ROOM_NAME' ROOM_DIR='$ROOM_DIR' VOLATILE=$VOLATILE WORDLIST='$WORDLIST'; clear" C-m
    tmux send-keys -t "$SESSION:Control.0" \
        "echo ''; echo '  ╔════════════════════════════════╗'; echo '  ║  BOSATEK SENTINEL V2           ║'; echo '  ║  Master Terminal               ║'; echo '  ╚════════════════════════════════╝'; echo ''; echo \"  Target : \$IP\"; echo \"  Room   : \$ROOM\"; echo \"  Dir    : \$ROOM_DIR\"; echo ''" C-m

    # Split right (Pane 1 = full right column)
    tmux split-window -h -t "$SESSION:Control.0" -p 45

    # Split Pane 1 vertically → Pane 1 (top-right) + Pane 2 (bottom-right)
    tmux split-window -v -t "$SESSION:Control.1" -p 50

    # Pane 1 (top-right): RustScan / Nmap
    tmux send-keys -t "$SESSION:Control.1" \
        "source '$SCRIPT_DIR/modules/recon.sh' && run_nmap '$TARGET_IP' '$ROOM_DIR' $VOLATILE" C-m

    # Pane 2 (bottom-right): FFUF
    tmux send-keys -t "$SESSION:Control.2" \
        "source '$SCRIPT_DIR/modules/recon.sh' && run_ffuf '$TARGET_IP' '$ROOM_DIR' $VOLATILE" C-m

    # Return focus to Pane 0 (master terminal) — user can type freely
    tmux select-pane -t "$SESSION:Control.0"

    # ----------------------------------------------------------
    # TAB 2: AI-Brain
    # ----------------------------------------------------------
    tmux new-window -t "$SESSION" -n "AI-Brain"
    tmux send-keys -t "$SESSION:AI-Brain" "ollama run bosatek-sentinel" C-m
    tmux split-window -v -t "$SESSION:AI-Brain" -l 8
    tmux send-keys -t "$SESSION:AI-Brain.1" \
        "source '$SCRIPT_DIR/modules/ai_brain.sh' && ai_brain_loop '$ROOM_DIR'" C-m
    tmux select-pane -t "$SESSION:AI-Brain.0"

    # ----------------------------------------------------------
    # TAB 3: Network — SKIPPED in Tool Test (VOLATILE) mode
    # ----------------------------------------------------------
    tmux new-window -t "$SESSION" -n "Network"
    if [[ "$VOLATILE" -eq 1 ]]; then
        tmux send-keys -t "$SESSION:Network" \
            "echo '[TOOL TEST] VPN module skipped in volatile mode.'" C-m
    else
        # Left pane: OpenVPN (logs to ~/vpn.log for wait_for_vpn to watch)
        tmux send-keys -t "$SESSION:Network" \
            "echo '[*] Starting OpenVPN...'; sudo openvpn '$VPN_PATH' 2>&1 | tee '$HOME/vpn.log'" C-m
        # Right pane: wait_for_vpn watcher
        tmux split-window -h -t "$SESSION:Network"
        tmux send-keys -t "$SESSION:Network.1" \
            "source '$SCRIPT_DIR/modules/network.sh' && wait_for_vpn '$HOME/vpn.log' && echo '[+] Tunnel up. Ready.'" C-m
    fi

    # ----------------------------------------------------------
    # TAB 4: Monitor
    #   Left : live tail of summary.log
    #   Right : watch -n 1 checklist.md (touch it first if absent)
    # ----------------------------------------------------------
    tmux new-window -t "$SESSION" -n "Monitor"

    tmux send-keys -t "$SESSION:Monitor" \
        "echo '[*] Monitor — tailing summary.log'; tail -F '$ROOM_DIR/logs/summary.log' 2>/dev/null" C-m

    tmux split-window -h -t "$SESSION:Monitor"
    tmux send-keys -t "$SESSION:Monitor.1" \
        "touch '$ROOM_DIR/checklist.md'; watch -n 1 cat '$ROOM_DIR/checklist.md'" C-m

    # ----------------------------------------------------------
    # Always land on Tab 1, Pane 0 (Master Terminal) after attach
    # ----------------------------------------------------------
    tmux select-window -t "$SESSION:Control"
    tmux select-pane -t "$SESSION:Control.0"
    tmux attach-session -t "$SESSION"
}

# ============================================================
# ENTRY POINT
# ============================================================
master_menu
