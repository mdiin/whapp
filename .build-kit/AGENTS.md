<!-- Generated from the slice-state event log. Record learnings with the learn command; do not edit. -->

## General
- Event structs: `Event, Equatable` required if used in a read-model state. BSD sed needs `-i ''`.
- ListLargeTitleHeader init is `(title:)`; don't duplicate navigationTitle with it.
- Don't name types `State` in slice namespaces with SwiftUI screens (clashes with @State); route params via Parameters struct + route.decode.
