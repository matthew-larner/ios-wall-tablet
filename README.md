# ios Wall Tablet
iOS app that can be controlled via MQTT for use as a wall tablet.


## Settings to enable on the iOS device
### Guided Access
Guided access allows you to lock down access to only 1 app (this app) and stops the display locking. You can close the app by entering a 4 digit passcode.

1. Open the **Settings** app.
2. Go to **Accessibility**.
3. Scroll down and tap **Guided Access**.
4. Toggle **Guided Access** to ON.
5. Tap **Passcode Settings** to:
   - Set a passcode to control Guided Access.
6. Set **Display auto-lock** to 'Never'
7. You can then open the `MQTT Kiosk` app and triple-press the home lock button to enable guided access.

### Reduce White Point
iOS doesn't allow you to programatically turn off the display. To overcome this, we can enable the Reduced White Point accessibilty feature. This will allow the app to dim brightness down to nearly 0%.

1. Open the **Settings** app.
2. Navigate to **Accessibility**.
3. Tap **Display & Text Size**.
4. Scroll down and toggle **Reduce White Point** to ON.
5. Move the intensity slider to 100%

