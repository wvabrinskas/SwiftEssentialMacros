import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct SettingsDidSetMacro: AccessorMacro {
  public static func expansion(of node: SwiftSyntax.AttributeSyntax,
                               providingAccessorsOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
                               in context: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.AccessorDeclSyntax] {
    guard let variableDecl = declaration.as(SwiftSyntax.VariableDeclSyntax.self),
          let identifierType = variableDecl.bindings.first?.typeAnnotation,
          let variableName = variableDecl.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
      return []
    }

    let initializer = AccessorDeclSyntax(stringLiteral: """
    @storageRestrictions(initializes: _\(variableName))
    init(initialValue) {
      _\(variableName) = UserDefaults.standard.value(forKey: SettingKeys.\(variableName).rawValue) as? \(identifierType) ?? initialValue
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
          UserDefaults.standard.set(newValue, forKey: SettingKeys.\(variableName).rawValue)
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
    
    return [ ]
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
    
    variables.forEach { variableDecl in
        if let variableValue = variableDecl.bindings.first?.initializer?.value,
          let variableName = variableDecl.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text {
          resetSyntaxString.appendLiteral("\(variableName) = \(variableValue)\n")
          
          syntaxString.appendLiteral("case \(variableName) \n")
        }
      
    }
  
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
  
    let newMembers: [MemberBlockItemSyntax] = [.init(decl: observationRegistrar),
                                               .init(decl: enumSyntax),
                                               .init(decl: resetFunction),
                                               .init(decl: accessFunction),
                                               .init(decl: withMutationFunction)]
    
    return newMembers.map { $0.decl }
  }
}

@main
struct SettingsPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
      SettingsImplMacro.self,
      SettingsDidSetMacro.self
    ]
}
