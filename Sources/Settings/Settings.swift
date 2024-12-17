import Observation

@attached(member, names: arbitrary)
@attached(memberAttribute)
public macro Settings() = #externalMacro(module: "SettingsMacros", type: "SettingsImplMacro")


@attached(member, names: arbitrary)
@attached(memberAttribute)
@attached(extension, conformances: Observable)
public macro SettingsObserve() = #externalMacro(module: "SettingsMacros", type: "SettingsObserveImplMacro")

@attached(accessor, names: named(init), named(get), named(set), named(_modify)) @attached(peer, names: prefixed(`_`))
public macro SettingsObserveDidSet() = #externalMacro(module: "SettingsMacros", type: "SettingsObserveDidSetMacro")
