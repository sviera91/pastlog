import SwiftUI

/// Drop-in for `@State`. SwiftUI's `@State` is now a compiler macro whose plugin ships only with Xcode,
/// so Command Line Tools builds can't expand it; this wrapper uses `@StateObject` instead.
@propertyWrapper
struct Local<Value>: DynamicProperty {
    final class Box: ObservableObject {
        @Published var value: Value
        init(_ value: Value) { self.value = value }
    }

    @StateObject private var box: Box

    init(wrappedValue: Value) { _box = StateObject(wrappedValue: Box(wrappedValue)) }

    var wrappedValue: Value {
        get { box.value }
        nonmutating set { box.value = newValue }
    }

    var projectedValue: Binding<Value> {
        let box = box
        return Binding(get: { box.value }, set: { box.value = $0 })
    }
}
