# DesignTracker

**Version 1.0.0**

A small task tracker that sits on top of your screen while you work. I built it because I wanted something that stays in front of everything, shows my progress at a glance, and doesn't need a browser tab or an account.

DesignTracker is made with Godot 4 and runs as a single Windows `.exe`.

## What it does

- **Always on top.** A small window that stays in front of your other apps. Drag the top bar to put it anywhere on your screen.
- **Projects.** Keep a separate task list for each project (for example a game, a client job, a hobby). Switch between them from the project button at the top.
- **Progress circle.** The big ring shows the progress of the current project in %. The thinner inner ring shows your progress across all projects together.
- **Tasks with priority.** Every task can be HIGH, MED or LOW. Click the tag to change it.
- **Your own order.** Move tasks up or down with the arrows. The number in front of each task is its position.
- **Notes.** Add a note to any task.
- **Tracking.** Every task remembers when it was added and when you finished it. The dashboard shows Total, Done, Left and Done today.
- **Filters.** Show All, Active or Done tasks, and clear all finished tasks with one click.
- **Minimized mode.** Shrinks the app to just the project name, the circle and your next task, with a Mark done button.
- **Light and dark mode**, and adjustable size (60% to 130%).
- **Automatic saving.** Everything is saved the moment you change it. Nothing to press.

## Install (Windows)

1. Go to the **Releases** page of this repository.
2. Download `DesignTracker-1.0.0-windows.zip`.
3. Unzip it anywhere you like.
4. Double-click `DesignTracker.exe`.

There is no installer. To remove the app, delete the file.

**Windows warning:** because the app is not code-signed, Windows SmartScreen may say "Windows protected your PC". Click **More info**, then **Run anyway**.

## How to use it

**Add a task:** type in the field at the bottom and press Enter.

**Finish a task:** click the task name. Click it again to undo.

**Change a task:**
- ▲ ▼ move it up or down
- HIGH / MED / LOW changes the priority
- ✎ adds or edits a note (type it in the bottom field and press Enter)
- ✕ deletes it

**Switch or create a project:** click the project button under the top bar. Pick a project, or type a new name at the bottom of the list and press Enter. To delete a project, click ✕ next to it and confirm with **Sure?**.

**Clear finished tasks:** click **Clear**. The number on the button is how many tasks it will remove.

**Minimize:** click `–` in the top bar. The app shows your next task, which is the highest priority task that isn't done. If two tasks have the same priority, the one higher in your list wins. Click `▢` to go back.

**Settings:** click the gear. You can switch between light and dark mode and change the size with A- and A+.

**Move the window:** hold the left mouse button on the top bar and drag.

## Where your data is saved

Your tasks are stored locally in a file called `tracker_data.json`, in Godot's user data folder:

```
%APPDATA%\Godot\app_userdata\DesignTracker\
```

Nothing is sent online. To back up your tasks or move them to another computer, copy that file.

## Build it yourself

1. Install [Godot 4](https://godotengine.org/download).
2. Clone or download this repository.
3. Open Godot, click **Import**, and select `project.godot`.
4. In **Project Settings > Display > Window > Stretch**, set **Mode** to `disabled`.
5. Press F5 to run. If the window is embedded in the editor, turn off **Embed Game on Next Play** in the Game tab first.

All the logic lives in one script, `tracker.gd`.

## Known limits

- Windows only for now.
- No cloud sync.
- One window size at a time.

## Changelog

### 1.0.0
- First public release.

## License

Subject to the terms and conditions of this License, Accompanying Extraordinary Terms, and the Apache License, Version 2.0, or the MIT License, or any other open source license (the "Underlying License"), you are hereby granted the rights under the Underlying License, EXCEPT THAT the Underlying License is modified to exclude the right to sell, sublicense, or otherwise commercially exploit the Software.

"Commercial exploitation" includes, but is not limited to, providing the Software as a service, bundling the Software with other software or hardware, or using the Software to generate revenue, regardless of whether the Software itself is sold.

----------------------------------------------------------------------
THE MIT LICENSE

Copyright (c) 2026 Dominik - Red House studio

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Author

Made by Dominik at Red House studio.