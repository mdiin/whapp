<!-- Generated from the slice-state event log. Record learnings with the learn command; do not edit. -->

## General
- Event structs: `Event, Equatable` required if used in a read-model state. BSD sed needs `-i ''`.
- ListLargeTitleHeader init is `(title:)`; don't duplicate navigationTitle with it.
- Don't name types `State` in slice namespaces with SwiftUI screens (clashes with @State); route params via Parameters struct + route.decode.
- AppTableDetail(LocalizedStringKey) shows chevron unless `drillIn: false`. test.sh prints little; check exit code.
- Registering a command a screen uses (system.commands.isRegistered) changes that screen's snapshot: re-record it (delete images, run twice).
