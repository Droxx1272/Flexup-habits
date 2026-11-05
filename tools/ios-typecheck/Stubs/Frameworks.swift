// Linux stand-ins for Apple's non-UI frameworks: just enough surface to
// type-check FlexUp's code with a stock Swift toolchain. Signatures mirror
// Apple's for everything the app uses. See tools/ios-typecheck/README.md.
import Foundation
@_exported import FoundationNetworking
@_exported import Observation

// MARK: - UIKit (non-view)

public final class UIImage: @unchecked Sendable {
    public var size: CGSize = .zero
    public init?(data: Data) {}
    public init?(contentsOfFile: String) {}
    public init(cgImage: CGImage) {}
    public init?(systemName: String) {}
    public func jpegData(compressionQuality: CGFloat) -> Data? { nil }
    public func draw(in rect: CGRect) {}
    public var cgImage: CGImage? { nil }
}
public final class UIGraphicsImageRendererFormat {
    public static func `default`() -> UIGraphicsImageRendererFormat { .init() }
    public var scale: CGFloat = 1
}
public final class UIGraphicsImageRenderer {
    public init(size: CGSize, format: UIGraphicsImageRendererFormat = .default()) {}
    public func image(actions: (Any) -> Void) -> UIImage { UIImage(cgImage: CGImage()) }
}
public final class UIColor {
    public init(_ provider: @escaping (UITraitCollection) -> UIColor) {}
    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {}
}
public final class UITraitCollection { public var userInterfaceStyle: UIUserInterfaceStyle { .light } }
public enum UIUserInterfaceStyle { case light, dark, unspecified }
public class UIResponder: NSObject {}
public final class UIApplication: UIResponder {
    public static let shared = UIApplication()
    public static let openSettingsURLString = "app-settings:"
    public func endEditingStub() {}
}
public final class UIPasteboard { public static let general = UIPasteboard(); public var string: String? }
public final class UINotificationFeedbackGenerator {
    public enum FeedbackType { case success, warning, error }
    public init() {}
    public func prepare() {}
    public func notificationOccurred(_ type: FeedbackType) {}
}
public final class UIImpactFeedbackGenerator {
    public enum FeedbackStyle { case light, medium, heavy, soft, rigid }
    public init(style: FeedbackStyle = .medium) {}
    public func prepare() {}
    public func impactOccurred() {}
}

// MARK: - CoreGraphics / ImageIO

public final class CGImage {}
public final class CGImageSource {}
public typealias CFURL = NSURL
public typealias CFData = NSData
public typealias CFString = NSString
public typealias CFTypeRef = AnyObject
public typealias CFDictionary = NSDictionary
public func CGImageSourceCreateWithURL(_ url: CFURL, _ o: CFDictionary?) -> CGImageSource? { nil }
public func CGImageSourceCreateWithData(_ d: CFData, _ o: CFDictionary?) -> CGImageSource? { nil }
public func CGImageSourceCreateThumbnailAtIndex(_ s: CGImageSource, _ i: Int, _ o: CFDictionary?) -> CGImage? { nil }
public let kCGImageSourceCreateThumbnailFromImageAlways: NSString = "a"
public let kCGImageSourceCreateThumbnailWithTransform: NSString = "b"
public let kCGImageSourceShouldCacheImmediately: NSString = "c"
public let kCGImageSourceThumbnailMaxPixelSize: NSString = "d"
public let kCGImageSourceShouldCache: NSString = "e"

// MARK: - UserNotifications

public struct UNAuthorizationOptions: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let alert = UNAuthorizationOptions(rawValue: 1)
    public static let sound = UNAuthorizationOptions(rawValue: 2)
    public static let badge = UNAuthorizationOptions(rawValue: 4)
}
public enum UNNotificationInterruptionLevel: Sendable { case passive, active, timeSensitive, critical }
public class UNNotificationContent: NSObject {}
public final class UNMutableNotificationContent: UNNotificationContent {
    public var title = ""
    public var subtitle = ""
    public var body = ""
    public var sound: UNNotificationSound?
    public var interruptionLevel: UNNotificationInterruptionLevel = .active
    public var threadIdentifier = ""
    public var categoryIdentifier = ""
    public var userInfo: [AnyHashable: Any] = [:]
    public var relevanceScore: Double = 0
}
public struct UNNotificationSoundName { public init(_ s: String) {} }
public final class UNNotificationSound: NSObject {
    public static let `default` = UNNotificationSound()
    public static let defaultCritical = UNNotificationSound()
    public override init() {}
    public convenience init(named: UNNotificationSoundName) { self.init() }
    public static var defaultRingtone: UNNotificationSound { .init() }
}
public class UNNotificationTrigger: NSObject {}
public final class UNCalendarNotificationTrigger: UNNotificationTrigger { public init(dateMatching: DateComponents, repeats: Bool) {} }
public final class UNTimeIntervalNotificationTrigger: UNNotificationTrigger { public init(timeInterval: TimeInterval, repeats: Bool) {} }
public final class UNNotificationRequest: NSObject {
    public let identifier: String
    public let content: UNNotificationContent
    public init(identifier: String, content: UNNotificationContent, trigger: UNNotificationTrigger?) {
        self.identifier = identifier
        self.content = content
    }
}
public enum UNAuthorizationStatus: Int, Sendable { case notDetermined, denied, authorized, provisional, ephemeral }
public final class UNNotificationSettings: NSObject { public var authorizationStatus: UNAuthorizationStatus = .notDetermined }
public final class UNNotification: NSObject { public var request: UNNotificationRequest { fatalError() } }
public final class UNNotificationResponse: NSObject { public var notification: UNNotification { fatalError() } }
public struct UNNotificationPresentationOptions: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let banner = Self(rawValue: 1)
    public static let sound = Self(rawValue: 2)
    public static let list = Self(rawValue: 4)
    public static let badge = Self(rawValue: 8)
}
public protocol UNUserNotificationCenterDelegate: AnyObject {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
}
public final class UNUserNotificationCenter: @unchecked Sendable {
    public static func current() -> UNUserNotificationCenter { .init() }
    public weak var delegate: UNUserNotificationCenterDelegate?
    public func requestAuthorization(options: UNAuthorizationOptions, completionHandler: @escaping (Bool, Error?) -> Void) {}
    public func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { true }
    public func add(_ request: UNNotificationRequest, withCompletionHandler: ((Error?) -> Void)? = nil) {}
    public func add(_ request: UNNotificationRequest) async throws {}
    public func removePendingNotificationRequests(withIdentifiers: [String]) {}
    public func removeDeliveredNotifications(withIdentifiers: [String]) {}
    public func removeAllPendingNotificationRequests() {}
    public func removeAllDeliveredNotifications() {}
    public func getPendingNotificationRequests(completionHandler: @escaping ([UNNotificationRequest]) -> Void) {}
    public func notificationSettings() async -> UNNotificationSettings { .init() }
}

// MARK: - CoreLocation

public typealias CLLocationDegrees = Double
public typealias CLLocationDistance = Double
public typealias CLLocationAccuracy = Double
public typealias CLLocationDirection = Double
public struct CLLocationCoordinate2D: Sendable, Hashable {
    public var latitude: Double
    public var longitude: Double
    public init() { latitude = 0; longitude = 0 }
    public init(latitude: Double, longitude: Double) { self.latitude = latitude; self.longitude = longitude }
}
public final class CLLocation: NSObject, @unchecked Sendable {
    public let coordinate: CLLocationCoordinate2D
    public var altitude: Double = 0
    public var horizontalAccuracy: Double = 5
    public var verticalAccuracy: Double = 5
    public var timestamp = Date()
    public var speed: Double = 0
    public var course: Double = 0
    public init(latitude: Double, longitude: Double) { coordinate = .init(latitude: latitude, longitude: longitude) }
    public func distance(from: CLLocation) -> CLLocationDistance { 0 }
}
public let kCLLocationAccuracyBest: Double = -1
public enum CLActivityType: Int { case other, automotiveNavigation, fitness, otherNavigation, airborne }
public enum CLAuthorizationStatus: Int32 { case notDetermined, restricted, denied, authorizedAlways, authorizedWhenInUse }
public protocol CLLocationManagerDelegate: NSObjectProtocol {}
public final class CLLocationManager: NSObject {
    public weak var delegate: CLLocationManagerDelegate?
    public var desiredAccuracy: Double = 0
    public var activityType: CLActivityType = .other
    public var distanceFilter: Double = 0
    public var allowsBackgroundLocationUpdates = false
    public var showsBackgroundLocationIndicator = false
    public var pausesLocationUpdatesAutomatically = true
    public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    public var location: CLLocation? { nil }
    public func requestWhenInUseAuthorization() {}
    public func startUpdatingLocation() {}
    public func stopUpdatingLocation() {}
}

// MARK: - CryptoKit

public struct SHA256Digest: Sequence { public func makeIterator() -> Array<UInt8>.Iterator { [UInt8]().makeIterator() } }
public enum SHA256 { public static func hash<D: DataProtocol>(data: D) -> SHA256Digest { .init() } }

// MARK: - DeviceCheck

public struct DCError: Error {
    public enum Code: Int { case unknownSystemFailure, featureUnsupported, invalidInput, invalidKey, serverUnavailable }
    public var code: Code
}
public final class DCAppAttestService: @unchecked Sendable {
    public static let shared = DCAppAttestService()
    public var isSupported: Bool { false }
    public func generateKey() async throws -> String { "" }
    public func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data { Data() }
    public func generateAssertion(_ keyId: String, clientDataHash: Data) async throws -> Data { Data() }
}

// MARK: - Security

public let kSecClass = "class" as NSString
public let kSecClassGenericPassword = "genp" as NSString
public let kSecAttrService = "svce" as NSString
public let kSecAttrAccount = "acct" as NSString
public let kSecReturnData = "r_Data" as NSString
public let kSecMatchLimit = "m_Limit" as NSString
public let kSecMatchLimitOne = "m_LimitOne" as NSString
public let kSecValueData = "v_Data" as NSString
public let kSecAttrAccessible = "pdmn" as NSString
public let kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly = "cku" as NSString
public let errSecSuccess: Int32 = 0
public func SecItemCopyMatching(_ q: CFDictionary, _ r: UnsafeMutablePointer<CFTypeRef?>?) -> Int32 { 0 }
public func SecItemAdd(_ q: CFDictionary, _ r: UnsafeMutablePointer<CFTypeRef?>?) -> Int32 { 0 }
public func SecItemDelete(_ q: CFDictionary) -> Int32 { 0 }

// MARK: - Vision

public class VNRequest { public var revision: Int = 1 }
public class VNObservation {}
public final class VNFeaturePrintObservation: VNObservation {
    public func computeDistance(_ outDistance: UnsafeMutablePointer<Float>, to featurePrint: VNFeaturePrintObservation) throws {}
}
public final class VNGenerateImageFeaturePrintRequest: VNRequest {
    public override init() {}
    public var results: [VNFeaturePrintObservation]? { nil }
}
public let VNGenerateImageFeaturePrintRequestRevision2: Int = 2
public struct VNImageOption: Hashable {}
public final class VNImageRequestHandler {
    public init(cgImage: CGImage, options: [VNImageOption: Any] = [:]) {}
    public func perform(_ requests: [VNRequest]) throws {}
}

// MARK: - LocalAuthentication

public enum LAPolicy { case deviceOwnerAuthentication, deviceOwnerAuthenticationWithBiometrics }
public enum LABiometryType { case none, touchID, faceID, opticID }
public final class LAContext {
    public init() {}
    public var biometryType: LABiometryType { .none }
    public func canEvaluatePolicy(_ p: LAPolicy, error: UnsafeMutablePointer<NSError?>?) -> Bool { true }
    public func evaluatePolicy(_ p: LAPolicy, localizedReason: String) async throws -> Bool { true }
}

// MARK: - Speech / AVFoundation

public final class SFSpeechRecognizer {
    public enum AuthorizationStatus { case notDetermined, denied, restricted, authorized }
    public init?(locale: Locale = .current) {}
    public init?() {}
    public var isAvailable: Bool { true }
    public static func requestAuthorization(_ handler: @escaping (AuthorizationStatus) -> Void) {}
    public static func authorizationStatus() -> AuthorizationStatus { .authorized }
    public func recognitionTask(with request: SFSpeechAudioBufferRecognitionRequest, resultHandler: @escaping (SFSpeechRecognitionResult?, Error?) -> Void) -> SFSpeechRecognitionTask { .init() }
}
public final class SFSpeechAudioBufferRecognitionRequest {
    public init() {}
    public var shouldReportPartialResults = true
    public var requiresOnDeviceRecognition = false
    public func append(_ buffer: AVAudioPCMBuffer) {}
    public func endAudio() {}
}
public final class SFSpeechRecognitionResult {
    public var bestTranscription: SFTranscription { .init() }
    public var isFinal: Bool { false }
}
public final class SFTranscription { public var formattedString: String { "" } }
public final class SFSpeechRecognitionTask { public func cancel() {}; public func finish() {} }
public final class AVAudioPCMBuffer {}
public final class AVAudioFormat {}
public final class AVAudioTime {}
public final class AVAudioInputNode {
    public func outputFormat(forBus: Int) -> AVAudioFormat { .init() }
    public func installTap(onBus: Int, bufferSize: UInt32, format: AVAudioFormat?, block: @escaping (AVAudioPCMBuffer, AVAudioTime) -> Void) {}
    public func removeTap(onBus: Int) {}
}
public final class AVAudioEngine {
    public init() {}
    public var inputNode: AVAudioInputNode { .init() }
    public func prepare() {}
    public func start() throws {}
    public func stop() {}
    public var isRunning: Bool { false }
}
public final class AVAudioSession {
    public struct Category: Hashable { public static let record = Category(), playback = Category(), playAndRecord = Category(), ambient = Category() }
    public struct Mode: Hashable { public static let measurement = Mode(), `default` = Mode(), voicePrompt = Mode(), spokenAudio = Mode() }
    public struct CategoryOptions: OptionSet {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let duckOthers = CategoryOptions(rawValue: 1)
        public static let mixWithOthers = CategoryOptions(rawValue: 2)
        public static let interruptSpokenAudioAndMixWithOthers = CategoryOptions(rawValue: 4)
    }
    public struct SetActiveOptions: OptionSet {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let notifyOthersOnDeactivation = SetActiveOptions(rawValue: 1)
    }
    public static func sharedInstance() -> AVAudioSession { .init() }
    public func setCategory(_ c: Category, mode: Mode = .default, options: CategoryOptions = []) throws {}
    public func setActive(_ active: Bool, options: SetActiveOptions = []) throws {}
}
public final class AVAudioApplication {
    public static func requestRecordPermission() async -> Bool { true }
}
public final class AVSpeechSynthesisVoice {
    public init?(language: String?) {}
    public static func currentLanguageCode() -> String { "en-US" }
}
public final class AVSpeechUtterance: NSObject {
    public init(string: String) {}
    public var voice: AVSpeechSynthesisVoice?
    public var rate: Float = 0.5
    public var pitchMultiplier: Float = 1
    public var volume: Float = 1
    public var preUtteranceDelay: TimeInterval = 0
    public var postUtteranceDelay: TimeInterval = 0
}
public let AVSpeechUtteranceDefaultSpeechRate: Float = 0.5
public protocol AVSpeechSynthesizerDelegate: AnyObject {}
public final class AVSpeechSynthesizer: NSObject {
    public override init() {}
    public weak var delegate: AVSpeechSynthesizerDelegate?
    public var isSpeaking: Bool { false }
    public func speak(_ utterance: AVSpeechUtterance) {}
    public func stopSpeaking(at boundary: AVSpeechBoundary) -> Bool { true }
}
public enum AVSpeechBoundary { case immediate, word }
