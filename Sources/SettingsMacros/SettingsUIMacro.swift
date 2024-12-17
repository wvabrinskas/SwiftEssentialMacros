//
//  SettingsObserve.swift
//  Settings
//
//  Created by William Vabrinskas on 12/17/24.
//
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct SettingsObserveDidSetMacro: AccessorMacro, PeerMacro {
  public static func expansion(of node: SwiftSyntax.AttributeSyntax,
                               providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
                               in context: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.DeclSyntax] {
    guard let variableDecl = declaration.as(SwiftSyntax.VariableDeclSyntax.self),
          let identifierType = variableDecl.bindings.first?.typeAnnotation?.type,
          let variableName = variableDecl.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
          let variableValue = variableDecl.bindings.first?.initializer?.value else {
      return []
    }

    let ignoredVariable = VariableDeclSyntax(attributes: .init(itemsBuilder: {
      AttributeSyntax(atSign: .atSignToken(), attributeName: IdentifierTypeSyntax(name: .identifier("ObservationIgnored")))
    }),
                                                  modifiers: .init(itemsBuilder: {
      DeclModifierSyntax(name: .keyword(.private))
    }),
                                                  bindingSpecifier: .keyword(.var),
                                                  bindings: .init(itemsBuilder: {
      PatternBindingSyntax(pattern: IdentifierPatternSyntax(identifier: .identifier("_\(variableName)")),
                           typeAnnotation: .init(type: IdentifierTypeSyntax(name: .identifier("\(identifierType)"))),
                           initializer: InitializerClauseSyntax(equal: .equalToken(),
                                                                value: DeclReferenceExprSyntax(baseName: .identifier("\(variableValue)"))))
    }))
    
    return [.init(ignoredVariable)]
  }
  
  public static func expansion(of node: SwiftSyntax.AttributeSyntax,
                               providingAccessorsOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
                               in context: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.AccessorDeclSyntax] {
    guard let variableDecl = declaration.as(SwiftSyntax.VariableDeclSyntax.self),
          let variableName = variableDecl.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
      return []
    }

    let initializer = AccessorDeclSyntax(stringLiteral: """
    @storageRestrictions(initializes: _\(variableName))
    init(initialValue) {
      _\(variableName) = initialValue
    }
    """)
    
    let getter = AccessorDeclSyntax(stringLiteral: """
    get {
      access(keyPath: \\.\(variableName))
      return _\(variableName)
    }
    """)
    
    let setter = AccessorDeclSyntax(stringLiteral: """
    set {
       withMutation(keyPath: \\.\(variableName)) {
           _\(variableName) = newValue
          userDefaults.set(newValue, forKey: SettingKeys.\(variableName).rawValue)
       }
    }
    """)
    
    let modify = AccessorDeclSyntax(stringLiteral: """
    _modify {
       access(keyPath: \\.\(variableName))
       _$observationRegistrar.willSet(self, keyPath: \\.\(variableName))
       defer {
           _$observationRegistrar.didSet(self, keyPath: \\.\(variableName))
       }
       yield &_\(variableName)
    }
    """)
    
    return [initializer, getter, setter, modify]
  }
}

public struct SettingsObserveImplMacro: MemberMacro, MemberAttributeMacro, ExtensionMacro {
  public static func expansion(of node: SwiftSyntax.AttributeSyntax, attachedTo declaration: some SwiftSyntax.DeclGroupSyntax, providingExtensionsOf type: some SwiftSyntax.TypeSyntaxProtocol, conformingTo protocols: [SwiftSyntax.TypeSyntax], in context: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.ExtensionDeclSyntax] {
    
    // Generate the boilerplate extension code
    let decl: DeclSyntax = """
    extension \(type.trimmed): Observable {
    }
    """
    guard let extensionDecl = decl.as(ExtensionDeclSyntax.self) else {
        return []
    }
    
    return [extensionDecl]
  }
  
  public static func expansion(of node: SwiftSyntax.AttributeSyntax,
                               attachedTo declaration: some SwiftSyntax.DeclGroupSyntax,
                               providingAttributesFor member: some SwiftSyntax.DeclSyntaxProtocol,
                               in context: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.AttributeSyntax] {
    return [AttributeSyntax(atSign: .atSignToken(),
                            attributeName: IdentifierTypeSyntax(name: .identifier("SettingsObserveDidSet")))]
  }

  public static func expansion(of node: AttributeSyntax,
                               providingMembersOf declaration: some DeclGroupSyntax,
                               in context: some MacroExpansionContext) throws -> [DeclSyntax] {
    guard let protocolDecl = declaration.as(ClassDeclSyntax.self) else {
      // throw error
      return []
    }

    let observationRegistrar = VariableDeclSyntax(attributes: .init(itemsBuilder: {
      AttributeSyntax(atSign: .atSignToken(), attributeName: IdentifierTypeSyntax(name: .identifier("ObservationIgnored")))
    }),
                                                  modifiers: .init(itemsBuilder: {
      DeclModifierSyntax(name: .keyword(.private))
    }),
                                                  bindingSpecifier: .keyword(.let),
                                                  bindings: .init(itemsBuilder: {
      PatternBindingSyntax(pattern: IdentifierPatternSyntax(identifier: .identifier("_$observationRegistrar")),
                           initializer: InitializerClauseSyntax(equal: .equalToken(),
                                                                value: FunctionCallExprSyntax(calledExpression: MemberAccessExprSyntax(base: DeclReferenceExprSyntax(baseName: .identifier("Observation")),
                                                                                                                                       period: .periodToken(),
                                                                                                                                       declName: DeclReferenceExprSyntax(baseName: .identifier("ObservationRegistrar"))),
                                                                                              leftParen: .leftParenToken(),
                                                                                              arguments: .init(itemsBuilder: {}),
                                                                                              rightParen: .rightParenToken())))
    }))
    
    
    let withMutationFunction = FunctionDeclSyntax(modifiers: DeclModifierListSyntax(itemsBuilder: {
      DeclModifierSyntax(name: .keyword(.internal))
      DeclModifierSyntax(name: .keyword(.nonisolated))
    }),
                                                  funcKeyword: .keyword(.func),
                                                  name: .identifier("withMutation"),
                                                  genericParameterClause:       GenericParameterClauseSyntax(leftAngle: .leftAngleToken(),
                                                                                                             parameters: .init(itemsBuilder: {
      // generic parameters
      GenericParameterSyntax(name: .identifier("Member"),
                             trailingComma: .commaToken())
      GenericParameterSyntax(name: .identifier("MutationResult"))
    }),
                                                                                                             rightAngle: .rightAngleToken()),
                                                  signature: .init(parameterClause: .init(leftParen: .leftParenToken(),
                                                                                          parameters: .init(itemsBuilder: {
      // parameters
      FunctionParameterSyntax(firstName: .identifier("keyPath"),
                              colon: .colonToken(),
                              type: IdentifierTypeSyntax(name: .identifier("KeyPath"),
                                                         genericArgumentClause: GenericArgumentClauseSyntax(leftAngle: .leftAngleToken(), arguments: .init(itemsBuilder: {
        GenericArgumentSyntax(argument: IdentifierTypeSyntax(name: .identifier(protocolDecl.name.text)), trailingComma: .commaToken())
        GenericArgumentSyntax(argument: IdentifierTypeSyntax(name: .identifier("Member")))
      }))),
                              trailingComma: .commaToken())
      
      FunctionParameterSyntax(firstName: .wildcardToken(),
                              secondName: .identifier("mutation"),
                              colon: .colonToken(),
                              type: FunctionTypeSyntax(leftParen: .leftParenToken(),
                                                       parameters: .init(itemsBuilder: {}),
                                                       rightParen: .rightParenToken(),
                                                       effectSpecifiers: TypeEffectSpecifiersSyntax(throwsClause: ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))),
                                                       returnClause: ReturnClauseSyntax(arrow: .arrowToken(),
                                                                                        type: IdentifierTypeSyntax(name: .identifier("MutationResult")))))
      
    }),
                                                                                          rightParen: .rightParenToken()),
                                                                   effectSpecifiers: FunctionEffectSpecifiersSyntax(throwsClause: ThrowsClauseSyntax(throwsSpecifier: .keyword(.rethrows))),
                                                                   returnClause: ReturnClauseSyntax(arrow: .arrowToken(), type: IdentifierTypeSyntax(name: .identifier("MutationResult")))),
                                                  body: .init(leftBrace: .leftBraceToken(),
                                                              statements: .init(itemsBuilder: {
      CodeBlockItemSyntax(stringLiteral: """
        return try _$observationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
      """)
    }),
                                                              rightBrace: .rightBraceToken()))
    
    
    
    
    let accessFunction = FunctionDeclSyntax(modifiers: DeclModifierListSyntax(itemsBuilder: {
      DeclModifierSyntax(name: .keyword(.internal))
      DeclModifierSyntax(name: .keyword(.nonisolated))
    }),
                                                  funcKeyword: .keyword(.func),
                                                  name: .identifier("access"),
                                                  genericParameterClause:       GenericParameterClauseSyntax(leftAngle: .leftAngleToken(),
                                                                                                             parameters: .init(itemsBuilder: {
      // generic parameters
      GenericParameterSyntax(name: .identifier("Member"))
    }),
                                                                                                             rightAngle: .rightAngleToken()),
                                                  signature: .init(parameterClause: .init(leftParen: .leftParenToken(),
                                                                                          parameters: .init(itemsBuilder: {
      // parameters
      FunctionParameterSyntax(firstName: .identifier("keyPath"),
                              colon: .colonToken(),
                              type: IdentifierTypeSyntax(name: .identifier("KeyPath"),
                                                         genericArgumentClause: GenericArgumentClauseSyntax(leftAngle: .leftAngleToken(), arguments: .init(itemsBuilder: {
        GenericArgumentSyntax(argument: IdentifierTypeSyntax(name: .identifier(protocolDecl.name.text)), trailingComma: .commaToken())
        GenericArgumentSyntax(argument: IdentifierTypeSyntax(name: .identifier("Member")))
      }))))
      
    }),
                                                                                          rightParen: .rightParenToken())),
                                                  body: .init(leftBrace: .leftBraceToken(),
                                                              statements: .init(itemsBuilder: {
      
      // function body
      CodeBlockItemSyntax(item: .expr(.init(FunctionCallExprSyntax(calledExpression: MemberAccessExprSyntax(base: DeclReferenceExprSyntax(baseName: .identifier("_$observationRegistrar")),
                                                                                                                                                                  period: .periodToken(),
                                                                                                                                                                  declName: .init(baseName: .identifier("access"))),
                                                                                                                         leftParen: .leftParenToken(),
                                                                                                                         arguments: .init(itemsBuilder: {
        LabeledExprSyntax(expression: DeclReferenceExprSyntax(baseName: .keyword(.self)),
                          trailingComma: .commaToken())
        
        LabeledExprSyntax(label: .identifier("keyPath"),
                          colon: .colonToken(),
                          expression: DeclReferenceExprSyntax(baseName: .identifier("keyPath")))
      }),
                                                                                                                         rightParen: .rightParenToken()))))
    }),
                                                              rightBrace: .rightBraceToken()))
    
    

    let variables = protocolDecl.memberBlock.members.compactMap { $0.decl.as(VariableDeclSyntax.self) }

    var syntaxString = SyntaxStringInterpolation(literalCapacity: variables.count,
                                                 interpolationCount: variables.capacity)
    
    var resetSyntaxString = SyntaxStringInterpolation(literalCapacity: variables.count,
                                                      interpolationCount: variables.capacity)
    
    var initString = SyntaxStringInterpolation(literalCapacity: variables.count,
                                               interpolationCount: variables.capacity)
    
    initString.appendLiteral("{ \n self.userDefaults = userDefaults \n ")
    
    for variableDecl in variables {
      guard let variableValue = variableDecl.bindings.first?.initializer?.value,
            let variableName = variableDecl.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
        throw SettingsError.unknownVariable
      }
      resetSyntaxString.appendLiteral("\(variableName) = \(variableValue)\n")
      
      syntaxString.appendLiteral("case \(variableName) \n")
      
      guard let variableType = variableDecl.bindings.first?.typeAnnotation?.type.as(IdentifierTypeSyntax.self)?.name.text else {
        throw SettingsError.typeAnnotationMissing(variableName)
      }
      
      initString.appendLiteral("self.\(variableName) = userDefaults.value(forKey: ExampleSettings.SettingKeys.\(variableName).rawValue) as? \(variableType) ?? \(variableValue)\n")
    }
  
    initString.appendLiteral("\n }")

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
  
    let userDefaultsSyntax = VariableDeclSyntax(bindingSpecifier: .keyword(.let),
                                                bindings: .init(itemsBuilder: {
      PatternBindingSyntax(pattern: IdentifierPatternSyntax(identifier: .identifier("userDefaults")),
                           typeAnnotation: TypeAnnotationSyntax(colon: .colonToken(),
                                                                type: IdentifierTypeSyntax(name: .identifier("UserDefaults"))))
    }))
    
    let initFunction = InitializerDeclSyntax(modifiers: .init(itemsBuilder: {
      .init(name: .keyword(.public))
    }),
                                             signature: .init(parameterClause: .init(parameters: .init(itemsBuilder: {
      .init(firstName: .identifier("userDefaults"),
            type: IdentifierTypeSyntax(name: .identifier("UserDefaults")),
            defaultValue: InitializerClauseSyntax(equal: .equalToken(), value: MemberAccessExprSyntax(period: .periodToken(), name: .identifier("standard"))))
    }))),
                                             body: .init(stringInterpolation: initString))
    
    let newMembers: [MemberBlockItemSyntax] = [.init(decl: observationRegistrar),
                                               .init(decl: userDefaultsSyntax),
                                               .init(decl: enumSyntax),
                                               .init(decl: initFunction),
                                               .init(decl: resetFunction),
                                               .init(decl: accessFunction),
                                               .init(decl: withMutationFunction)]
    
    return newMembers.map { $0.decl }
  }
}
