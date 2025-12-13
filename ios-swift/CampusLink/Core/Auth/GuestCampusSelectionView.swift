import SwiftUI

/// View for guest users to select their campus before browsing
struct GuestCampusSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("guestSelectedCampus") private var guestSelectedCampus: String = ""
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    
    let onCampusSelected: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color("ThemeColor"))
                        .padding(.top, 40)
                    
                    Text("Select Your Campus")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Choose your campus to see relevant listings")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.bottom, 32)
                
                // Campus List
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(Campus.allCases, id: \.self) { campus in
                            CampusSelectionCard(
                                campus: campus,
                                isSelected: guestSelectedCampus == campus.rawValue,
                                action: {
                                    selectCampus(campus)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func selectCampus(_ campus: Campus) {
        guestSelectedCampus = campus.rawValue
        hasSeenWelcome = true
        onCampusSelected()
        dismiss()
    }
}

/// Individual campus selection card
struct CampusSelectionCard: View {
    let campus: Campus
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Campus icon
                Circle()
                    .fill(Color("ThemeColor").opacity(0.1))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(campus.abbreviation)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color("ThemeColor"))
                    )
                
                // Campus info
                VStack(alignment: .leading, spacing: 4) {
                    Text(campus.displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(campus.abbreviation)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Checkmark if selected
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color("ThemeColor"))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color("ThemeColor").opacity(0.05) : Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color("ThemeColor") : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct GuestCampusSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        GuestCampusSelectionView(onCampusSelected: {})
    }
}

