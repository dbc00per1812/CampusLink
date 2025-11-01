import Foundation

extension String {
    /// Formats a full name as "FirstName L." (first name and last name initial)
    /// Examples:
    /// - "John Doe" -> "John D."
    /// - "Mary Jane Smith" -> "Mary S."
    /// - "Alice" -> "Alice"
    /// - "" -> "Unknown"
    var formattedName: String {
        let trimmed = self.trimmingCharacters(in: .whitespaces)
        
        guard !trimmed.isEmpty else {
            return "Unknown"
        }
        
        let components = trimmed.split(separator: " ").map(String.init)
        
        guard !components.isEmpty else {
            return "Unknown"
        }
        
        // If only one name component, return it as-is
        if components.count == 1 {
            return components[0]
        }
        
        // Get first name and last name initial
        let firstName = components[0]
        let lastNameInitial = components.last?.first.map { String($0).uppercased() } ?? ""
        
        return "\(firstName) \(lastNameInitial)."
    }
}

