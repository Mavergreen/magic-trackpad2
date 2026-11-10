# Magic Trackpad 2 for Mavericks

Magic Trackpad 2 driver for Mac OS X 10.9 Mavericks.

## How it works

The big half is `MavericksTerminalBackend`, an implementation of `VoodooInputTerminal` for 10.9. Along with a verbatim copy of [upstream's](https://github.com/acidanthera/VoodooInput) `VoodooInput` mux, it's enough for existing VoodooInput device drivers ("satellite readers") to build and run on Mavericks unmodified.

The small half is the new satellite readers. `MT2USBReader` and `MT2BTReader` translate their input to the period-appropriate wire format recognized by 10.9's `hidd` from the original Magic Trackpad and laptop trackpads of the era. In exchange, gestures are processed natively by the system.

The third half is the SIMBL plugin. It runtime-nudges 10.9's Trackpad and Bluetooth prefpanes to recognize and talk to our devices.
