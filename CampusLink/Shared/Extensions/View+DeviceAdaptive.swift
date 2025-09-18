import SwiftUI

// MARK: - Device Adaptive Layout System
// This extension provides device-specific layout adaptations for optimal user experience

extension View {
    
    // MARK: - Screen Size Adaptations
    
    /// Adapts content based on screen width categories
    func screenWidthAdaptive<Content: View>(
        @ViewBuilder compact: () -> Content,
        @ViewBuilder regular: () -> Content,
        @ViewBuilder large: () -> Content
    ) -> some View {
        Group {
            let width = UIScreen.main.bounds.width
            if width < 400 {
                compact()
            } else if width < 600 {
                regular()
            } else {
                large()
            }
        }
    }
    
    /// Adapts content based on device type (iPhone vs iPad)
    func deviceTypeAdaptive<Content: View>(
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
    
    // MARK: - Orientation Adaptations
    
    /// Adapts layout for portrait vs landscape orientations
    func orientationAdaptive<Content: View>(
        @ViewBuilder portrait: () -> Content,
        @ViewBuilder landscape: () -> Content
    ) -> some View {
        Group {
            if UIDevice.current.orientation.isLandscape {
                landscape()
            } else {
                portrait()
            }
        }
    }
    
    /// Provides different layouts for different orientations with screen size consideration
    func adaptiveLayout<Content: View>(
        @ViewBuilder compactPortrait: () -> Content,
        @ViewBuilder compactLandscape: () -> Content,
        @ViewBuilder regularPortrait: () -> Content,
        @ViewBuilder regularLandscape: () -> Content,
        @ViewBuilder largePortrait: () -> Content,
        @ViewBuilder largeLandscape: () -> Content
    ) -> some View {
        Group {
            let width = UIScreen.main.bounds.width
            let isLandscape = UIDevice.current.orientation.isLandscape
            
            if width < 400 {
                isLandscape ? compactLandscape() : compactPortrait()
            } else if width < 600 {
                isLandscape ? regularLandscape() : regularPortrait()
            } else {
                isLandscape ? largeLandscape() : largePortrait()
            }
        }
    }
    
    // MARK: - Dynamic Grid Systems
    
    /// Creates a responsive grid that adapts to screen size
    func responsiveGrid<Content: View>(
        columns: Int = 2,
        spacing: CGFloat = 16,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        let adaptiveColumns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns)
        
        return LazyVGrid(columns: adaptiveColumns, spacing: spacing) {
            content()
        }
    }
    
    /// Creates a grid that adapts column count based on screen size
    func adaptiveGrid<Content: View>(
        compactColumns: Int = 1,
        regularColumns: Int = 2,
        largeColumns: Int = 3,
        spacing: CGFloat = 16,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        let width = UIScreen.main.bounds.width
        let columns = width < 400 ? compactColumns : width < 600 ? regularColumns : largeColumns
        let adaptiveColumns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns)
        
        return LazyVGrid(columns: adaptiveColumns, spacing: spacing) {
            content()
        }
    }
    
    // MARK: - Safe Area Adaptations
    
    /// Provides safe area padding that adapts to device type
    func adaptiveSafeAreaPadding(_ edges: Edge.Set = .all) -> some View {
        let padding: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 24 : 16
        return self.padding(edges, padding)
    }
    
    /// Provides bottom safe area padding for tab bars and home indicators
    func adaptiveBottomPadding() -> some View {
        let padding: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 20 : 16
        return self.padding(.bottom, padding)
    }
    
    // MARK: - Navigation Adaptations
    
    /// Adapts navigation bar style based on device type
    func adaptiveNavigationBar() -> some View {
        self
            .navigationBarTitleDisplayMode(UIDevice.current.userInterfaceIdiom == .pad ? .large : .inline)
    }
    
    // MARK: - Sheet and Modal Adaptations
    
    /// Adapts sheet presentation based on device type
    func adaptiveSheet<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                self.sheet(isPresented: isPresented) {
                    NavigationView {
                        content()
                    }
                }
            } else {
                self.sheet(isPresented: isPresented, content: content)
            }
        }
    }
    
    // MARK: - Typography Adaptations
    
    /// Provides responsive typography that scales with device
    func adaptiveTypography(
        compact: Font.TextStyle = .body,
        regular: Font.TextStyle = .title3,
        large: Font.TextStyle = .title2
    ) -> some View {
        let width = UIScreen.main.bounds.width
        let style = width < 400 ? compact : width < 600 ? regular : large
        return self.font(.system(style, design: .default))
    }
    
    // MARK: - Spacing Adaptations
    
    /// Provides responsive spacing that scales with device
    func adaptiveSpacing(
        compact: CGFloat = 8,
        regular: CGFloat = 16,
        large: CGFloat = 24
    ) -> some View {
        let width = UIScreen.main.bounds.width
        let spacing = width < 400 ? compact : width < 600 ? regular : large
        return self.padding(.vertical, spacing)
    }
    
    // MARK: - Image Adaptations
    
    /// Provides responsive image sizing
    func adaptiveImageSize(
        compact: CGFloat = 100,
        regular: CGFloat = 150,
        large: CGFloat = 200
    ) -> some View {
        let width = UIScreen.main.bounds.width
        let size = width < 400 ? compact : width < 600 ? regular : large
        return self.frame(width: size, height: size)
    }
}

// MARK: - Device-Specific Constants

struct DeviceConstants {
    static let compactScreenWidth: CGFloat = 400
    static let regularScreenWidth: CGFloat = 600
    
    static let compactSpacing: CGFloat = 8
    static let regularSpacing: CGFloat = 16
    static let largeSpacing: CGFloat = 24
    
    static let compactFontSize: CGFloat = 14
    static let regularFontSize: CGFloat = 16
    static let largeFontSize: CGFloat = 18
    
    static let compactPadding: CGFloat = 12
    static let regularPadding: CGFloat = 16
    static let largePadding: CGFloat = 20
}

// MARK: - Environment Values for Device Adaptation

struct DeviceAdaptiveEnvironmentKey: EnvironmentKey {
    static let defaultValue: DeviceAdaptiveInfo = DeviceAdaptiveInfo()
}

struct DeviceAdaptiveInfo {
    let isCompact: Bool
    let isRegular: Bool
    let isLarge: Bool
    let isTablet: Bool
    let isLandscape: Bool
    
    init() {
        let width = UIScreen.main.bounds.width
        self.isCompact = width < DeviceConstants.compactScreenWidth
        self.isRegular = width >= DeviceConstants.compactScreenWidth && width < DeviceConstants.regularScreenWidth
        self.isLarge = width >= DeviceConstants.regularScreenWidth
        self.isTablet = UIDevice.current.userInterfaceIdiom == .pad
        self.isLandscape = UIDevice.current.orientation.isLandscape
    }
}

extension EnvironmentValues {
    var deviceAdaptive: DeviceAdaptiveInfo {
        get { self[DeviceAdaptiveEnvironmentKey.self] }
        set { self[DeviceAdaptiveEnvironmentKey.self] = newValue }
    }
}

// MARK: - Responsive Container Views

struct ResponsiveContainer<Content: View>: View {
    let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        content()
            .environment(\.deviceAdaptive, DeviceAdaptiveInfo())
    }
}

// MARK: - Adaptive List Styles

struct AdaptiveListStyle: ViewModifier {
    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            content.listStyle(InsetGroupedListStyle())
        } else {
            content.listStyle(PlainListStyle())
        }
    }
}

extension View {
    func adaptiveListStyle() -> some View {
        self.modifier(AdaptiveListStyle())
    }
}


