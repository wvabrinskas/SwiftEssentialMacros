import Settings
import SwiftUI
import Observation
import Combine

final class ExampleSettings {
  public var foo = "bar"
  public var bar: Int = 42
}

let settings = ExampleSettings()

//
//@MainActor func printSettings() {
//  print(settings.foo)
//  print(settings.bar)
//
//  print("user defaults:")
//  print(UserDefaults.standard.string(forKey: ExampleSettings.SettingKeys.foo.rawValue))
//  print(UserDefaults.standard.string(forKey: ExampleSettings.SettingKeys.bar.rawValue))
//  print("\r")
//}
//
//print("before setting ------")
//
//printSettings()
//
//print("after setting ------")
//
//settings.foo = "baz"
//settings.bar = 10
//
//printSettings()
//
//print("reset ------")
//
//settings.reset()
//
//printSettings()
//
//@MainActor
//class TestObservation {
//  var cancellables: Set<AnyCancellable> = []
//  
//  func observe() {
//    settings.$foo.receive(on: RunLoop.main).sink { foo in
//      print("changed foo to \(foo)")
//    }.store(in: &cancellables)
//    
//    settings.$bar.receive(on: RunLoop.main).sink { foo in
//      print("changed foo to \(foo)")
//    }.store(in: &cancellables)
//  }
//}
//
//let observation = TestObservation()
//observation.observe()
//
//settings.foo = "update_foo"
//settings.bar = 45
//
//// run for 1 second
//RunLoop.main.run(until: .now + 1)
