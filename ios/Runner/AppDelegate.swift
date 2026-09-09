import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Registra a chave do Maps ANTES do super, que é quem dispara o
    // GeneratedPluginRegistrant — o google_maps_flutter exige a chave
    // registrada antes de qualquer GMSMapView ser criado.
    let mapsApiKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String ?? ""
    if mapsApiKey.isEmpty {
      // Sem chave o mapa abre cinza. Deixamos o app subir para não derrubar as
      // demais telas, mas registramos o motivo no console.
      NSLog("[EcoJP] MAPS_API_KEY ausente: copie ios/Flutter/Maps.xcconfig.example "
            + "para ios/Flutter/Maps.xcconfig e preencha a chave.")
    } else {
      GMSServices.provideAPIKey(mapsApiKey)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
