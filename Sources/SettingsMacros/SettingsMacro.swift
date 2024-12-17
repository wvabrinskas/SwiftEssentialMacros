import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum SettingsError: Error, CustomStringConvertible {
    case unknownVariable
    case typeAnnotationMissing(String)

    var description: String {
        switch self {
        case .unknownVariable:
          return "Unable to parse variable declaration."
        case .typeAnnotationMissing(let message):
          return "Type annotation is required. Please provide one for \(message)."
        }
    }
}

public struct SettingsImplMacro: MemberMacro, MemberAttributeMacro {
  public static func expansion(of node: SwiftSyntax.AttributeSyntax,
                               attachedTo declaration: some SwiftSyntax.DeclGroupSyntax,
                               providingAttributesFor member: some SwiftSyntax.DeclSyntaxProtocol,
                               in context: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.AttributeSyntax] {
    return [AttributeSyntax(atSign: .atSignToken(),
                            attributeName: IdentifierTypeSyntax(name: .identifier("Published")))]
  }
  
  public static func expansion(of node: AttributeSyntax,
                               providingMembersOf declaration: some DeclGroupSyntax,
                               in context: some MacroExpansionContext) throws -> [DeclSyntax] {
    guard let protocolDecl = declaration.as(ClassDeclSyntax.self) else {
      // throw error
      return []
    }

    let variables = protocolDecl.memberBlock.members.compactMap { $0.decl.as(VariableDeclSyntax.self) }

    var syntaxString = SyntaxStringInterpolation(literalCapacity: variables.count,
                                                 interpolationCount: variables.capacity)
    
    var resetSyntaxString = SyntaxStringInterpolation(literalCapacity: variables.count,
                                                      interpolationCount: variables.capacity)
    
    var subscriptionString = SyntaxStringInterpolation(literalCapacity: variables.count + 2,
                                                       interpolationCount: variables.capacity)
    
    subscriptionString.appendLiteral("{ \n")
  
    var initString = SyntaxStringInterpolation(literalCapacity: variables.count + 2,
                                               interpolationCount: variables.capacity)
    
    initString.appendLiteral("{ \n self.userDefaults = userDefaults \n")

    for variableDecl in variables {
        guard let variableValue = variableDecl.bindings.first?.initializer?.value,
              let variableName = variableDecl.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
          throw SettingsError.unknownVariable
        }
        resetSyntaxString.appendLiteral("\(variableName) = \(variableValue)\n")
        
        syntaxString.appendLiteral("case \(variableName) \n")
        
        subscriptionString.appendLiteral("""
                                          $\(variableName).sink { [userDefaults] value in
                                            userDefaults.set(value, forKey: ExampleSettings.SettingKeys.\(variableName).rawValue)
                                          }.store(in: &cancellables) \n\n
                                          """)
        
        guard let variableType = variableDecl.bindings.first?.typeAnnotation?.type.as(IdentifierTypeSyntax.self)?.name.text else {
          throw SettingsError.typeAnnotationMissing(variableName)
        }
        
        initString.appendLiteral("self.\(variableName) = userDefaults.value(forKey: ExampleSettings.SettingKeys.\(variableName).rawValue) as? \(variableType) ?? \(variableValue)\n")
    }
    
    subscriptionString.appendLiteral("}")
    initString.appendLiteral("subscribe() \n }")

    let enumSyntax = EnumDeclSyntax(modifiers: .init(itemsBuilder: {
      DeclModifierSyntax(name: .keyword(.public))
    }),
                                    name: .identifier("SettingKeys"),
                                    inheritanceClause: .init(inheritedTypes: .init(itemsBuilder: {
      InheritedTypeSyntax(type: IdentifierTypeSyntax(name: .identifier("String")))
    })),
                                    memberBlock: .init(members: .init(stringInterpolation: syntaxString)))
    
    let resetFunction = FunctionDeclSyntax(modifiers: DeclModifierListSyntax(itemsBuilder: {
      DeclModifierSyntax(name: .keyword(.public))
    }),
                                           funcKeyword: .keyword(.func),
                                           name: .identifier("reset"),
                                           signature: .init(parameterClause: .init(leftParen: .leftParenToken(),
                                                                                   parameters: .init(itemsBuilder: {}),
                                                                                   rightParen: .rightParenToken())),
                                           body: .init(leftBrace: .leftBraceToken(),
                                                       statements: .init(stringInterpolation: resetSyntaxString),
                                                       rightBrace: .rightBraceToken()))
  
    
    let cancellablesSyntax = VariableDeclSyntax(bindingSpecifier: .keyword(.var),
                                                bindings: .init(itemsBuilder: {
      PatternBindingSyntax(pattern: IdentifierPatternSyntax(identifier: .identifier("cancellables")),
                           typeAnnotation: TypeAnnotationSyntax(colon: .colonToken(),
                                                                type: IdentifierTypeSyntax(name: .identifier("Set"),
                                                                                           genericArgumentClause: .init(leftAngle: .leftAngleToken(),
                                                                                                                        arguments: .init(itemsBuilder: {
        GenericArgumentSyntax(argument: IdentifierTypeSyntax(name: .identifier("AnyCancellable")))
      })))),
                           initializer: .init(equal: .equalToken(), value: ArrayExprSyntax(leftSquare: .leftSquareToken(),
                                                                                           elements: .init(),
                                                                                           rightSquare: .rightSquareToken())))
    }))
    
    let userDefaultsSyntax = VariableDeclSyntax(bindingSpecifier: .keyword(.let),
                                                bindings: .init(itemsBuilder: {
      PatternBindingSyntax(pattern: IdentifierPatternSyntax(identifier: .identifier("userDefaults")),
                           typeAnnotation: TypeAnnotationSyntax(colon: .colonToken(),
                                                                type: IdentifierTypeSyntax(name: .identifier("UserDefaults"))))
    }))
    
    let deinitFunction = DeinitializerDeclSyntax(body: .init(stringLiteral: """
                                                                       {
                                                                         cancellables.forEach { value in value.cancel() }
                                                                         cancellables.removeAll()
                                                                       }
                                                                       """))
    
    
    // subscription
    
    let subscribeFunction = FunctionDeclSyntax(modifiers: .init(itemsBuilder: {
      .init(name: .keyword(.internal))
    }),
                                               name: .identifier("subscribe"),
                                               signature: .init(parameterClause: .init(parameters: .init(itemsBuilder: {}))),
                                               body: .init(stringInterpolation: subscriptionString))

    let initFunction = InitializerDeclSyntax(modifiers: .init(itemsBuilder: {
      .init(name: .keyword(.public))
    }),
                                             signature: .init(parameterClause: .init(parameters: .init(itemsBuilder: {
      .init(firstName: .identifier("userDefaults"),
            type: IdentifierTypeSyntax(name: .identifier("UserDefaults")),
            defaultValue: InitializerClauseSyntax(equal: .equalToken(), value: MemberAccessExprSyntax(period: .periodToken(), name: .identifier("standard"))))
    }))),
                                             body: .init(stringInterpolation: initString))
    
    let newMembers: [MemberBlockItemSyntax] = [.init(decl: cancellablesSyntax),
                                               .init(decl: userDefaultsSyntax),
                                               .init(decl: deinitFunction),
                                               .init(decl: enumSyntax),
                                               .init(decl: initFunction),
                                               .init(decl: resetFunction),
                                               .init(decl: subscribeFunction)]
    return newMembers.map { $0.decl }
  }
}

@main
struct SettingsPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
      SettingsImplMacro.self,
      SettingsObserveImplMacro.self,
      SettingsObserveDidSetMacro.self
    ]
}
