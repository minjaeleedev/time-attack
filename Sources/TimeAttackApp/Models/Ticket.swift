import Foundation

struct Ticket: Identifiable, Codable, Equatable {
    let id: String
    let identifier: String
    let title: String
    let url: String
    let state: String
    let linearEstimate: Int?
    var localEstimate: TimeInterval?
    let priority: Int
    let updatedAt: Date
    
    var displayEstimate: String {
        if let local = localEstimate {
            let hours = Int(local) / 3600
            let minutes = (Int(local) % 3600) / 60
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(minutes)m"
        }
        if let linear = linearEstimate {
            return "\(linear) pts"
        }
        return "No estimate"
    }
}
