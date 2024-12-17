import Settings
import SwiftUI
import Observation
import Combine

final class ExampleObj: Codable {
  let value: Int
  
  init(value: Int = 0) {
    self.value = value
  }
}

@Settings
final class ExampleSettings {
  public var foo: String = "bar"
  public var bar: Int = 42
  public var exampleObj: ExampleObj = ExampleObj()
}

let settings = ExampleSettings()

@MainActor func printSettings() {
  print(settings.foo)
  print(settings.bar)

  print("user defaults:")
  print(UserDefaults.standard.string(forKey: ExampleSettings.SettingKeys.foo.rawValue))
  print(UserDefaults.standard.string(forKey: ExampleSettings.SettingKeys.bar.rawValue))
  print(UserDefaults.standard.string(forKey: ExampleSettings.SettingKeys.exampleObj.rawValue))
  print("\r")
}

print("before setting ------")

printSettings()

print("after setting ------")

settings.foo = "baz"
settings.bar = 10
settings.exampleObj = ExampleObj(value: 100)

printSettings()

print("reset ------")

settings.reset()

printSettings()

@MainActor
class TestObservation {
  var cancellables: Set<AnyCancellable> = []
  
  func observe() {
    settings.$foo.receive(on: RunLoop.main).sink { foo in
      print("changed foo to \(foo)")
    }.store(in: &cancellables)
    
    settings.$bar.receive(on: RunLoop.main).sink { foo in
      print("changed bar to \(foo)")
    }.store(in: &cancellables)
    
    settings.$exampleObj.receive(on: RunLoop.main).sink { foo in
      print("change exampleObj to \(foo)")
    }.store(in: &cancellables)
  }
}

let observation = TestObservation()
observation.observe()

settings.foo = "update_foo"
settings.bar = 45
settings.exampleObj = ExampleObj(value: 200)

// run for 500 milliseconds
RunLoop.main.run(until: .now + 0.5)
