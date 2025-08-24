# wpa2-penetration-toolkit
A stealth-focused tool for capturing WPA2 handshakes and PMKIDs for authorized penetration testing.

# Stealth WPA2/WPA3 Penetration Tool

A Bash script designed for authorized penetration testing that focuses on capturing WPA2 handshakes and PMKIDs with techniques to minimize detection. It emphasizes stealth through passive capture, targeted attacks, and reduced radio frequency footprint.

**Disclaimer: This tool is for educational and authorized security testing purposes only. Unauthorized use against networks you do not own or have explicit permission to test is illegal. You are responsible for your own actions.**

## Features

*   **Stealth-First Approach:** Prioritizes passive attacks to avoid detection by Wireless Intrusion Detection Systems (WIDS).
*   **PMKID Capture:** Attempts a completely passive PMKID capture, requiring no deauthentication packets.
*   **Low-Profile Active Attacks:** If PMKID fails, uses minimal, targeted deauthentication with randomized delays to avoid threshold-based alarms.
*   **Reduced Transmission Power:** Attempts to lower the adapter's TX power to minimize physical footprint.
*   **Pre-Targeting:** Supports pre-configuration of target details to eliminate noisy scanning phases.
*   **Robust Cleanup:** Ensures your wireless interface is always returned to a managed state after execution.

## Prerequisites

*   **A Linux distribution** (Kali Linux, Parrot OS, or Ubuntu are recommended).
*   **A wireless network adapter** that supports monitor mode and packet injection. (e.g., Alfa AWUS036ACH, AWUS036NHA).
*   **Root privileges**.
*   **The `aircrack-ng` suite** installed.
    ```bash
    sudo apt update && sudo apt install aircrack-ng
    ```
*   **`hashcat`** (optional, but recommended for faster PMKID cracking).
    ```bash
    sudo apt install hashcat
    ```

## Installation

1.  Clone this repository:
    ```bash
    git clone https://github.com/VastScientist69/wpa2-penetration-toolkit.git
    cd wpa2-penetration-toolkit
    ```

## Usage

### 1. Pre-Configuration (Recommended for Stealth)
The most stealthy method is to avoid scanning altogether. To do this, pre-configure your target.

*   Copy the example config file:
    ```bash
    cp config/target_example.conf config/target.conf
    ```
*   Edit `config/target.conf` with the details of your **authorized** target:
    ```bash
    # Edit these values
    TARGET_BSSID="AA:BB:CC:DD:EE:FF" # The AP's MAC Address
    TARGET_CHANNEL="6"                # The AP's Wi-Fi channel
    TARGET_SSID="Your_Network_Name"   # The AP's SSID
    ```

### 2. Running the Script

1.  Navigate to the scripts directory:
    ```bash
    cd scripts
    ```
2.  Make the script executable:
    ```bash
    chmod +x stealth_wpa_crack.sh
    ```
3.  Run the script with root privileges:
    ```bash
    sudo ./stealth_wpa_crack.sh
    ```
4.  The script will:
    *   Check for dependencies.
    *   Put your interface into monitor mode.
    *   Attempt a passive PMKID capture for ~2 minutes.
    *   If unsuccessful, it will wait for a client and then perform a low-rate deauthentication attack.
    *   Analyze the capture file to confirm a handshake/PMKID was captured.
    *   Optionally attempt to crack the password immediately.

## How It Evades Detection

| Technique | Description | Why It's Stealthy |
| :--- | :--- | :--- |
| **PMKID Capture** | Listens for a specific data field sent by APs. | **100% Passive.** No packets are transmitted. Virtually undetectable. |
| **Targeted Deauth** | Sends deauth packets to a single client MAC address. | Mimics a network glitch instead of a broadcast attack, avoiding common IDS thresholds. |
| **Randomized Timing** | Waits long, random intervals between small deauth bursts. | Prevents triggering alarms that look for rapid, repeated attacks. |
| **Reduced TX Power** | Lowers the transmission power of the wireless adapter. | Physically reduces the range of your transmissions, making them harder to triangulate. |
| **Pre-Configured Target** | Uses a known BSSID/Channel instead of active scanning. | Eliminates the noisy `airodump-ng` scanning phase that is easily detected. |

## Troubleshooting

*   **Script fails to run:** Ensure you have all prerequisites installed and are running as root (`sudo`).
*   **"Interface does not support monitoring":** Your wireless adapter likely does not support monitor mode. Use a compatible adapter.
*   **No handshake captured:** Ensure you are within range of the target AP. If using deauth, a client must be actively connected. The target may be using WPA3, which is resistant to these attacks.
*   **Cracking fails:** The password is not in your wordlist. Use a larger, more comprehensive wordlist for better results.

## Legal and Ethical Notice

This tool is provided ** strictly for educational purposes and authorized penetration testing**. You must have **explicit, written permission** from the network owner before attempting to test any network.

Unauthorized access to computer networks is a serious crime in most jurisdictions. The developers and contributors of this tool are not responsible for any misuse or damage caused by this program.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
