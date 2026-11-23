import Foundation

public enum TmutilParsing {
    /// Parses `tmutil status -X` (plist).
    public static func parseStatusPlist(_ data: Data) throws -> TMStatus {
        guard let dict = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw TimeMachineError.unparsable("status plist")
        }
        let running = truthy(dict["Running"])
        let percent = (dict["Percent"] as? NSNumber)?.doubleValue
        return TMStatus(
            isRunning: running,
            phase: dict["BackupPhase"] as? String,
            percent: (percent ?? -1) >= 0 ? percent : nil
        )
    }

    /// Fallback for the old text/NeXT-style output of `tmutil status`.
    public static func parseStatusText(_ text: String) -> TMStatus {
        func value(_ key: String) -> String? {
            for line in text.split(separator: "\n") {
                let parts = line.split(separator: "=", maxSplits: 1).map {
                    $0.trimmingCharacters(in: CharacterSet(charactersIn: " \t;\""))
                }
                if parts.count == 2, parts[0] == key { return parts[1] }
            }
            return nil
        }
        return TMStatus(isRunning: value("Running") == "1", phase: value("BackupPhase"), percent: value("Percent").flatMap(Double.init).flatMap { $0 >= 0 ? $0 : nil })
    }

    /// Parses the output of `tmutil latestbackup`: a path ending in `YYYY-MM-DD-HHMMSS` (optionally `.backup`/`.previous`).
    public static func parseLatestBackup(_ output: String, calendar: Calendar = .current) -> Date? {
        guard let range = output.range(of: #"\d{4}-\d{2}-\d{2}-\d{6}"#, options: .regularExpression) else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "yyyy-MM-dd-HHmmss"
        return f.date(from: String(output[range]))
    }

    /// Parses `tmutil destinationinfo -X`.
    public static func parseDestinations(_ data: Data) throws -> [TMDestination] {
        guard let dict = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let list = dict["Destinations"] as? [[String: Any]] else {
            throw TimeMachineError.unparsable("destinationinfo plist")
        }
        return list.compactMap { d in
            guard let id = d["ID"] as? String else { return nil }
            return TMDestination(id: id, name: (d["Name"] as? String) ?? id, kind: d["Kind"] as? String)
        }
    }

    private static func truthy(_ value: Any?) -> Bool {
        if let n = value as? NSNumber { return n.intValue != 0 }
        if let s = value as? String { return s == "1" || s.lowercased() == "true" }
        return false
    }
}
