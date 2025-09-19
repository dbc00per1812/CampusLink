import SwiftUI

// MARK: - Responsive Design System
// This extension provides a comprehensive responsive design system for all iOS devices

extension View {
    
    // MARK: - Dynamic Spacing
    /// Provides responsive spacing that scales with device size and accessibility settings
    func responsiveSpacing(_ base: CGFloat) -> some View {
        self.padding(.vertical, base)
    }
    
    /// Horizontal responsive spacing
    func responsiveHorizontalSpacing(_ base: CGFloat) -> some View {
        self.padding(.horizontal, base)
    }
    
    /// All-around responsive spacing
    func responsivePadding(_ base: CGFloat) -> some View {
        self.padding(base)
    }
    
    // MARK: - Dynamic Font Sizes
    /// Responsive font that scales with device and accessibility settings
    func responsiveFont(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> some View {
        self.font(.system(style, design: .default, weight: weight))
    }
    
    /// Custom responsive font size
    func responsiveFontSize(_ base: CGFloat, weight: Font.Weight = .regular) -> some View {
        let scaledSize = base * UIScreen.main.bounds.width / 375 // iPhone 12 base width
        return self.font(.system(size: scaledSize, weight: weight))
    }
    
    // MARK: - Dynamic Frame Sizing
    /// Responsive frame that adapts to screen size
    func responsiveFrame(width: CGFloat? = nil, height: CGFloat? = nil) -> some View {
        let scale = UIScreen.main.bounds.width / 375 // iPhone 12 base width
        let responsiveWidth = width != nil ? width! * scale : nil
        let responsiveHeight = height != nil ? height! * scale : nil
        return self.frame(width: responsiveWidth, height: responsiveHeight)
    }
    
    /// Responsive max width
    func responsiveMaxWidth(_ base: CGFloat) -> some View {
        let scale = UIScreen.main.bounds.width / 375
        return self.frame(maxWidth: base * scale)
    }
    
    // MARK: - Device-Specific Adaptations
    /// Applies different styles based on device size
    func deviceAdaptive<Content: View>(
        @ViewBuilder phone: () -> Content,
        @ViewBuilder tablet: () -> Content
    ) -> some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                tablet()
            } else {
                phone()
            }
        }
    }
    
    /// Applies different styles based on screen size
    func screenSizeAdaptive<Content: View>(
        @ViewBuilder small: () -> Content,
        @ViewBuilder medium: () -> Content,
        @ViewBuilder large: () -> Content
    ) -> some View {
        Group {
            let width = UIScreen.main.bounds.width
            if width < 400 {
                small()
            } else if width < 600 {
                medium()
            } else {
                large()
            }
        }
    }
    
    // MARK: - Orientation Handling
    // Note: orientationAdaptive is defined in View+DeviceAdaptive.swift
    
    // MARK: - Accessibility Support
    /// Ensures content is accessible with dynamic type
    func accessibleContent() -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isStaticText)
    }
    
    /// Makes buttons accessible
    func accessibleButton(_ label: String) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Safe Area Handling
    /// Responsive safe area padding
    func responsiveSafeAreaPadding(_ edges: Edge.Set = .all) -> some View {
        self.padding(edges, 16 * UIScreen.main.scale)
    }
    
    // MARK: - Corner Radius Scaling
    /// Responsive corner radius
    func responsiveCornerRadius(_ base: CGFloat) -> some View {
        let scale = UIScreen.main.bounds.width / 375
        return self.cornerRadius(base * scale)
    }
}

// MARK: - Responsive Layout Helpers

struct ResponsiveGrid<Content: View>: View {
    let columns: Int
    let spacing: CGFloat
    let content: () -> Content
    
    init(columns: Int, spacing: CGFloat = 16, @ViewBuilder content: @escaping () -> Content) {
        self.columns = columns
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        let adaptiveColumns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns)
        
        LazyVGrid(columns: adaptiveColumns, spacing: spacing) {
            content()
        }
    }
}

struct ResponsiveHStack<Content: View>: View {
    let spacing: CGFloat
    let alignment: VerticalAlignment
    let content: () -> Content
    
    init(spacing: CGFloat = 16, alignment: VerticalAlignment = .center, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.alignment = alignment
        self.content = content
    }
    
    var body: some View {
        HStack(alignment: alignment, spacing: spacing) {
            content()
        }
    }
}

struct ResponsiveVStack<Content: View>: View {
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: () -> Content
    
    init(spacing: CGFloat = 16, alignment: HorizontalAlignment = .center, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.alignment = alignment
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: alignment, spacing: spacing) {
            content()
        }
    }
}

// MARK: - Device Detection

extension UIDevice {
    var isSmallScreen: Bool {
        UIScreen.main.bounds.width < 400
    }
    
    var isMediumScreen: Bool {
        let width = UIScreen.main.bounds.width
        return width >= 400 && width < 600
    }
    
    var isLargeScreen: Bool {
        UIScreen.main.bounds.width >= 600
    }
    
    var isTablet: Bool {
        userInterfaceIdiom == .pad
    }
}

// MARK: - Responsive Constants

struct ResponsiveConstants {
    static let baseSpacing: CGFloat = 16
    static let smallSpacing: CGFloat = 8
    static let largeSpacing: CGFloat = 24
    
    static let baseCornerRadius: CGFloat = 12
    static let smallCornerRadius: CGFloat = 8
    static let largeCornerRadius: CGFloat = 16
    
    static let baseFontSize: CGFloat = 16
    static let smallFontSize: CGFloat = 12
    static let largeFontSize: CGFloat = 20
    
    static let cardPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 20
}


