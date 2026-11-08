import CoreAudio

func route(_ name: String, _ transport: UInt32, jack: UInt32 = 0) -> OutputRoute {
 OutputRoute(uid: name, name: name, transport: transport, dataSource: 0, jack: jack, rate: 48000)
}
precondition(!route("Studio Display", kAudioDeviceTransportTypeUSB).allowsHeadphones)
precondition(!route("USB Speaker", kAudioDeviceTransportTypeUSB).allowsHeadphones)
precondition(!route("Mac", kAudioDeviceTransportTypeBuiltIn).allowsHeadphones)
precondition(route("Headphones", kAudioDeviceTransportTypeBuiltIn, jack: 1).allowsHeadphones)
precondition(route("USB Headphones", kAudioDeviceTransportTypeUSB).allowsHeadphones)
precondition(!route("AirPlay", kAudioDeviceTransportTypeAirPlay).allowsHeadphones)
precondition(!route("Bluetooth", kAudioDeviceTransportTypeBluetooth).allowsHeadphones)
precondition(!route("Virtual", kAudioDeviceTransportTypeVirtual).allowsHeadphones)
print("PASS: headphone route classification and speaker protection")
