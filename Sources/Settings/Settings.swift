
@attached(member, names: arbitrary)
@attached(memberAttribute)
public macro Settings() = #externalMacro(module: "SettingsMacros", type: "SettingsImplMacro")

@attached(accessor, names: named(init), named(get), named(set), named(_modify))
public macro SettingsDidSet() = #externalMacro(module: "SettingsMacros", type: "SettingsDidSetMacro")
