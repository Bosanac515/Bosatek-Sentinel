#!/bin/bash
# BOSATEK SENTINEL V3.8 - OLLAMA & CLEAN FFUF

# 1. CLEANUP
tmux kill-server 2>/dev/null

# 2. MENU
clear
echo "--- BOSATEK SENTINEL V3.8 ---"
echo "[1] New Engagement"
echo "[2] Tool Test"
echo "[3] Exit"
read -p "Selection: " CHOICE

if [[ "$CHOICE" == "3" || -z "$CHOICE" ]]; then exit; fi

# 3. TARGETING
if [ "$CHOICE" == "2" ]; then
    TARGET="10.10.10.10"
    ROOM="Test_Room"
else
    read -p "Target (e.g., bosatek.com): " TARGET
    read -p "Room Name: " ROOM
    [ -z "$TARGET" ] && { echo "Target required."; exit 1; }
    [ -z "$ROOM" ]   && ROOM="My_Room"
fi

# 4. PREP
ROOM_DIR="$HOME/Documents/GitHub/Bosanac-Writeups/$ROOM"
mkdir -p "$ROOM_DIR"

# 5. START TMUX (5 TABS)
tmux new-session -d -s sentinel -n 'Master'
tmux new-window -t sentinel:1 -n 'RustScan'
tmux new-window -t sentinel:2 -n 'FFUF'
tmux new-window -t sentinel:3 -n 'Burp'
tmux new-window -t sentinel:4 -n 'AI_Brain'

# --- TAB 0: MASTER ---
tmux send-keys -t sentinel:Master "alias exit-sentinel='tmux kill-server'" C-m
tmux send-keys -t sentinel:Master "clear && echo 'TARGET: $TARGET' && zsh" C-m

# --- TAB 1: RUSTSCAN ---
tmux send-keys -t sentinel:RustScan "rustscan -a $TARGET -- -A -sC" C-m

# --- TAB 2: FFUF (CLEAN PROGRESS) ---
# -c for colour, -mc 200 for hits only, no -v noise
FFUF_CMD="ffuf -w ~/Desktop/wordlists/dirb/common.txt -u http://$TARGET/FUZZ -e .php,.html,.txt -t 100 -mc 200 -c"
tmux send-keys -t sentinel:FFUF "$FFUF_CMD" C-m

# --- TAB 3: BURP PRO ---
tmux send-keys -t sentinel:Burp "/opt/BurpSuitePro/BurpSuitePro --project-file=\"$ROOM_DIR/$ROOM.burp\" &>/dev/null" C-m

# --- TAB 4: AI BRAIN (OLLAMA) ---
# Change model name if needed (e.g. mistral, llama3:8b, bosatek-sentinel)
tmux send-keys -t sentinel:AI_Brain "ollama run sentinel-brain" C-m

# ATTACH
tmux select-window -t sentinel:Master
tmux attach-session -t sentinel
