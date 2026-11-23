# Contributing

Thanks for helping! Keep changes small and focused.

- Build and test: `swift build && swift test` (macOS 14+, Swift 6).
- The scheduling rule lives in `Sources/BackupCadenceCore/Decision.swift` and must stay a pure function. Add a test in `Tests/BackupCadenceCoreTests` for every behavior change.
- Anything that talks to `tmutil` goes behind `TimeMachineClient` so tests can use a fake.
- Never run `tmutil enable/disable/startbackup` from tests.
- UI strings: English in code, Portuguese in `Resources/pt.lproj/Localizable.strings`.
- Open an issue first for larger features.
