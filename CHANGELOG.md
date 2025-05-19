# Changelog

All notable changes to this project will be documented in this file.

## [2.3] - 2025-05-19 
### Changed
- Improved menu positioning logic: The panel will now attempt to open in various preferred locations around the trigger button to avoid overlapping it, while also respecting screen boundaries.
- Fixed an issue where the trigger button's appearance might not update correctly when the panel was closed via the ESC key.
- Minor code cleanup and removal of unnecessary debug messages.


## [2.2] - 2025-05-18 
### Added
- New Trigger Button functionality:
    - Right Click (no modifiers): Resets the WoW sound system.
        - Provides chat feedback on action.
### Changed
- Updated Trigger Button tooltips to reflect new right-click action.
- Minor visual adjustments to trigger button icons for clarity.

## [2.1] - 2025-05-18 
### Added
- Chat feedback for output device changes made via the trigger button when the panel is closed.

### Changed
- Updated Trigger Button functionalities and tooltips:
    - Shift + Right Click: Now cycles to the next sound output device.
    - Alt + Left Click & Drag: Now used to move the button. (Previously Shift + Right Click & Drag)
    - Alt + Right Click: Now resets the button position. (Previously Alt + Left Click)
- Minor internal code adjustments for stability.

## [2.0] - 2025-05-18 
### Added
- Initial public release of Audio Control.
- Quick access panel for Master Volume, Music, Ambience, and Dialog settings.
- Output device selection with cycling (panel buttons) and dropdown menu.
- Movable trigger button with saved positions and status display (Master Volume % or Mute 'X').
- Slash commands: `/audioc` (or `/aca`) `toggle`, `/audioc resetmenu`.
- ESC key support to close the panel.
- Basic UI for sound adjustments.
