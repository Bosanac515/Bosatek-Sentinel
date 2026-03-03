#!/bin/bash
# ============================================================
# BOSATEK SENTINEL V3 — MASTER CONTROL
# Main launcher — Master Menu + Tmux workspace
# ============================================================

# --- CONFIGURATION ---
VPN_PATH="$HOME/Documents/THM.ovpn"
WRITEUP_BASE="$HOME/Documents/GitHub/Bosanac-Writeups/TryHackMe"
BURP_BASE="$HOME/Documents/GitHub/Bosanac-Writeups"
WORDLIST="$HOME/Desktop/wordlists/dirb/common.txt"
SESSION="sentinel"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- COLORS ---
GOLD='\033[1;33m'
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
    echo -e "${GOLD}${BOLD}"
    echo "  ╔══════════════════════════════════════════════╗"
    echo "  ║    BOSATEK SENTINEL V3 — MASTER CONTROL     ║"
    echo "  ║    Tactical Recon Framework                  ║"
    echo "  ╚══════════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo -e "  ${GREEN}[1]${RESET} New Engagement"
    echo -e "  ${GREEN}[2]${RESET} Resume Session"
    echo -e "  ${YELLOW}[3]${RESET} Tool Test  (Volatile — date-stamped, VPN optional)"
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
    mkdir -p "$BURP_BASE/$ROOM_NAME"

    echo -e "${GOLD}[*] Launching workspace for: $ROOM_NAME ($TARGET_IP)${RESET}"
    launch_tmux "$TARGET_IP" "$ROOM_NAME" "$ROOM_DIR" 0 1
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

    mkdir -p "$BURP_BASE/$ROOM_NAME"

    launch_tmux "$TARGET_IP" "$ROOM_NAME" "$ROOM_DIR" 0 1
}

# ============================================================
# OPTION 3: TOOL TEST — Volatile, date-stamped, VPN optional
# ============================================================
tool_test() {
    echo ""
    echo -e "${YELLOW}[!] TOOL TEST MODE${RESET}"
    echo -e "    • Output is volatile — nothing saved permanently"
    echo -e "    • Room auto-named with timestamp"
    echo ""
    read -p "  Target IP (test): " TARGET_IP

    # Date-stamped ROOM_NAME as requested
    ROOM_NAME="TEST_$(date +%Y%m%d_%H%M)"
    ROOM_DIR="/tmp/$ROOM_NAME"
    mkdir -p "$ROOM_DIR/nmap" "$ROOM_DIR/ffuf" "$ROOM_DIR/logs"
    mkdir -p "$BURP_BASE/$ROOM_NAME"

    echo ""
    read -p "  Connect VPN? (y/n): " VPN_CHOICE
    local USE_VPN=0
    [[ "$VPN_CHOICE" =~ ^[Yy]$ ]] && USE_VPN=1

    launch_tmux "$TARGET_IP" "$ROOM_NAME" "$ROOM_DIR" 1 "$USE_VPN"
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
    echo -e "${GOLD}[*] Bosatek Sentinel V3 — goodbye.${RESET}"
    exit 0
}

# ============================================================
# TMUX WORKSPACE LAUNCHER
# launch_tmux <TARGET_IP> <ROOM_NAME> <ROOM_DIR> <VOLATILE 0|1> <USE_VPN 0|1>
#
# ┌──────────────────────────────────────────────────────────┐
# │  TAB 1: Control                                          │
# │  ┌───────────────────┬───────────────┐                   │
# │  │                   │  Pane 1       │                   │
# │  │   Pane 0  (55%)   │  (RustScan)   │                   │
# │  │   MASTER TERMINAL ├───────────────┤                   │
# │  │   Clean Zsh       │  Pane 2       │                   │
# │  │   ← FOCUSED       │  (FFUF)       │                   │
# │  └───────────────────┴───────────────┘                   │
# │  TAB 2: AI-Brain  (ollama | ai_brain_loop)               │
# │  TAB 3: Network   (VPN | wait_for_vpn | Burp Pro)        │
# │  TAB 4: Monitor   (summary.log | checklist.md)           │
# └──────────────────────────────────────────────────────────┘
# ============================================================
launch_tmux() {
    local TARGET_IP="$1"
    local ROOM_NAME="$2"
    local ROOM_DIR="$3"
    local VOLATILE="$4"
    local USE_VPN="$5"
    local BURP_PROJECT="$BURP_BASE/$ROOM_NAME/$ROOM_NAME.burp"

    tmux kill-session -t "$SESSION" 2>/dev/null

    # ----------------------------------------------------------
    # TMUX OPTIONS — server-level settings applied cleanly
    # ----------------------------------------------------------
    tmux start-server 2>/dev/null || true

    # Prefix: Ctrl+a
    # bind C-a send-prefix → double-tap C-a passes literal C-a to app
    tmux set -g prefix C-a
    tmux unbind C-b
    tmux bind C-a send-prefix

    # Mouse on — NO custom MouseDrag bindings (restores right-click menu)
    tmux set -g mouse on

    # Unbind tmux's default right-click menu so the terminal emulator
    # receives the right-click and shows the standard Kali context menu
    tmux unbind-key -T root MouseDown3Pane

    # Clipboard: on without custom drag bindings (use Shift+drag for xclip)
    tmux set -s set-clipboard on

    # Status bar — gold theme
    tmux set -g status-bg colour235
    tmux set -g status-fg colour220
    tmux set -g status-left  "#[fg=colour220,bold] SENTINEL V3 #[fg=colour250]| "
    tmux set -g status-right "#[fg=colour220] $ROOM_NAME #[fg=colour250]| %H:%M "

    # ----------------------------------------------------------
    # TAB 1: Control — 3-pane layout
    #   Pane 0  Left  (55%) : Master Terminal — clean Zsh, FOCUSED
    #   Pane 1  Top-Right   : RustScan / Nmap
    #   Pane 2  Bottom-Right: FFUF  (-s -ic -mc 200,301,302)
    # ----------------------------------------------------------
    tmux new-session -d -s "$SESSION" -n "Control"

    # Pane 0: export env vars, print gold banner, leave at clean prompt
    tmux send-keys -t "$SESSION:Control.0" \
        "export IP='$TARGET_IP' ROOM='$ROOM_NAME' ROOM_DIR='$ROOM_DIR' VOLATILE=$VOLATILE WORDLIST='$WORDLIST'; clear" C-m
    tmux send-keys -t "$SESSION:Control.0" \
        "printf '\033[1;33m  ╔══════════════════════════════════════════════╗\n  ║    BOSATEK SENTINEL V3 — MASTER CONTROL     ║\n  ╚══════════════════════════════════════════════╝\033[0m\n\n  \033[0;32mTarget :\033[0m \$IP\n  \033[0;32mRoom   :\033[0m \$ROOM\n  \033[0;32mDir    :\033[0m \$ROOM_DIR\n'" C-m

    # Split right column (45% width) — this becomes the recon column
    tmux split-window -h -t "$SESSION:Control.0" -p 45

    # Split right column in half vertically → Pane 1 (top) + Pane 2 (bottom)
    tmux split-window -v -t "$SESSION:Control.1" -p 50

    # Pane 1 — Top-Right: RustScan / Nmap
    tmux send-keys -t "$SESSION:Control.1" \
        "source '$SCRIPT_DIR/modules/recon.sh' && run_nmap '$TARGET_IP' '$ROOM_DIR' $VOLATILE" C-m

    # Pane 2 — Bottom-Right: FFUF
    tmux send-keys -t "$SESSION:Control.2" \
        "source '$SCRIPT_DIR/modules/recon.sh' && run_ffuf '$TARGET_IP' '$ROOM_DIR' $VOLATILE" C-m

    # Return focus to Pane 0 — clean Zsh prompt, user can type immediately
    tmux select-pane -t "$SESSION:Control.0"

    # ----------------------------------------------------------
    # TAB 2: AI-Brain  (PRESERVED — do not modify)
    #   Top    : ollama interactive model
    #   Bottom : ai_brain_loop — watches summary.log, updates checklist.md
    # ----------------------------------------------------------
    tmux new-window -t "$SESSION" -n "AI-Brain"
    tmux send-keys -t "$SESSION:AI-Brain" "ollama run bosatek-sentinel" C-m
    tmux split-window -v -t "$SESSION:AI-Brain" -l 8
    tmux send-keys -t "$SESSION:AI-Brain.1" \
        "source '$SCRIPT_DIR/modules/ai_brain.sh' && ai_brain_loop '$ROOM_DIR'" C-m
    tmux select-pane -t "$SESSION:AI-Brain.0"

    # ----------------------------------------------------------
    # TAB 3: Network  (PRESERVED — do not modify)
    #   USE_VPN=1  → Left: OpenVPN | Top-Right: wait_for_vpn | Bot-Right: Burp
    #   USE_VPN=0  → Single pane notice + Burp launch
    #
    # Burp project: $BURP_BASE/$ROOM_NAME/$ROOM_NAME.burp
    # Directory pre-created above in new_engagement / tool_test.
    # ----------------------------------------------------------
    tmux new-window -t "$SESSION" -n "Network"

    if [[ "$USE_VPN" -eq 1 ]]; then
        # Left pane: OpenVPN — output logged to ~/vpn.log
        tmux send-keys -t "$SESSION:Network" \
            "echo '[*] Starting OpenVPN...'; sudo openvpn '$VPN_PATH' 2>&1 | tee '$HOME/vpn.log'" C-m

        # Right column
        tmux split-window -h -t "$SESSION:Network" -p 50

        # Top-right: wait_for_vpn watcher
        tmux send-keys -t "$SESSION:Network.1" \
            "source '$SCRIPT_DIR/modules/network.sh' && wait_for_vpn '$HOME/vpn.log' && echo '[+] Tunnel confirmed.'" C-m

        # Bottom-right: Burp Pro — auto-creates or reopens project file
        tmux split-window -v -t "$SESSION:Network.1" -p 60
        tmux send-keys -t "$SESSION:Network.2" \
            "echo '[*] Burp project: $BURP_PROJECT'; echo ''; burpsuite --project-file='$BURP_PROJECT' 2>/dev/null || { echo '[!] burpsuite not found in PATH.'; read -r; }" C-m
    else
        # VPN skipped — show notice, launch Burp directly
        tmux send-keys -t "$SESSION:Network" \
            "echo '[*] VPN skipped.'; echo '[*] Burp project: $BURP_PROJECT'; echo ''" C-m
        tmux split-window -h -t "$SESSION:Network"
        tmux send-keys -t "$SESSION:Network.1" \
            "burpsuite --project-file='$BURP_PROJECT' 2>/dev/null || { echo '[!] burpsuite not found in PATH.'; read -r; }" C-m
    fi

    # ----------------------------------------------------------
    # TAB 4: Monitor  (PRESERVED — do not modify)
    #   Left  : tail -F summary.log
    #   Right : touch + watch -n 1 checklist.md
    # ----------------------------------------------------------
    tmux new-window -t "$SESSION" -n "Monitor"

    tmux send-keys -t "$SESSION:Monitor" \
        "echo '[*] Tailing summary.log...'; tail -F '$ROOM_DIR/logs/summary.log' 2>/dev/null" C-m

    tmux split-window -h -t "$SESSION:Monitor"
    tmux send-keys -t "$SESSION:Monitor.1" \
        "touch '$ROOM_DIR/checklist.md'; watch -n 1 cat '$ROOM_DIR/checklist.md'" C-m

    # ----------------------------------------------------------
    # Land on Tab 1, Pane 0 — Master Terminal (clean Zsh, focused)
    # ----------------------------------------------------------
    tmux select-window -t "$SESSION:Control"
    tmux select-pane -t "$SESSION:Control.0"
    tmux attach-session -t "$SESSION"
}

# ============================================================
# ENTRY POINT
# ============================================================
master_menu
