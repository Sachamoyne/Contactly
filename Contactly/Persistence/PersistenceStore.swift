import Foundation

enum PersistenceStore {
    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func fileURL(for filename: String) -> URL {
        documentsDirectory.appendingPathComponent(filename)
    }

    static func save<T: Encodable>(_ data: T, to filename: String) throws {
        let url = fileURL(for: filename)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let encoded = try encoder.encode(data)
        try encoded.write(to: url, options: .atomic)
    }

    static func load<T: Decodable>(_ type: T.Type, from filename: String) throws -> T {
        let url = fileURL(for: filename)
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    static func exists(_ filename: String) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: filename).path())
    }
}
