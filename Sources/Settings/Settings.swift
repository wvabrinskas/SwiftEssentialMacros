
@attached(member, names: arbitrary)
@attached(memberAttribute)
public macro Settings() = #externalMacro(module: "SettingsMacros", type: "SettingsImplMacro")
