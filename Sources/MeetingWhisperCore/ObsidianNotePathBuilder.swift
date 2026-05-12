import Foundation

public struct ObsidianNotePathBuilder: Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = Calendar(identifier: .gregorian)) {
        var calendar = calendar
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        self.calendar = calendar
    }

    public func noteURL(
        title: String,
        createdAt: Date,
        config: AppConfig
    ) -> URL {
        let prefix = datePrefix(for: createdAt)
        let slug = slugify(title)
        return URL(filePath: config.vaultPath, directoryHint: .isDirectory)
            .appending(path: config.notesFolder, directoryHint: .isDirectory)
            .appending(path: "\(prefix) - \(slug).md")
    }

    public func slugify(_ title: String) -> String {
        let lowercased = title.lowercased()
        var output = ""
        var previousWasDash = false

        for scalar in lowercased.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                output.unicodeScalars.append(scalar)
                previousWasDash = false
            } else if !previousWasDash {
                output.append("-")
                previousWasDash = true
            }
        }

        let trimmed = output.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? "meeting" : trimmed
    }

    private func datePrefix(for date: Date) -> String {
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        return String(
            format: "%04d-%02d-%02d %02d%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0,
            components.hour ?? 0,
            components.minute ?? 0
        )
    }
}
