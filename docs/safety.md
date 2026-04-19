# Safety

KeepAwake is intentionally conservative.

## Battery-Aware Auto Stop

You can configure the app to stop automatically when:

- battery drops below a chosen threshold
- Low Power Mode turns on

## Display Sleep Option

If you only want the Mac itself to stay awake, turn on **Allow Display Sleep**.

## Clean Session Lifecycle

Sessions end when:

- you toggle the icon off
- a timed duration expires
- a new duration replaces the current one
- battery rules trigger
- Low Power Mode triggers

When a session ends, the app releases its wake assertions.
