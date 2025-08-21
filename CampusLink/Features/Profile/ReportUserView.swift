import SwiftUI
import Supabase

struct ReportUserView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    
    let reportedUserId: String?
    let reportedUserName: String?
    let reportedListingId: String?
    let reportedListingTitle: String?
    
    @State private var selectedReportType: ReportType = .inappropriateContent
    @State private var additionalDetails = ""
    @State private var isSubmitting = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var reportSubmitted = false
    
    init(userId: String? = nil, userName: String? = nil, listingId: String? = nil, listingTitle: String? = nil) {
        self.reportedUserId = userId
        self.reportedUserName = userName
        self.reportedListingId = listingId
        self.reportedListingTitle = listingTitle
    }
    
    var body: some View {
        NavigationView {
            Form {
                // What are you reporting?
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        if let listingTitle = reportedListingTitle {
                            Label {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Listing")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(listingTitle)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                            } icon: {
                                Image(systemName: "tag.fill")
                                    .foregroundColor(Color("ThemeColor"))
                            }
                        }
                        
                        if let userName = reportedUserName {
                            Label {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("User")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(userName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                            } icon: {
                                Image(systemName: "person.fill")
                                    .foregroundColor(Color("ThemeColor"))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Reporting")
                }
                
                // Report Type Selection
                Section {
                    Picker("Report Type", selection: $selectedReportType) {
                        ForEach(ReportType.allCases, id: \.self) { type in
                            VStack(alignment: .leading) {
                                Text(type.displayName)
                                    .tag(type)
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    
                    // Show description of selected type
                    Text(selectedReportType.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                } header: {
                    Text("Reason for Report")
                } footer: {
                    Text("Please select the option that best describes the issue")
                        .font(.caption)
                }
                
                // Additional Details
                Section {
                    TextEditor(text: $additionalDetails)
                        .frame(minHeight: 100)
                        .overlay(
                            Group {
                                if additionalDetails.isEmpty {
                                    Text("Please provide specific details about the issue...")
                                        .foregroundColor(.secondary.opacity(0.5))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 8)
                                        .allowsHitTesting(false)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                }
                            }
                        )
                } header: {
                    Text("Additional Information")
                } footer: {
                    Text("The more details you provide, the better we can investigate this report")
                        .font(.caption)
                }
                
                // Community Guidelines
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label {
                            Text("False reports may result in account suspension")
                                .font(.caption)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                        
                        Label {
                            Text("All reports are reviewed within 24-48 hours")
                                .font(.caption)
                        } icon: {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                        
                        Label {
                            Text("Your identity will remain anonymous")
                                .font(.caption)
                        } icon: {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Important Information")
                }
            }
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        submitReport()
                    }
                    .fontWeight(.semibold)
                    .disabled(additionalDetails.count < 10 || isSubmitting)
                }
            }
            .disabled(isSubmitting)
            .overlay {
                if isSubmitting {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView("Submitting report...")
                                .padding()
                                .background(Color(UIColor.systemBackground))
                                .cornerRadius(10)
                                .shadow(radius: 5)
                        }
                }
            }
            .alert(reportSubmitted ? "Report Submitted" : "Error", isPresented: $showingAlert) {
                Button("OK") {
                    if reportSubmitted {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func submitReport() {
        guard additionalDetails.count >= 10 else {
            alertMessage = "Please provide more details about the issue (at least 10 characters)"
            showingAlert = true
            return
        }
        
        guard authManager.session?.user.id.uuidString != nil else {
            alertMessage = "You must be logged in to submit a report"
            showingAlert = true
            return
        }
        
        Task {
            await submitReportAsync()
        }
    }
    
    @MainActor
    private func submitReportAsync() async {
        isSubmitting = true
        
        do {
            // Create the report in Supabase
            let report = ReportCreate(
                reportedUserId: reportedUserId,
                reportedListingId: reportedListingId,
                reportType: selectedReportType.rawValue,
                description: additionalDetails
            )
            
            _ = try await supabase
                .from("reports")
                .insert(report)
                .execute()
            
            // Success
            reportSubmitted = true
            alertMessage = "Thank you for your report. We will review it within 24-48 hours and take appropriate action."
            showingAlert = true
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
        } catch {
            // Error
            reportSubmitted = false
            alertMessage = "Failed to submit report: \(error.localizedDescription)"
            showingAlert = true
        }
        
        isSubmitting = false
    }
}

struct ReportUserView_Previews: PreviewProvider {
    static var previews: some View {
        ReportUserView(
            userId: "123",
            userName: "John Doe",
            listingId: "456",
            listingTitle: "MacBook Pro 2021"
        )
        .environmentObject(AuthManager())
    }
}
