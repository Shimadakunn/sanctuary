Correct! Picture-in-Picture does NOT work on the iOS Simulator - it only
  works on real devices. Here's how to test on your iPhone:

  How to Run on Your iPhone:

  1. Connect Your iPhone

  - Connect your iPhone to your Mac using a USB cable (or USB-C cable for
  newer iPhones)
  - Unlock your iPhone

  2. Trust This Computer (First time only)

  - On your iPhone, you'll see a popup: "Trust This Computer?"
  - Tap Trust and enter your passcode

  3. Select Your iPhone in Xcode

  - In Xcode, look at the top toolbar
  - Click on the device selector (currently shows "iPhone Simulator" or
  similar)
  - Your iPhone should appear in the list under "iOS Device"
  - Select your iPhone (e.g., "Leo's iPhone")

  4. Enable Developer Mode (iOS 16+, First time only)

  - On your iPhone, go to: Settings → Privacy & Security → Developer Mode
  - Toggle Developer Mode ON
  - Restart your iPhone when prompted

  5. Sign Your App (If needed)

  In Xcode:
  - Select the Sanctuary project in the left sidebar
  - Select the Sanctuary target
  - Go to Signing & Capabilities tab
  - Under Team, select your Apple ID (or add it if not present)
  - Xcode will automatically handle code signing

  6. Build and Run

  - Press ⌘ + R or click the Play button ▶️ in Xcode
  - The app will install and launch on your iPhone
  - First time: You may need to trust the developer certificate on your
  iPhone:
    - Go to Settings → General → VPN & Device Management
    - Tap your Apple ID
    - Tap Trust "[Your Apple ID]"

  7. Test Picture-in-Picture

  1. Open a video website (try Vimeo or DailyMotion)
  2. Play a video
  3. Enter fullscreen mode
  4. Look for the PiP button (overlapping rectangles icon)
  5. OR press the home button - video should automatically enter PiP mode

  That's it! The app will now run on your actual iPhone and PiP will work. 📱

