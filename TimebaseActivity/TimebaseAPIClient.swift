import Foundation
import Security

struct TimebaseProject: Identifiable, Equatable {
    let id: String
    let name: String
    let clientID: String
    let clientName: String
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
    case invalidURL
    case invalidResponse
    case server(Int, String?)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "No se encontró el token de Timebase en el Llavero."
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
    private let keychainService = "Timebase macOS API"
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

    private func token() throws -> String {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else {
            throw TimebaseAPIError.missingToken
        }
        return value
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

