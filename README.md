# GlobeLangSwitch

A tiny menu bar app for macOS that switches your keyboard layout the moment you tap (press and quickly release) the **Globe (🌐)** key.

macOS can switch input sources with the Globe key by itself, but it can be slow: it sometimes puts a list of input sources in the middle of the screen and switches only after the list fades away. GlobeLangSwitch switches as soon as you release the key, in any app.

## Requirements

- macOS 13 Ventura or later, on a Mac with Apple silicon.
- An Apple keyboard with the Globe key (🌐; on older keyboards it's labeled fn): the built-in one or a Magic Keyboard.

## Installation

### Download

1. Download the **.dmg** file from the [latest release](https://github.com/vturekhanov/GlobeLangSwitch/releases/latest).
2. Open it and drag **GlobeLangSwitch** to the **Applications** folder in the window that appears.
3. Open the Applications folder in Finder and double-click **GlobeLangSwitch**. macOS asks whether you want to open an app downloaded from the internet: click **Open**. The app is signed with a Developer ID and notarized by Apple. A globe icon appears in the menu bar.

Start the app from the Applications folder, not from the disk image: Launch at Login remembers where the app is.

To update, quit GlobeLangSwitch, then drag the new version to Applications and choose **Replace**.

### Build from source

You need the Xcode Command Line Tools. Open Terminal and, if they aren't installed yet, run:

```bash
xcode-select --install
```

Then download the source and build the app:

```bash
git clone https://github.com/vturekhanov/GlobeLangSwitch.git
cd GlobeLangSwitch
./build.sh
```

When updating, get the latest source in the existing folder instead of cloning it again:

```bash
cd GlobeLangSwitch
git pull
./build.sh
```

This creates `build/GlobeLangSwitch.app`, signed ad hoc for the Mac it was built on. The script doesn't launch the app.

Before copying a new build, quit the running copy first, and remove the old app instead of copying over it: macOS may refuse to launch a signed app that was overwritten in place. Dragging the app to Applications in Finder and choosing **Replace** works too.

Copy the app to Applications. The first command removes a previous version, if there is one:

```bash
rm -rf /Applications/GlobeLangSwitch.app
ditto build/GlobeLangSwitch.app /Applications/GlobeLangSwitch.app
```

To start the app, open the Applications folder in Finder and double-click **GlobeLangSwitch**. A globe icon appears in the menu bar. There is no Dock icon.

## Setup

Open **System Settings › Keyboard** and set **Press 🌐 key to** to **Do Nothing**.

While it's set to anything else, an "!" sign appears next to the globe icon in the menu bar and the menu explains what to change.

## Usage

- **Tap the Globe key** to select the next input source.
- **Hold the Globe key** longer than the tap threshold (default: 300 ms) and nothing happens.
- **Use the Globe key with other keys** (arrows, Delete, F1–F12, media keys, or Shift, Control, Option, Command) and the shortcuts work as usual. The layout doesn't change.

The menu bar menu has:

- **Status**: Working, Paused, or Not receiving key events, followed by the app version.
- **Pause**: stops watching the keyboard completely until you resume.
- **Launch at Login**: off by default. Turn it on to start GlobeLangSwitch automatically when you log in.
- **Hide Layout Popup**: off by default. Turn it on, and macOS stops showing the layout popup next to the text cursor when GlobeLangSwitch switches the layout.
- **Tap Threshold**: from 100 to 500 ms, 300 ms by default.
- **Quit GlobeLangSwitch**.

## Privacy

GlobeLangSwitch doesn't ask you to grant any additional permissions, such as Input Monitoring or Accessibility.

It only receives changes of the modifier keys (Shift, Control, Option, Command, Caps Lock, Globe) and system-wide key counters, which tell how many keys were pressed but not which ones. That's enough to tell a lone tap of the Globe key from combinations with other keys. Keystrokes are never changed, blocked, stored, or logged, and the app never connects to the network. It saves only its own settings, and they stay on your Mac. Step 4 of [Uninstall](#uninstall) explains how to delete them.

GlobeLangSwitch runs in the App Sandbox, without access to the network or your files. It doesn't collect any personal data and doesn't share anything with anyone.

## Limitations

- **Open and Save dialogs.** If **Automatically switch to a document's input source** is on (System Settings › Keyboard › Input Sources › Edit…), the layout doesn't switch in these dialogs, because macOS restores the layout it remembers for them. Turn the setting off if this matters to you. The system shortcut ⌃⌥Space works there either way.
- **Password fields.** macOS allows only layouts that type Latin characters there, so other layouts can't be selected.
- **Caps Lock.** Switching the layout turns Caps Lock off. macOS does the same when it switches layouts itself.
- **Layout popup next to the text cursor.** Because of a macOS bug ([FB18799316](https://github.com/feedback-assistant/reports/issues/687)), this popup can keep showing the previous layout after a background app switches it. As a workaround, GlobeLangSwitch moves keyboard focus to an invisible panel for an instant right after each switch and then gives it back, so the app you're typing in picks up the new layout.
- **Hide Layout Popup.** It doesn't work together with **Automatically switch to a document's input source** (System Settings › Keyboard › Input Sources › Edit…): the layout switches back at once. While both are on, an "!" sign appears next to the globe icon in the menu bar and the menu explains what to change.
- **Future macOS versions.** GlobeLangSwitch relies on macOS sending it modifier key changes and key counters without any extra permissions. A future version of macOS may stop sending them. If that happens, the menu will show **Not receiving key events** and an "!" sign will appear next to the globe icon in the menu bar.

## Uninstall

1. In the GlobeLangSwitch menu, turn off **Launch at Login** if you turned it on.
2. Choose **Quit GlobeLangSwitch**.
3. Move **GlobeLangSwitch** from the Applications folder to the Trash.
4. Optionally, delete the saved settings: in Finder, choose **Go › Go to Folder…**, enter `~/Library/Containers`, and move the **GlobeLangSwitch** folder to the Trash.
5. Optionally, open **System Settings › Keyboard** and set **Press 🌐 key to** back to the option you used before installing GlobeLangSwitch.
