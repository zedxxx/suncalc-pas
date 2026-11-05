# SunCalc Delphi — full console test suite

Framework-free port of [suncalc/test/accuracy.test.js](https://github.com/mourner/suncalc/blob/master/test/accuracy.test.js) and its supporting harness (`compare.js`, `moon-phases.json`). 
No DUnit or other test framework is used; the suite is a plain Delphi console program and only depends on the RTL (`System.JSON`, `System.IOUtils`, `System.Math`, ...).

## Contents

| File | Purpose |
| --- | --- |
| `SunCalcFullTest.dpr` | The test program and all test cases |
| `SunCalcFullTestSupport.pas` | Tiny assertion runner, fixture loader, statistics, ISO-8601 and angle helpers |
| `SunCalcFullTest.dproj` | IDE project (Win32/Win64), optional |
| `fixtures.json` | Vendored external truth from the JavaScript repo (JPL Horizons positions, USNO times) |
| `moon-phases.json` | USNO lunar-phase instants |

## Running

From the IDE: open `SunCalcFullTest.dproj` and press F9. The executable is written to `..\..\.bin\<Platform>`; the program locates `fixtures.json` relative to the executable, so running from the IDE works without changing the working directory.

From the command line (adjust the Studio version if needed):

```cmd
call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"
dcc32 -B -E..\..\.bin\Win32 ^
  -U"%BDS%\lib\win32\release" ^
  -NS"System;System.Win;Data;Datasnap;Web;Soap;Xml;Winapi" ^
  SunCalcFullTest.dpr
..\..\.bin\Win32\SunCalcFullTest.exe
```

You may pass the data directory as the first argument:

```cmd
SunCalcFullTest.exe C:\dev\suncalc\test\full
```

Exit codes: `0` = all tests passed, `1` = test failures, `2` = harness/data error. The runner prints `[ RUN ]`, `[ OK ]` / `[ FAILED ]` per test and a final summary of tests and individual checks.

## What is covered

Truth-anchored accuracy gates (identical fields and tolerances to `accuracy.test.js`):

- Sun position vs JPL Horizons: altitude, azimuth, angular separation
- Sun times vs USNO: sunrise, sunset, solar noon, dawn, dusk
- Moon position vs JPL Horizons: angular separation
- Moon illumination fraction and geocentric distance
- Moon times vs USNO: rise, set, upper transit, lower transit
- "No dropped samples": every USNO event must have a corresponding SunCalc time

Structural and regression tests:

- Polar day/night flags for `GetTimes`, including no invalid `TDateTime` values
- No-crossing flags for `GetMoonTimes`
- Issue #186: `AlwaysUp`/`AlwaysDown` agrees with the actual altitude sign
- Issue #187: `GetTimes` anchors the local solar day at every longitude
- Issue #189: `GetMoonTimes` scans the same local solar day as `GetTimes`
- Issue #191: grazing twilight/sunrise/sunset events, plus a full high-latitude sweep (every event inside its half day and at the configured altitude)
- UTC-offset overloads anchor both functions to the civil day (incl. the three historical regression cases and exact-midnight boundaries)
- Moon transits occur exactly once per ~24.8 h and skip about one day a month
- Issue #190: illumination phase crosses USNO phase instants (mean < 1 min, max < 2 min, measured by bisection)
- API contracts: documented angle domains, waxing/phase consistency, observer height semantics, and `NewSunCalcTimes` defaults

## Note on the library

The suite exposed an exact-midnight boundary bug in `civilMidnight` for non-dyadic UTC offsets (e.g. 480 minutes): the floating-point sum `date + offset` could land a few ulps below the integer day, making `Floor` select the previous civil day. `SunCalc.pas` now adds a ~86 µs boundary guard
there. Without that fix the “UTC offset anchors …” test fails on the `2022-04-14` (UTC+8), `2026-09-30` (UTC−4) and `2026-08-19` (UTC+5:45) cases.
