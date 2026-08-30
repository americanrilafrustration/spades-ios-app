# Spades for iOS

Native SwiftUI port of the Android Spades app. Same rules, navy/gold theme, vs-AI play, and same-Wi-Fi friends tables.

iPhone and Android can sit at the same table on the same Wi-Fi. One device hosts; the other finds that table and joins.

## Open on a Mac

1. Copy this repo to a Mac, or clone it there.
2. Open `ios/Spades/Spades.xcodeproj` in Xcode 15 or later.
3. Select the **Spades** scheme and an iPhone simulator or device.
4. Set your **Team** under Signing & Capabilities (needed for a real device).
5. Run (⌘R). Allow **Local Network** when iOS asks, so friends can find your table.

Minimum iOS: **16.0**. Portrait only.

## Features

- Play vs AI (Cam, Reese, Quinn) as a team or individually
- Nil scoring and 10-bag penalty toggles (same defaults as Android: Nil off, bags on)
- Friends lobby: host or find a table on the same Wi-Fi
- 2–4 humans; 2 or 3 play individually; 4 can play teams or individual
- Host picks winning score and bag penalty
- Mid-game leave fills the seat with AI; same name can rejoin for 5 minutes
- Edge swipe back: lobby returns home; in-game asks before ending

## Friends play

Use two phones on the same Wi-Fi — two iPhones, two Androids, or one of each. One taps **Host table**, the other taps **Find table** and **Join**. Allow **Local Network** on iPhone. The host starts when at least two people are seated.

## TestFlight / App Store

Needs a Mac, Xcode, and a paid [Apple Developer Program](https://developer.apple.com/programs/) membership ($99/year). In Xcode: Product → Archive → Distribute App.
