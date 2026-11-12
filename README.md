# Rummy Points Calculator

A Flutter app (Android) for keeping score in home rummy games.

- Each round has one winner, who collects the points every other player loses
  (winner gets a plus score, everyone else a minus score).
- Quick buttons for Drop / Middle drop / Full count (configurable, default 20 / 40 / 80).
- Players can start with any points, including negative, to continue a game from the middle.
- Add players mid-game, mark players as not playing, edit or undo rounds.
- Every game is saved automatically with its date; a new game can carry the totals over.

See [Rummy Points - How to Use.pdf](Rummy%20Points%20-%20How%20to%20Use.pdf) for a user guide.

## Build

```
flutter pub get
flutter test
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`.

Note: `android/gradle.properties` sets `kotlin.incremental=false`, which is needed
when the project and the pub cache are on different drives on Windows.
