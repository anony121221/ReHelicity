Few things to keep in mind: 
1. ReHelicity is not released yet, and is planned to release some time this week.
2. This is 100% allowed and does not violate any terms of service. I am already being threatened by the helcity devs that I will be perm banned if this is released. This is just simply to make peoples life easier.

# ReHelicity

Automated server reroller for Helicity using OCR detection. Finds servers matching your criteria.

## Requirements

### 1. AutoHotkey v2.0
Download and install: https://www.autohotkey.com/

### 2. Tesseract OCR
Download installer: https://github.com/UB-Mannheim/tesseract/wiki

**Important:** Install to default location:
```
C:\Users\YOUR_USERNAME\AppData\Local\Programs\Tesseract-OCR\
```

If you install elsewhere, edit line 7 in the script to match your path.

## Setup

1. Download `ReHelecity.ahk` 
2. Once downloaded, open your downloads folder and double click to open.
3. Click the **Config** tab
4. Paste your private server link
5. Click the **Main** tab
6. Press **F5** to calibrate OCR region:
   - Open Roblox and display the thermos
   - Follow the countdown prompts
   - Position mouse at top-left, then bottom-right of thermos

## Usage

1. Set your target risk level (TSTM, MARGINAL, ENHANCED, SLIGHT, MODERATE, HIGH)
2. (Optional) Enable filters for Lapse Rate, Wind Shear, CAPE, and more.
3. Press **F2** to start rerolling
4. Press **F3** to stop

The script will:
- Launch Roblox
- Wait for main menu (automatic detection)
- Navigate to spawn
- Read thermos stats with OCR
- Reroll if conditions don't match
- Alert you when a good server is found

## Hotkeys

- **F2** - Start/Stop reroller
- **F3** - Force stop
- **F4** - Test OCR (make sure thermos is visible)
- **F5** - Calibrate OCR region

## Troubleshooting

**OCR not working?**
- Make sure Tesseract is installed correctly
- Run the calibration (F5) with thermos visible
- Test with F4 to verify detection

**Script not detecting menu?**
- Ensure Roblox window is not minimized
- Check that menu is fully loaded before it starts checking

**False positives/negatives?**
- Recalibrate OCR region (F5)
- Make sure thermos text is clearly visible
- Check logs tab for detection details

## Notes

- Requires a private server link
- Works with standard Roblox or Bloxstrap
- All settings saved automatically in `helicity_settings.ini`
- Logs saved to `helicity_log.txt`
