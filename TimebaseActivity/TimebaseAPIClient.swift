import Foundation
import Security

struct TimebaseProject: Identifiable, Equatable {
    let id: String
    let name: String
    let clientID: String
    let clientName: String
}

struct CreatedTimeEntry: Decodable {
    let id: String
}

private struct TimeEntryResponse: Decodable {
    let entry: CreatedTimeEntry
}

private struct ProjectsResponse: Decodable {
    struct Client: Decodable {
        struct Project: Decodable {
            let id: String
            let name: String
        }
        let id: String
        let name: String
        let projects: [Project]
    }
    let clients: [Client]
}

enum TimebaseAPIError: LocalizedError {
    case missingToken
    case keychain(OSStatus)
    case invalidURL
    case invalidResponse
    case server(Int, String?)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "No se encontró el token de Timebase en el Llavero."
        case .keychain(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "código \(status)"
            return "El Llavero no permitió acceder al token: \(message)."
        case .invalidURL:
            return "La dirección de Timebase no es válida."
        case .invalidResponse:
            return "Timebase devolvió una respuesta no válida."
        case .server(let status, let message):
            return message ?? "Timebase respondió con el código HTTP \(status)."
        }
    }
}

struct TimebaseAPIClient {
    private let baseURL = "https://time.22mw.online"
    private let keychainService = "Timebase Activity API"
    private let legacyKeychainService = "Timebase macOS API"
    private let keychainAccount = "time.22mw.online"

    func projects() async throws -> [TimebaseProject] {
        guard let url = URL(string: "\(baseURL)/api/raycast/projects") else {
            throw TimebaseAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(try token())", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TimebaseAPIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
            throw TimebaseAPIError.server(httpResponse.statusCode, message)
        }

        let responseBody = try JSONDecoder().decode(ProjectsResponse.self, from: data)
        return responseBody.clients.flatMap { client in
            client.projects.map { project in
                TimebaseProject(
                    id: project.id,
                    name: project.name,
                    clientID: client.id,
                    clientName: client.name
                )
            }
        }
    }

    func createTimeEntry(
        projectID: String,
        session: PreparedSession,
        description: String
    ) async throws -> CreatedTimeEntry {
        guard let url = URL(string: "\(baseURL)/api/raycast/time-entries") else {
            throw TimebaseAPIError.invalidURL
        }
        struct Body: Encodable {
            let projectId: String
            let startTime: Date
            let endTime: Date
            let description: String
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(try token())", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(Body(
            projectId: projectID,
            startTime: session.startedAt,
            endTime: session.calculatedEnd,
            description: description
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TimebaseAPIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
            throw TimebaseAPIError.server(httpResponse.statusCode, message)
        }
        return try JSONDecoder().decode(TimeEntryResponse.self, from: data).entry
    }

    private func token() throws -> String {
        if let value = keychainToken(service: keychainService) {
            return value
        }
        if let value = keychainToken(service: legacyKeychainService) {
            return value
        }
        if let value = tokenUsingSecurityTool(service: legacyKeychainService) {
            return value
        }
        throw TimebaseAPIError.missingToken
    }

    private func keychainToken(service: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: keychainAccount,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecUseAuthenticationUI: kSecUseAuthenticationUIAllow,
            kSecUseOperationPrompt: "Permite que Timebase Activity use tu token de Timebase."
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
           let data = item as? Data,
           let value = String(data: data, encoding: .utf8),
           !value.isEmpty else { return nil }
        return value
    }

    private func tokenUsingSecurityTool(service: String) -> String? {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = [
            "find-generic-password", "-w",
            "-a", keychainAccount,
            "-s", service
        ]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            let value = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return value?.isEmpty == false ? value : nil
        } catch {
            return nil
        }
    }
}

@MainActor
final class ProjectLoader: ObservableObject {
    @Published private(set) var projects: [TimebaseProject] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            projects = try await TimebaseAPIClient().projects()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
