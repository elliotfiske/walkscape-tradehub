---
name: testing-timing
description: Use when dealing with timing, delays, and time simulation in lamdera/program-test
---

# Timing in lamdera/program-test

## Time Simulation

The second argument to `Effect.Test.start` sets the simulated start time:

```elm
-- January 1, 2026 00:00:00 UTC
january1st2026 : Int
january1st2026 = 1767225600000

Effect.Test.start
    "My test"
    (Effect.Time.millisToPosix january1st2026)
    config
    [ ... ]
```

This affects:
- `Effect.Time.now` calls
- `Effect.Time.here` calls
- Any time-based logic in your app

## Action Delays

Each action has a delay parameter (first argument):

```elm
[ Effect.Test.backendUpdate 100 (...)  -- Wait 100ms, then trigger
, actions.checkView 200 (...)          -- Wait 200ms after previous
, actions.click 100 (...)              -- Wait 100ms after previous
]
```

**Delays are cumulative** - each relative to the previous action.

## Typical Delay Values

| Delay | Use Case |
|-------|----------|
| 100ms | Quick backend update or UI check |
| 200ms | Checking view after multiple updates |
| 500ms | After HTTP request/response cycle |
| 1000ms | Initial frontend connection |

## Time-based Mock Data

Calculate times relative to your test start time:

```elm
mockTimeEntry : Toggl.TimeEntry
mockTimeEntry =
    { id = Toggl.TimeEntryId 999
    , start = Time.millisToPosix (january1st2026 + (9 * 60 * 60 * 1000))  -- 9 AM
    , stop = Just (Time.millisToPosix (january1st2026 + (9 * 60 * 60 * 1000) + (30 * 60 * 1000)))  -- 9:30 AM
    , duration = 1800  -- 30 minutes in seconds
    , ...
    }
```

## Debugging Timing Issues

If tests are flaky or assertions fail unexpectedly:

```elm
-- Too quick, might not render
actions.checkView 10 (...)

-- Better
actions.checkView 100 (...)

-- Safer for complex updates
actions.checkView 200 (...)
```

## Visual Debugging

Navigate to `http://localhost:8000/tests/E2ETests.elm`:
- Use arrow keys (Left/Right) to step through timeline
- Click "clientId 0" to see frontend view at each step
- Timestamp shown at bottom of screen
