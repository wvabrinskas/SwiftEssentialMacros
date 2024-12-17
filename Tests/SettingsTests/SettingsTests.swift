import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(SettingsMacros)
import SettingsMacros

let testMacros: [String: Macro.Type] = [
    "Settings": SettingsImplMacro.self
]
#endif

final class SettingsTests: XCTestCase {
  func testMacro() throws {
      #if canImport(SettingsMacros)
      assertMacroExpansion(
          """
          @Settings
          public final class ExampleSettings {
             var foo: Int = 42 
          }
          """,
          expandedSource: """
          public final class ExampleSettings {
             @Published
             var foo: Int = 42 

              var cancellables: Set<AnyCancellable> = []

              deinit {
                cancellables.forEach { value in
                    value.cancel()
                }
                cancellables.removeAll()
              }

              public enum SettingKeys: String {
                  case foo
              }

              public init() {
                  self.foo = UserDefaults.standard.value(forKey: ExampleSettings.SettingKeys.foo.rawValue) as? Int ?? 42
                  subscribe()
               }

              public func reset() {
                  foo = 42
              }

              internal func subscribe() {
                  $foo.sink { value in
                    UserDefaults.standard.set(value, forKey: ExampleSettings.SettingKeys.foo.rawValue)
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
