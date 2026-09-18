# Sarvatobhadra Transit — Flutter APK

A GitHub-ready Flutter app for live Vedic transit exploration.

## What it does
- Uses **sidereal Lahiri** calculations.
- Shows Sun, Moon, Mars, Mercury, Jupiter, Venus, Saturn, Rahu and Ketu.
- For each planet: longitude, Nakshatra, Pada and retrograde/direct status.
- Shows the loaded SBC Front / Right / Left Vedha targets.
- Shows which current transit planets occupy the target Vedha Nakshatra.
- Search by planet name, Nakshatra or Pada.
- Date selector for checking another day.
- GitHub Actions builds a release APK.

## Calculation engine
The app uses `vedic_panchanga_dart`, a Dart port using Swiss Ephemeris for planetary positions and Lahiri sidereal calculations.

## SBC rule source
`lib/data/sbc_rules.json` is generated from the user's supplied 108-row SBC workbook. The app does not invent missing rules.

## Important accuracy note
The astronomical transit positions are calculated from Swiss Ephemeris. The **Vedha layer is a rule table** and should be kept separate from the ephemeris calculation. If you later replace the SBC table with a verified classical/pada-specific table, the calculation engine does not need to change.

## Build
1. Install Flutter.
2. `flutter pub get`
3. `flutter build apk --release`

Or push to GitHub and run **Actions → Build Android APK**. The APK is uploaded as an Actions artifact.

## Swiss Ephemeris licensing
Swiss Ephemeris is dual-licensed by Astrodienst. The AGPL route requires compatible source licensing; for a closed-source/commercial distribution, obtain the appropriate professional license. See the official Swiss Ephemeris repository and documentation.
