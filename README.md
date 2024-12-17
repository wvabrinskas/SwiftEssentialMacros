# Swift Essential Macros

| Macro | Description | Example |
|-------|-------------|---------|
| @Setting | Creates a settings property that can be persisted using UserDefaults. It also makes each property a `@Published` property. | `@Setting` |

## @Setting

### Usage
```swift
@Settings
final class ExampleSettings {
  public var foo: String = "bar"
  public var bar: Int = 42
}
```

### Expanded

```swift
@Settings
final class ExampleSettings {
  @Published
  public var foo: String = "bar"
  @Published
  public var bar: Int = 42

  var cancellables: Set<AnyCancellable> = []
  let userDefaults: UserDefaults

  deinit {
    cancellables.forEach { value in
        value.cancel()
    }
    cancellables.removeAll()
  }

  public enum SettingKeys: String {
      case foo
      case bar
  }

  public init(userDefaults: UserDefaults = .standard) {
      self.userDefaults = userDefaults
      self.foo = userDefaults.value(forKey: ExampleSettings.SettingKeys.foo.rawValue) as? String ?? "bar"
      self.bar = userDefaults.value(forKey: ExampleSettings.SettingKeys.bar.rawValue) as? Int ?? 42
      subscribe()
  }

  public func reset() {
      foo = "bar"
      bar = 42
  }

  internal func subscribe() {
      $foo.sink { [userDefaults] value in
        userDefaults.set(value, forKey: ExampleSettings.SettingKeys.foo.rawValue)
      } .store(in: &cancellables)

      $bar.sink { [userDefaults] value in
        userDefaults.set(value, forKey: ExampleSettings.SettingKeys.bar.rawValue)
      } .store(in: &cancellables)

  }
}
```
