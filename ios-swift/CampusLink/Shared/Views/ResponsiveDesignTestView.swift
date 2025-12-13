import SwiftUI

// MARK: - Responsive Design Test View
// This view demonstrates and tests the responsive design system across different devices

struct ResponsiveDesignTestView: View {
    @State private var selectedDevice = "iPhone 15"
    @State private var selectedOrientation = "Portrait"
    
    let devices = ["iPhone SE", "iPhone 15", "iPhone 15 Plus", "iPhone 15 Pro Max", "iPad Air", "iPad Pro"]
    let orientations = ["Portrait", "Landscape"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                ResponsiveVStack(spacing: 24) {
                    // Device Selection
                    deviceSelectionSection
                    
                    // Typography Test
                    typographyTestSection
                    
                    // Spacing Test
                    spacingTestSection
                    
                    // Image Test
                    imageTestSection
                    
                    // Layout Test
                    layoutTestSection
                    
                    // Button Test
                    buttonTestSection
                    
                    // Grid Test
                    gridTestSection
                }
                .responsivePadding(16)
            }
            .navigationTitle("Responsive Design Test")
            .adaptiveNavigationBar()
        }
    }
    
    // MARK: - Test Sections
    
    private var deviceSelectionSection: some View {
        ResponsiveVStack(spacing: 16) {
            Text("Device & Orientation")
                .responsiveFont(.headline, weight: .semibold)
            
            HStack {
                Picker("Device", selection: $selectedDevice) {
                    ForEach(devices, id: \.self) { device in
                        Text(device).tag(device)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Picker("Orientation", selection: $selectedOrientation) {
                    ForEach(orientations, id: \.self) { orientation in
                        Text(orientation).tag(orientation)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
        }
        .responsivePadding(16)
        .background(Color(UIColor.systemGray6))
        .responsiveCornerRadius(12)
    }
    
    private var typographyTestSection: some View {
        ResponsiveVStack(spacing: 16) {
            Text("Typography Scale")
                .responsiveFont(.headline, weight: .semibold)
            
            ResponsiveVStack(spacing: 8, alignment: .leading) {
                Text("Large Title")
                    .responsiveFont(.largeTitle, weight: .bold)
                
                Text("Title")
                    .responsiveFont(.title, weight: .semibold)
                
                Text("Headline")
                    .responsiveFont(.headline, weight: .medium)
                
                Text("Body Text")
                    .responsiveFont(.body)
                
                Text("Caption")
                    .responsiveFont(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .responsivePadding(16)
        .background(Color(UIColor.systemGray6))
        .responsiveCornerRadius(12)
    }
    
    private var spacingTestSection: some View {
        ResponsiveVStack(spacing: 16) {
            Text("Spacing Scale")
                .responsiveFont(.headline, weight: .semibold)
            
            ResponsiveVStack(spacing: 8) {
                HStack {
                    Rectangle()
                        .fill(Color.blue)
                        .responsiveFrame(width: 20, height: 20)
                    Text("Small Spacing (8pt)")
                        .responsiveFont(.body)
                }
                
                HStack {
                    Rectangle()
                        .fill(Color.green)
                        .responsiveFrame(width: 30, height: 30)
                    Text("Medium Spacing (16pt)")
                        .responsiveFont(.body)
                }
                
                HStack {
                    Rectangle()
                        .fill(Color.orange)
                        .responsiveFrame(width: 40, height: 40)
                    Text("Large Spacing (24pt)")
                        .responsiveFont(.body)
                }
            }
        }
        .responsivePadding(16)
        .background(Color(UIColor.systemGray6))
        .responsiveCornerRadius(12)
    }
    
    private var imageTestSection: some View {
        ResponsiveVStack(spacing: 16) {
            Text("Image Scaling")
                .responsiveFont(.headline, weight: .semibold)
            
            ResponsiveHStack(spacing: 16) {
                ResponsiveAsyncImage(
                    url: URL(string: "https://picsum.photos/200"),
                    width: ResponsiveImageConstants.smallImageSize,
                    height: ResponsiveImageConstants.smallImageSize,
                    aspectRatio: 1,
                    contentMode: .fill,
                    cornerRadius: ResponsiveImageConstants.smallCornerRadius
                )
                
                ResponsiveAsyncImage(
                    url: URL(string: "https://picsum.photos/200"),
                    width: ResponsiveImageConstants.mediumImageSize,
                    height: ResponsiveImageConstants.mediumImageSize,
                    aspectRatio: 1,
                    contentMode: .fill,
                    cornerRadius: ResponsiveImageConstants.mediumCornerRadius
                )
                
                ResponsiveAsyncImage(
                    url: URL(string: "https://picsum.photos/200"),
                    width: ResponsiveImageConstants.largeImageSize,
                    height: ResponsiveImageConstants.largeImageSize,
                    aspectRatio: 1,
                    contentMode: .fill,
                    cornerRadius: ResponsiveImageConstants.largeCornerRadius
                )
            }
        }
        .responsivePadding(16)
        .background(Color(UIColor.systemGray6))
        .responsiveCornerRadius(12)
    }
    
    private var layoutTestSection: some View {
        ResponsiveVStack(spacing: 16) {
            Text("Layout Adaptation")
                .responsiveFont(.headline, weight: .semibold)
            
            // Device-specific layout
            deviceTypeAdaptive {
                // Phone layout
                ResponsiveVStack(spacing: 8) {
                    Text("Phone Layout")
                        .responsiveFont(.subheadline, weight: .medium)
                    Text("Single column, compact spacing")
                        .responsiveFont(.caption)
                        .foregroundColor(.secondary)
                }
            } tablet: {
                // Tablet layout
                ResponsiveVStack(spacing: 16) {
                    Text("Tablet Layout")
                        .responsiveFont(.subheadline, weight: .medium)
                    Text("Multi-column, expanded spacing")
                        .responsiveFont(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Screen size adaptation
            screenSizeAdaptiveImage {
                // Compact
                Text("Compact Screen")
                    .responsiveFont(.caption)
                    .responsivePadding(8)
                    .background(Color.blue.opacity(0.2))
                    .responsiveCornerRadius(6)
            } regular: {
                // Regular
                Text("Regular Screen")
                    .responsiveFont(.caption)
                    .responsivePadding(12)
                    .background(Color.green.opacity(0.2))
                    .responsiveCornerRadius(8)
            } large: {
                // Large
                Text("Large Screen")
                    .responsiveFont(.caption)
                    .responsivePadding(16)
                    .background(Color.orange.opacity(0.2))
                    .responsiveCornerRadius(10)
            }
        }
        .responsivePadding(16)
        .background(Color(UIColor.systemGray6))
        .responsiveCornerRadius(12)
    }
    
    private var buttonTestSection: some View {
        ResponsiveVStack(spacing: 16) {
            Text("Button Scaling")
                .responsiveFont(.headline, weight: .semibold)
            
            ResponsiveVStack(spacing: 12) {
                ActionButton(type: .contactSeller) {
                    print("Contact seller tapped")
                }
                
                ActionButton(type: .buyNow) {
                    print("Buy now tapped")
                }
                
                ActionButton(type: .editListing) {
                    print("Edit listing tapped")
                }
            }
        }
        .responsivePadding(16)
        .background(Color(UIColor.systemGray6))
        .responsiveCornerRadius(12)
    }
    
    private var gridTestSection: some View {
        ResponsiveVStack(spacing: 16) {
            Text("Grid Adaptation")
                .responsiveFont(.headline, weight: .semibold)
            
            // Adaptive grid that changes columns based on screen size
            adaptiveGrid(
                compactColumns: 1,
                regularColumns: 2,
                largeColumns: 3,
                spacing: 12
            ) {
                ForEach(0..<6, id: \.self) { index in
                    Rectangle()
                        .fill(Color.blue.opacity(0.3))
                        .responsiveFrame(height: 60)
                        .responsiveCornerRadius(8)
                        .overlay(
                            Text("Item \(index + 1)")
                                .responsiveFont(.caption, weight: .medium)
                        )
                }
            }
        }
        .responsivePadding(16)
        .background(Color(UIColor.systemGray6))
        .responsiveCornerRadius(12)
    }
}

// MARK: - Preview

struct ResponsiveDesignTestView_Previews: PreviewProvider {
    static var previews: some View {
        ResponsiveDesignTestView()
            .environmentObject(AuthManager())
    }
}


