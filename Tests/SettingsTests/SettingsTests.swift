import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(SettingsMacros)
import SettingsMacros

let testMacros: [String: Macro.Type] = [
    "Settings": SettingsImplMacro.self,
    "SettingsObserve": SettingsObserveImplMacro.self,
    "SettingsObserveDidSet": SettingsObserveDidSetMacro.self
]
#endif

final class SettingsTests: XCTestCase {
  func testUIMacro() throws {
      #if canImport(SettingsMacros)
      assertMacroExpansion(
          """
          @SettingsObserve
          public final class ExampleSettings {
             var foo: Int = 42 
          }
          """,
          expandedSource: """
          public final class ExampleSettings {
             @Published
             var foo: Int = 42 
            @Published

            public init(userDefaults: UserDefaults = .standard) {

            }

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
              }

              public init(userDefaults: UserDefaults = .standard) {
               self.userDefaults = userDefaults
               self.foo = userDefaults.value(forKey: ExampleSettings.SettingKeys.foo.rawValue) as? Int ?? 42
               subscribe()
               }

              public func reset() {
                  foo = 42
              }

              internal func subscribe() {
                  $foo.sink { [userDefaults] value in
                    userDefaults.set(value, forKey: ExampleSettings.SettingKeys.foo.rawValue)
                  } .store(in: &cancellables)

              }
          }
          """,
          macros: testMacros
      )
      #else
      throw XCTSkip("macros are only supported when running tests for the host platform")
      #endif
  }
  
  func testMacro() throws {
      #if canImport(SettingsMacros)
      assertMacroExpansion(
          """
          @Settings
          public final class ExampleSettings {
             var foo: Int = 42 
          
            public init(userDefaults: UserDefaults = .standard) {

            }
          }
          """,
          expandedSource: """
          public final class ExampleSettings {
             @Published
             var foo: Int = 42 
            @Published

            public init(userDefaults: UserDefaults = .standard) {

            }

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
              }

              public init(userDefaults: UserDefaults = .standard) {
               self.userDefaults = userDefaults
               self.foo = userDefaults.value(forKey: ExampleSettings.SettingKeys.foo.rawValue) as? Int ?? 42
               subscribe()
               }

              public func reset() {
                  foo = 42
              }

              internal func subscribe() {
                  $foo.sink { [userDefaults] value in
                    userDefaults.set(value, forKey: ExampleSettings.SettingKeys.foo.rawValue)
                  } .store(in: &cancellables)

              }
          }
          """,
          macros: testMacros
      )
      #else
      throw XCTSkip("macros are only supported when running tests for the host platform")
      #endif
  }
}
