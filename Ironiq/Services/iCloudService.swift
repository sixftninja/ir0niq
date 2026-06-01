import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

// MARK: - Protocol

protocol iCloudServiceProtocol: Sendable {
  /// Prepares the user-owned sync folders required before the app can be used.
  func prepareSyncFolders() async throws

  /// Exports a session as a gzipped JSON file. Returns the written file URL.
  func exportSession(_ model: SessionExportModel, templateSlug: String?) async throws -> URL

  /// Exports a template as a gzipped JSON file. Returns the written file URL.
  func exportTemplate(_ model: TemplateExportModel) async throws -> URL
}

// MARK: - Errors

enum iCloudError: Error, Equatable {
  case containerUnavailable
  case serializationFailed
  case compressionFailed
  case fileAlreadyExists
  case writeFailed(String)
}

// MARK: - Production implementation

actor iCloudService: iCloudServiceProtocol {
  private let containerIdentifier = "iCloud.com.ir0niq.app"
  private let fileManager: FileManager

  static let shared = iCloudService()
  private init(fileManager: FileManager = .default) { self.fileManager = fileManager }

  func prepareSyncFolders() async throws {
    guard fileManager.url(forUbiquityContainerIdentifier: containerIdentifier) != nil else {
      throw iCloudError.containerUnavailable
    }
    _ = try resolveDirectory(for: Date(), category: "Sessions")
    _ = try resolveDirectory(for: Date(), category: "Templates")
  }

  func exportSession(_ model: SessionExportModel, templateSlug: String? = nil) async throws -> URL {
    let directory = try resolveDirectory(for: model.startedAt, category: "Sessions")
    let filename = buildFilename(date: model.startedAt, slug: templateSlug)
    let fileURL = directory.appendingPathComponent(filename)

    guard !fileManager.fileExists(atPath: fileURL.path) else {
      throw iCloudError.fileAlreadyExists
    }

    let jsonData = try model.jsonData()
    let compressed = try jsonData.gzipped()

    do {
      try compressed.write(to: fileURL, options: .atomic)
    } catch {
      throw iCloudError.writeFailed(error.localizedDescription)
    }
    return fileURL
  }

  func exportTemplate(_ model: TemplateExportModel) async throws -> URL {
    let directory = try resolveDirectory(for: model.updatedAt, category: "Templates")
    let fileURL = directory.appendingPathComponent(
      "ironiq_template_\(model.id.uuidString.lowercased()).json.gz")

    let jsonData = try model.jsonData()
    let compressed = try jsonData.gzipped()

    do {
      try compressed.write(to: fileURL, options: .atomic)
    } catch {
      throw iCloudError.writeFailed(error.localizedDescription)
    }
    return fileURL
  }

  // MARK: - Helpers

  private func resolveDirectory(for date: Date, category: String) throws -> URL {
    let baseURL: URL

    if let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: containerIdentifier) {
      baseURL = iCloudURL.appendingPathComponent("Documents", isDirectory: true)
    } else {
      baseURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    let calendar = Calendar.current
    let year = calendar.component(.year, from: date)
    let month = calendar.component(.month, from: date)
    let categoryDirectory =
      baseURL
      .appendingPathComponent("Ironiq", isDirectory: true)
      .appendingPathComponent(category, isDirectory: true)

    let directory: URL
    if category == "Sessions" {
      directory =
        categoryDirectory
        .appendingPathComponent(String(year), isDirectory: true)
        .appendingPathComponent(String(format: "%02d", month), isDirectory: true)
    } else {
      directory = categoryDirectory
    }

    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  private func buildFilename(date: Date, slug: String?) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd_HHmmss"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    let timestamp = formatter.string(from: date)

    if let slug = slug?.lowercased()
      .replacingOccurrences(of: " ", with: "-")
      .filter({ $0.isLetter || $0.isNumber || $0 == "-" }),
      !slug.isEmpty
    {
      return "ironiq_\(timestamp)_\(slug).json.gz"
    }
    return "ironiq_\(timestamp).json.gz"
  }
}

// MARK: - Google Drive sync

struct GoogleDriveAccount: Equatable {
  let id: String
  let email: String?
}

enum GoogleDriveError: LocalizedError, Equatable {
  case missingConfiguration
  case authorizationCancelled
  case invalidCallback
  case tokenExchangeFailed
  case accountUnavailable
  case driveRequestFailed(String)

  var errorDescription: String? {
    switch self {
    case .missingConfiguration:
      return "Google Drive is not configured for this build."
    case .authorizationCancelled:
      return "Google sign-in was cancelled."
    case .invalidCallback:
      return "Google sign-in returned an invalid response."
    case .tokenExchangeFailed:
      return "Google sign-in could not finish. Try again."
    case .accountUnavailable:
      return "Google did not return a usable account. Try again."
    case .driveRequestFailed(let message):
      return "Google Drive setup failed: \(message)"
    }
  }
}

struct GoogleOAuthConfig: Equatable {
  let clientID: String
  let reversedClientID: String

  static func load(bundle: Bundle = .main) throws -> GoogleOAuthConfig {
    guard
      let clientID = bundle.object(forInfoDictionaryKey: "GoogleOAuthClientID") as? String,
      let reversedClientID = bundle.object(forInfoDictionaryKey: "GoogleOAuthReversedClientID")
        as? String,
      !clientID.isEmpty,
      !reversedClientID.isEmpty
    else {
      throw GoogleDriveError.missingConfiguration
    }

    return GoogleOAuthConfig(clientID: clientID, reversedClientID: reversedClientID)
  }
}

@MainActor
final class GoogleDriveService: NSObject {
  static let shared = GoogleDriveService()

  private let config: GoogleOAuthConfig
  private let tokenStore: GoogleTokenStore
  private var authSession: ASWebAuthenticationSession?

  private init(
    config: GoogleOAuthConfig = (try? GoogleOAuthConfig.load())
      ?? GoogleOAuthConfig(clientID: "", reversedClientID: ""),
    tokenStore: GoogleTokenStore = .shared
  ) {
    self.config = config
    self.tokenStore = tokenStore
    super.init()
  }

  func connectAndPrepareSyncFolders() async throws -> GoogleDriveAccount {
    guard !config.clientID.isEmpty, !config.reversedClientID.isEmpty else {
      throw GoogleDriveError.missingConfiguration
    }

    let verifier = GoogleOAuthPKCE.makeCodeVerifier()
    let challenge = GoogleOAuthPKCE.codeChallenge(for: verifier)
    let callbackURL = try await requestAuthorizationCode(challenge: challenge)
    let code = try authorizationCode(from: callbackURL)
    let token = try await exchangeCodeForToken(code: code, verifier: verifier)
    try tokenStore.save(token.accessToken, account: "access_token")
    if let refreshToken = token.refreshToken {
      try tokenStore.save(refreshToken, account: "refresh_token")
    }

    let account = try await fetchAccount(accessToken: token.accessToken)
    try await prepareDriveFolders(accessToken: token.accessToken)
    return account
  }

  private func requestAuthorizationCode(challenge: String) async throws -> URL {
    var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    components.queryItems = [
      URLQueryItem(name: "client_id", value: config.clientID),
      URLQueryItem(name: "redirect_uri", value: "\(config.reversedClientID):/oauth2redirect"),
      URLQueryItem(name: "response_type", value: "code"),
      URLQueryItem(
        name: "scope", value: "openid email profile https://www.googleapis.com/auth/drive.file"),
      URLQueryItem(name: "code_challenge", value: challenge),
      URLQueryItem(name: "code_challenge_method", value: "S256"),
      URLQueryItem(name: "access_type", value: "offline"),
      URLQueryItem(name: "prompt", value: "consent"),
    ]

    guard let url = components.url else { throw GoogleDriveError.missingConfiguration }

    return try await withCheckedThrowingContinuation { continuation in
      let session = ASWebAuthenticationSession(
        url: url,
        callbackURLScheme: config.reversedClientID
      ) { callbackURL, error in
        if let error = error as? ASWebAuthenticationSessionError,
          error.code == .canceledLogin
        {
          continuation.resume(throwing: GoogleDriveError.authorizationCancelled)
          return
        }
        if let error {
          continuation.resume(throwing: error)
          return
        }
        guard let callbackURL else {
          continuation.resume(throwing: GoogleDriveError.invalidCallback)
          return
        }
        continuation.resume(returning: callbackURL)
      }
      session.presentationContextProvider = self
      session.prefersEphemeralWebBrowserSession = false
      authSession = session
      session.start()
    }
  }

  private func authorizationCode(from callbackURL: URL) throws -> String {
    guard
      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
      let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
      !code.isEmpty
    else {
      throw GoogleDriveError.invalidCallback
    }
    return code
  }

  private func exchangeCodeForToken(code: String, verifier: String) async throws
    -> GoogleTokenResponse
  {
    var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.httpBody = formEncoded([
      "client_id": config.clientID,
      "code": code,
      "code_verifier": verifier,
      "grant_type": "authorization_code",
      "redirect_uri": "\(config.reversedClientID):/oauth2redirect",
    ])

    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
      throw GoogleDriveError.tokenExchangeFailed
    }
    return try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
  }

  private func fetchAccount(accessToken: String) async throws -> GoogleDriveAccount {
    var request = URLRequest(url: URL(string: "https://openidconnect.googleapis.com/v1/userinfo")!)
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
      throw GoogleDriveError.accountUnavailable
    }
    let account = try JSONDecoder().decode(GoogleUserInfoResponse.self, from: data)
    guard !account.sub.isEmpty else { throw GoogleDriveError.accountUnavailable }
    return GoogleDriveAccount(id: account.sub, email: account.email)
  }

  private func prepareDriveFolders(accessToken: String) async throws {
    let rootID = try await findOrCreateFolder(
      name: "Ironiq", parentID: "root", accessToken: accessToken)
    let sessionsID = try await findOrCreateFolder(
      name: "Sessions", parentID: rootID, accessToken: accessToken)
    let templatesID = try await findOrCreateFolder(
      name: "Templates", parentID: rootID, accessToken: accessToken)

    UserDefaults.standard.set(rootID, forKey: "googleDriveRootFolderId")
    UserDefaults.standard.set(sessionsID, forKey: "googleDriveSessionsFolderId")
    UserDefaults.standard.set(templatesID, forKey: "googleDriveTemplatesFolderId")
  }

  private func findOrCreateFolder(name: String, parentID: String, accessToken: String) async throws
    -> String
  {
    if let existing = try await findFolder(name: name, parentID: parentID, accessToken: accessToken)
    {
      return existing
    }
    return try await createFolder(name: name, parentID: parentID, accessToken: accessToken)
  }

  private func findFolder(name: String, parentID: String, accessToken: String) async throws
    -> String?
  {
    var components = URLComponents(string: "https://www.googleapis.com/drive/v3/files")!
    components.queryItems = [
      URLQueryItem(
        name: "q",
        value:
          "mimeType = 'application/vnd.google-apps.folder' and name = '\(name)' and '\(parentID)' in parents and trashed = false"
      ),
      URLQueryItem(name: "spaces", value: "drive"),
      URLQueryItem(name: "fields", value: "files(id,name)"),
    ]

    var request = URLRequest(url: components.url!)
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
      throw GoogleDriveError.driveRequestFailed("Could not check existing folders.")
    }
    let result = try JSONDecoder().decode(GoogleDriveFileListResponse.self, from: data)
    return result.files.first?.id
  }

  private func createFolder(name: String, parentID: String, accessToken: String) async throws
    -> String
  {
    var request = URLRequest(
      url: URL(string: "https://www.googleapis.com/drive/v3/files?fields=id,name")!)
    request.httpMethod = "POST"
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(
      GoogleDriveFolderCreateRequest(
        name: name,
        mimeType: "application/vnd.google-apps.folder",
        parents: [parentID]
      ))

    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
      throw GoogleDriveError.driveRequestFailed("Could not create \(name) folder.")
    }
    let file = try JSONDecoder().decode(GoogleDriveFileResponse.self, from: data)
    return file.id
  }

  private func formEncoded(_ parameters: [String: String]) -> Data {
    parameters
      .map { key, value in
        "\(urlEncode(key))=\(urlEncode(value))"
      }
      .joined(separator: "&")
      .data(using: .utf8) ?? Data()
  }

  private func urlEncode(_ value: String) -> String {
    value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
  }
}

extension GoogleDriveService: ASWebAuthenticationPresentationContextProviding {
  nonisolated func presentationAnchor(for session: ASWebAuthenticationSession)
    -> ASPresentationAnchor
  {
    MainActor.assumeIsolated { ASPresentationAnchor() }
  }
}

private struct GoogleTokenResponse: Decodable {
  let accessToken: String
  let refreshToken: String?

  enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
    case refreshToken = "refresh_token"
  }
}

private struct GoogleUserInfoResponse: Decodable {
  let sub: String
  let email: String?
}

private struct GoogleDriveFileListResponse: Decodable {
  let files: [GoogleDriveFileResponse]
}

private struct GoogleDriveFileResponse: Codable {
  let id: String
  let name: String?
}

private struct GoogleDriveFolderCreateRequest: Encodable {
  let name: String
  let mimeType: String
  let parents: [String]
}

enum GoogleOAuthPKCE {
  static func makeCodeVerifier() -> String {
    var bytes = [UInt8](repeating: 0, count: 32)
    _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    return base64URLEncoded(Data(bytes))
  }

  static func codeChallenge(for verifier: String) -> String {
    let digest = SHA256.hash(data: Data(verifier.utf8))
    return base64URLEncoded(Data(digest))
  }

  static func base64URLEncoded(_ data: Data) -> String {
    data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}

final class GoogleTokenStore: @unchecked Sendable {
  static let shared = GoogleTokenStore()
  private let service = "com.ir0niq.app.google.oauth"

  func save(_ value: String, account: String) throws {
    let data = Data(value.utf8)
    SecItemDelete(query(account: account) as CFDictionary)

    var attributes = query(account: account)
    attributes[kSecValueData as String] = data
    attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

    let status = SecItemAdd(attributes as CFDictionary, nil)
    guard status == errSecSuccess else {
      throw GoogleDriveError.driveRequestFailed("Could not store Google credentials.")
    }
  }

  func read(account: String) -> String? {
    var attributes = query(account: account)
    attributes[kSecReturnData as String] = true
    attributes[kSecMatchLimit as String] = kSecMatchLimitOne

    var result: AnyObject?
    let status = SecItemCopyMatching(attributes as CFDictionary, &result)
    guard status == errSecSuccess, let data = result as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  private func query(account: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
  }
}
