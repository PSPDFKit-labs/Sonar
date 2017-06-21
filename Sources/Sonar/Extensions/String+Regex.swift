import Foundation

extension String {
    /// Returns the string matching in the given group number (if any), nil otherwise.
    ///
    /// - parameter pattern: The regular expression to match.
    /// - parameter group:   The group number to return from the match.
    /// - parameter options: Options that will be use for matching using regular expressions.
    ///
    /// - returns: The string from the given group on the match (if any).
    func match(pattern: String, group: Int, options: NSRegularExpression.Options = []) -> String? {
        do {
            let nsstring = self as NSString
            let regex = try NSRegularExpression(pattern: pattern, options: options)
            let range = NSRange(location: 0, length: nsstring.length)

            guard let match = regex.firstMatch(in: self, options: [], range: range) else {
                return nil
            }

            if match.numberOfRanges < group {
                return nil
            }

            let matchRange = match.rangeAt(group)

            return nsstring
                .substring(with: matchRange)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}
