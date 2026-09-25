# Mac Media Key Forwarder

Mac Media Key Forwarder for [Apple Music](https://www.apple.com/apple-music/), [Spotify](https://www.spotify.com), [Cider](https://cider.sh), [Spotifast](https://spotifast.rocks) and [Pear Desktop](https://github.com/pear-devs/pear-desktop) (YouTube Music).

Forwards your keyboard media keys (play/pause, next, previous) to Apple Music, Spotify, Cider, Spotifast or Pear (YouTube Music) directly.

You can prioritize which app you would like to control or you can go with the default behaviour which controls the running app.

The status-bar menu holds the quick controls (pause and the prioritized player). Everything else — open at login, hiding the menu bar icon, automatic pause, and the Cider API token — lives in **Settings…** (⌘,).

The app runs in the menu bar.

**Cider support**

Apple Music and Spotify are controlled over AppleScript (Scripting Bridge). Cider does not ship an AppleScript dictionary, so it is controlled through its local REST API instead (`http://localhost:10767`). For it to work:

- In Cider, enable the RPC server under **Settings** > **Connectivity**.
- If Cider requires a token for external applications (**Manage External Application Access to Cider**), paste it into Mac Media Key Forwarder under **Settings… > Players**.

**Spotifast support**

Spotifast likewise ships no AppleScript dictionary. The running instance listens on a local loopback socket (`127.0.0.1:47113`) for its own `fastpotify` command-line tool, and Mac Media Key Forwarder talks to it the same way. No setup is required — just have Spotifast running.

**Pear Desktop (YouTube Music) support**

Pear does not ship an AppleScript dictionary either, so it is controlled through the local HTTP API of its API Server plugin (`http://localhost:26538`). For it to work:

- In Pear, enable the **API Server** plugin under **Plugins**.
- Keep its port at the default 26538.
- On the first media key press Pear asks whether to allow "MacMediaKeyForwarder"; approve it. The access token is stored and reused afterwards.

Download the compiled application from my [Releases](https://github.com/quentinlesceller/macmediakeyforwarder/releases).

If you want even more control over what you want to control you should try [beardedspice](http://beardedspice.github.io).

**Issues you should know about**

The app listens on the event tap for key events. This causes problems in some rare cases, like 
- when changing search engine in Safari's preferences window
- when trying to allow third-party kernel extensions

In these cases simply pause Mac Media Key Forwarder from it's menu.

**Requirements**

macOS 26 (Tahoe) or later. The app is signed with a Developer ID and notarized by Apple. For older systems, use version 3.1.2.

**Installation & permissions**

Mac Media Key Forwarder needs two permissions to work:

- **Accessibility**, so it can listen for the media keys on your keyboard.
- **Automation**, so it can tell Apple Music and Spotify to play, pause, or skip. This is why macOS shows an automation (osascript) prompt the first time you use a media key. The app only sends standard playback commands to those two apps and nothing else.

On first launch the app asks for Accessibility access and offers an **Open System Settings** button. Turn on **MacMediaKeyForwarder** under **Privacy & Security** > **Accessibility**, and the app starts forwarding right away. There is no need to relaunch it.

The Automation permission is requested the first time you press a media key. Allow **MacMediaKeyForwarder** to control **Music** and **Spotify** when prompted.

**Other milgra utilities you might be interested in**

[mac audio keepalive](https://github.com/milgra/macaudiokeepalive)

[airpods sound quality fixer](https://github.com/milgra/airpodssoundqualityfixer)

[fat fingers keyboard for iphone](https://github.com/milgra/fatfingerskeyboard)

---

**Contributors :** 
* Michael Dorner ([@michaeldorner](http://github.com/michaeldorner))
* Matt Chaput ([@mchaput](http://github.com/mchaput))
* Ben Kropf ([@ben-kropf](http://github.com/ben-kropf))
* Alejandro Iván ([@alejandroivan](http://github.com/alejandroivan))
* Sungho Lee ([@sh1217sh](http://github.com/sh1217sh))
* Björn Büschke ([@maciboy](http://github.com/maciboy))
* Sergei Solovev ([@e1ectron](http://github.com/e1ectron))
* Munkácsi Márk ([@munkacsimark](http://github.com/munkacsimark))
* Irvin Lim ([@irvinlim](https://github.com/irvinlim))
* Simon Seku ([@SimonSeku](https://github.com/SimonSeku))
* Dave Nicolson ([@dnicolson](https://github.com/dnicolson))
* teemue ([@teemue](https://github.com/teemue))
* takamu ([@takamu](https://github.com/takamu))
* Alex ([@sashoism](https://github.com/sashoism))
* Sebastiaan Pasma ([@spasma](https://github.com/spasma))
* WiktorBuczko ([@WiktorBuczko](https://github.com/WiktorBuczko))
* Andy White ([@arcwhite](https://github.com/arcwhite))
* xjbeta ([@xjbeta](https://github.com/xjbeta))
* Jules Coynel ([@jcoynel](https://github.com/jcoynel))

Thank you!!!

---

*What's new in version 4.2.0 :*
- Spotifast support: play/pause, next and previous now also work with [Spotifast](https://spotifast.rocks) (controlled through its local socket, no setup needed). New "Prioritize Spotifast" option. Thanks to @mdevils!
- New Settings window (⌘,) for open at login, hiding the menu bar icon, automatic pause and the Cider API token. The menu keeps the quick controls: Pause and the prioritized player.
- The Cider API token is entered in a masked field.
- Removed the Donate menu item.
- Fixed a media key press made while Spotifast was still starting up being replayed later.

*What's new in version 4.1.0 :*
- Cider support: play/pause, next and previous now also work with [Cider](https://cider.sh) (controlled through its local REST API — enable the RPC server in Cider under Settings > Connectivity, and use "Set Cider API Token…" in the menu if Cider requires a token).
- New "Prioritize Cider" option.
- The default mode is now called "Send events to all players" and includes Cider.
- Thanks to @andrwmai for testing!

*What's new in version 4.0.0 :*
- Rewritten in Swift.
- Fixes the freeze and hang on macOS Tahoe (the menu and app no longer become unresponsive).
- Signed with a Developer ID and notarized by Apple, so it launches without Gatekeeper warnings.
- Modern launch at login using SMAppService.
- Minimum macOS is now Tahoe (26). Use version 3.1.2 for older systems.
- New bundle identifier (com.quentinlesceller.macmediakeyforwarder). After updating you may need to re-grant Accessibility and Automation permissions once.

*What's new in version 3.1.2 :*
- Lower minimum version to macOS 10.14
- App is now signed.

*What's new in version 3.1.1 :*
- Fix freeze at launch
- Update for macOS 12.3

*What's new in version 3.1 :*
- Ability to hide the menu icon
- French translation

*What's new in version 3.0 :*
- Catalina compatibility

*What's new in version 2.8 :*
- Polish localization
- Fixed broken Japanese, Finnish, Dutch localization 

*What's new in version 2.7 :*
- Dutch localization 

*What's new in version 2.6 :*
- Enabled undocking status bar item 

*What's new in version 2.5 :*
- Finnish, Japanese localization
- Modified Accessibility Instructions

*What's new in version 2.3 :*
- Korean, Danish, Russian and Hungarian localization is linked back to the project ( they got lost somewhere :( )

*What's new in version 2.2 :*
- MacOS Mojave 10.14.2 fix, showing notification pop-up if tap cannot be created

*What's new in version 2.1 :*
- app brings up permission popups if permission is not granted for Accessibility and Automation Target

What's new in version 2.0 :
- app renamed to Mac Media Key Forwarder
- Hungarian localization
- updated icon
- Open At Login state is checked every time the menu is opened so it shows an updated state
- added installation steps to readme because increased MacOS security made it more confusing
- added event-tap related issues to readme because it can cause head scratches in some special cases 

What's new in version 1.9 :
- added open at login menu option
- German localization update
- Korean localization update

What's new in version 1.8 :
- added pause menu option
- added pause automatically menu option : if no music player is running macOS default behavior is used and keys are forwarded to currently active media player
- Russian localization
- German localization
- Spanish localization
- fixed headphone button issue
- added macOS Sierra compatibility if you want explicit music player control there

What's new in version 1.7 :
- fast forward/rewind is possible when iTunes is selected explicitly
- Korean localization
- rumors say that it works with TouchBar

What's new in version 1.6 :
- increased compatibility with external keyboards

What's new in version 1.5 :
- now you can explicitly prioritize iTunes or Spotify
- play button now starts up iTunes or Spotify if they are not running aaaand explicitly selected

What's new in version 1.4 :
- memory leak fixed

What's new in version 1.3 :
- previousTrack replaced with backTrack in case of iTunes for a better experience

What's new in version 1.2 :
- new icon
- source code is super tight now
- developer id signed, its a trusted app now

---
