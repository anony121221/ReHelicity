# ReHelicity - Automated Helicity Server Reroller

An AutoHotkey script that automatically rerolls Roblox Helicity servers until it finds one matching your specified weather criteria.

## Features

- Automatic server rerolling - Joins and leaves servers until perfect conditions are found
- OCR-based detection - Uses Tesseract OCR to read thermodynamics data
- Customizable filters - Set target risk levels and optional filters for lapse rate, wind shear, CAPE, dew point, and humidity
- Discord webhook notifications - Get pinged when a good server is found
- Draggable calibration - Easy visual calibration with a hollow white box overlay
- Auto-detection - Automatically finds the thermos interface on first run

## Requirements

1. Windows 10/11
2. AutoHotkey v2.0
3. Tesseract OCR
4. Roblox - Installed and logged in
5. Private server link for Helicity game

## Installation

### Step 1: Install AutoHotkey v2.0

Download and install from: https://www.autohotkey.com/download/ahk-v2.exe

### Step 2: Install Tesseract OCR

1. Download from: https://github.com/UB-Mannheim/tesseract/wiki
2. Run the installer and install to the default location: `C:\Program Files\Tesseract-OCR\`
3. During installation, make sure to select "Add to PATH"

### Step 3: Download ReHelicity Script

1. Download the latest `ReHelicity.ahk` file from the releases page
2. Save it anywhere on your computer
3. Double-click the script to run it
4. The script will automatically copy itself to `C:\Users\[YourName]\Downloads\ReHelicity\`

## Configuration

### Basic Setup

1. Open the ReHelicity GUI
2. Go to the Config tab
3. Enter your private server link in the "Server Link" field
   - Format: `https://www.roblox.com/games/17759606919/Helicity-1-8-4?privateServerLinkCode=YOUR_CODE_HERE`
4. Select your target risk level (TSTM, MARGINAL, ENHANCED, SLIGHT, MODERATE, HIGH)

### Optional Filters

Enable and configure additional filters in the Main tab:

- Lapse Rate - Temperature change with altitude (max 10 C)
- Wind Shear - Wind speed change (max 55 kts)
- CAPE - Convective Available Potential Energy (max 7000 J/Kg)
- Dew Point - Moisture content (max 90 F)
- Relative Humidity - Humidity percentage (max 100%)

Each filter has a comparison operator (>=, <=, =) and a target value.

### Discord Webhook (Optional)

1. Create a Discord webhook in your server settings
2. Go to Config tab
3. Paste webhook URL
4. Optionally add User ID or Role ID for pings
5. Enable "Enable Webhook Notifications"

### Bloxstrap Support (Optional)

If you use Bloxstrap instead of regular Roblox:
1. Go to Config tab
2. Check "Use Bloxstrap"

## How to Use

### First Time Setup - Calibration

The script needs to know where the thermos interface appears on your screen.

#### Method 1: Auto-Detection (Recommended)

1. Open Roblox and join your private server
2. Open the thermos interface in-game
3. Press F2 to start the reroller
4. The script will automatically detect the thermos position

#### Method 2: Manual Calibration

1. Open Roblox and join your private server
2. Open the thermos interface in-game
3. Press F6 to open manual calibration
4. A white hollow box will appear
5. Drag and resize the box to cover the entire thermos interface
6. Press ENTER to confirm or ESC to cancel

### Running the Reroller

1. Make sure Roblox is closed
2. Configure your target risk level and filters
3. Press F2 or click "Start" button
4. The script will:
   - Launch Roblox
   - Join your private server
   - Navigate to spawn
   - Open the thermos
   - Read the weather data
   - Leave and rejoin if conditions don't match
5. When a good server is found:
   - A popup will appear with server details
   - You can choose to continue rerolling or stay in the server
   - If webhook is enabled, you'll get a Discord notification

### Hotkeys

- F2 - Start/Stop reroller
- F3 - Stop reroller
- F4 - Test OCR (reads current thermos data)
- F5 - Reset OCR region (clears calibration)
- F6 - Manual calibration (draggable box)

## Troubleshooting

### Tesseract Not Found

Error: "Tesseract not found at: C:\Users\...\Tesseract-OCR\tesseract.exe"

Solution:
1. Reinstall Tesseract to the default location
2. Or edit line 32 in the script to point to your Tesseract installation
3. Make sure tesseract.exe is in the correct folder

### OCR Not Reading Thermos

Error: "Failed to parse risk level" or "Dew Point not found"

Solution:
1. Press F5 to reset the OCR region
2. Press F6 to manually calibrate
3. Make sure the white box covers the entire thermos interface
4. Press F4 to test if OCR is working
5. Check the debugging folder for screenshots: `C:\Users\[YourName]\Downloads\ReHelicity\debugging\`

### Permission Error When Joining Server

Error: "You do not have permission to join this game"

Solution:
1. Make sure your private server link is valid and not expired
2. Test the link by pasting it directly in a web browser
3. Make sure you're logged into the correct Roblox account
4. Private servers expire after inactivity - you may need a new link
5. Check that the link format is correct in the Config tab

### Script Won't Leave Game

Error: "Failed to leave game, forcing close"

Solution:
1. The leave delay has been increased to 100ms per keypress
2. Make sure Roblox window is not minimized
3. Try adjusting "Key Press Delay" in Config > Timing Settings
4. The script will force-close Roblox if leave fails

### Roblox Window Not Detected

Error: "Roblox window not found"

Solution:
1. Make sure RobloxPlayerBeta.exe is running
2. Check if your antivirus is blocking AutoHotkey
3. Run the script as administrator
4. Make sure Roblox is not running in compatibility mode

### Menu Detection Timeout

Error: "Timeout waiting for menu"

Solution:
1. Increase "Wait After Join" in Config > Timing Settings
2. Your computer may need more time to load Roblox
3. Make sure your internet connection is stable
4. Try restarting Roblox completely

### Calibration Box Won't Close

Solution:
1. Press ESC to cancel calibration
2. The box should disappear immediately
3. If stuck, close the instruction window manually
4. Restart the script if necessary

## File Locations

- Script: `C:\Users\[YourName]\Downloads\ReHelicity\ReHelicity.ahk`
- Settings: `C:\Users\[YourName]\Downloads\ReHelicity\settings\helicity_settings.ini`
- Logs: `C:\Users\[YourName]\Downloads\ReHelicity\debugging\helicity_log.txt`
- Screenshots: `C:\Users\[YourName]\Downloads\ReHelicity\debugging\`

## Advanced Configuration

### Timing Settings

Adjust these in Config > Timing Settings if the script is too fast/slow:

- Key Press Delay - Delay between key presses (default 150ms)
- Wait After Join - How long to wait after joining server (default 18 seconds)
- Spawn Delay - Delay after spawning (default 4 seconds)

### Editing Settings Manually

You can edit `helicity_settings.ini` directly with a text editor for advanced configuration.

## Credits

- OCR: Tesseract OCR by Google
- Script: AutoHotkey v2.0
- Game: Helicity by Roblox developers
- Thanks to ReTwisted for the idea! Go check them out here: https://github.com/Okmada/ReTwisted

## License

This script is provided as-is for personal use. Use at your own risk.

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review the log file in the debugging folder
3. Make sure all requirements are properly installed
4. Try resetting OCR calibration (F5) and recalibrating (F6)
