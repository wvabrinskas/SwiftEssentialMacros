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
    "SettingsDidSet": SettingsDidSetMacro.self
]
#endif
//
//public final class ExampleEvent {
//  @Published var foo = 42 {
//    didSet {
//      UserDefaults.standard.set(foo, forKey: "foo")
//    }
//  }
//  
//  init() {
//    foo = UserDefaults.standard.value(forKey: "foo") as? Int ?? 42
//  }
//  
//  func reset() {
//    foo = 42
//  }
//}

final class SettingsTests: XCTestCase {
  func testMacro() throws {
      #if canImport(SettingsMacros)
      assertMacroExpansion(
          """
          @Settings
          public final class ExampleSettings {
             @ObservationTracked
             var foo = 42 
          }
          """,
          expandedSource: """
          public final class ExampleSettings {
             @ObservationTracked
             @Published
             var foo {
                 @storageRestrictions(initializes: _foo)
                 init(initialValue) {
                   _foo = initialValue
                 }
                 get {
                   access(keyPath: \\.foo)
                   return _foo
                 }
                 set {
                    withMutation(keyPath: \\.foo) {
                        _foo = newValue
                       UserDefaults.standard.set(newValue, forKey: SettingKeys.foo.rawValue)
                    }
                 }
                 _modify {
                    access(keyPath: \\.foo)
                    _$observationRegistrar.willSet(self, keyPath: \\.foo)
                    defer {
                        _$observationRegistrar.didSet(self, keyPath: \\.foo)
                    }
                    yield &_foo
                 }
             }

              @ObservationIgnored private let _$observationRegistrar = Observation.ObservationRegistrar()

              public enum SettingKeys: String {
                  case foo
              }

              public func reset() {
                  foo = 42
              }

              internal nonisolated func access<Member>(keyPath: KeyPath<ExampleSettings, Member>) {
                  _$observationRegistrar.access(self, keyPath: keyPath)
              }

              internal nonisolated func withMutation<Member, MutationResult>(keyPath: KeyPath<ExampleSettings, Member>, _ mutation: () throws -> MutationResult) rethrows -> MutationResult {
                return try _$observationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
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
