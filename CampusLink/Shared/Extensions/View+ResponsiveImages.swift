import SwiftUI

// MARK: - Responsive Image System
// This extension provides responsive image handling for all device sizes

extension View {
    
    // MARK: - Responsive Image Sizing
    
    /// Creates a responsive image that scales with device size
    func responsiveImage(
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        maxWidth: CGFloat? = nil,
        maxHeight: CGFloat? = nil,
        aspectRatio: CGFloat? = nil,
        contentMode: ContentMode = .fit
    ) -> some View {
        let scale = UIScreen.main.bounds.width / 375 // iPhone 12 base width
        let responsiveWidth = width != nil ? width! * scale : nil
        let responsiveHeight = height != nil ? height! * scale : nil
        let responsiveMaxWidth = maxWidth != nil ? maxWidth! * scale : nil
        let responsiveMaxHeight = maxHeight != nil ? maxHeight! * scale : nil
        
        return self
            .frame(width: responsiveWidth, height: responsiveHeight)
            .frame(maxWidth: responsiveMaxWidth, maxHeight: responsiveMaxHeight)
            .aspectRatio(aspectRatio, contentMode: contentMode)
    }
    
    /// Creates a responsive square image
    func responsiveSquareImage(size: CGFloat) -> some View {
        responsiveImage(width: size, height: size, aspectRatio: 1, contentMode: .fill)
    }
    
    /// Creates a responsive rectangular image with aspect ratio
    func responsiveRectangularImage(
        width: CGFloat,
        height: CGFloat,
        contentMode: ContentMode = .fill
    ) -> some View {
        responsiveImage(width: width, height: height, aspectRatio: width/height, contentMode: contentMode)
    }
    
    // MARK: - Device-Specific Image Sizing
    
    /// Creates images that adapt to device type
    func deviceAdaptiveImage<Content: View>(
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
    
    /// Creates images that adapt to screen size
    func screenSizeAdaptiveImage<Content: View>(
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
    
    // MARK: - Responsive Image Galleries
    
    /// Creates a responsive image gallery that adapts to screen size
    func responsiveImageGallery<Content: View>(
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ResponsiveHStack(spacing: 8) {
                content()
            }
            .responsiveHorizontalSpacing(16)
        }
    }
    
    /// Creates a responsive grid of images
    func responsiveImageGrid<Content: View>(
        columns: Int = 2,
        spacing: CGFloat = 8,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        let adaptiveColumns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns)
        
        LazyVGrid(columns: adaptiveColumns, spacing: spacing) {
            content()
        }
    }
}

// MARK: - Responsive AsyncImage

struct ResponsiveAsyncImage: View {
    let url: URL?
    let width: CGFloat?
    let height: CGFloat?
    let maxWidth: CGFloat?
    let maxHeight: CGFloat?
    let aspectRatio: CGFloat?
    let contentMode: ContentMode
    let cornerRadius: CGFloat?
    let placeholder: AnyView?
    
    init(
        url: URL?,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        maxWidth: CGFloat? = nil,
        maxHeight: CGFloat? = nil,
        aspectRatio: CGFloat? = nil,
        contentMode: ContentMode = .fit,
        cornerRadius: CGFloat? = nil,
        placeholder: AnyView? = nil
    ) {
        self.url = url
        self.width = width
        self.height = height
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.aspectRatio = aspectRatio
        self.contentMode = contentMode
        self.cornerRadius = cornerRadius
        self.placeholder = placeholder
    }
    
    var body: some View {
        AsyncImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } placeholder: {
            placeholder ?? AnyView(
                Rectangle()
                    .fill(Color(UIColor.systemGray5))
                    .overlay(ProgressView())
            )
        }
        .responsiveImage(
            width: width,
            height: height,
            maxWidth: maxWidth,
            maxHeight: maxHeight,
            aspectRatio: aspectRatio,
            contentMode: contentMode
        )
        .if(cornerRadius != nil) { view in
            view.cornerRadius(cornerRadius!)
        }
    }
}

// MARK: - Responsive Image Constants

struct ResponsiveImageConstants {
    static let smallImageSize: CGFloat = 80
    static let mediumImageSize: CGFloat = 120
    static let largeImageSize: CGFloat = 160
    static let extraLargeImageSize: CGFloat = 200
    
    static let smallCornerRadius: CGFloat = 8
    static let mediumCornerRadius: CGFloat = 12
    static let largeCornerRadius: CGFloat = 16
    
    static let smallSpacing: CGFloat = 4
    static let mediumSpacing: CGFloat = 8
    static let largeSpacing: CGFloat = 12
}

// MARK: - View Extension for Conditional Modifiers

extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Responsive Image Gallery Component

struct ResponsiveImageGallery: View {
    let images: [URL]
    let selectedIndex: Binding<Int>?
    let onImageTap: ((Int) -> Void)?
    
    init(
        images: [URL],
        selectedIndex: Binding<Int>? = nil,
        onImageTap: ((Int) -> Void)? = nil
    ) {
        self.images = images
        self.selectedIndex = selectedIndex
        self.onImageTap = onImageTap
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ResponsiveHStack(spacing: ResponsiveImageConstants.mediumSpacing) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, url in
                    ResponsiveAsyncImage(
                        url: url,
                        width: ResponsiveImageConstants.mediumImageSize,
                        height: ResponsiveImageConstants.mediumImageSize,
                        aspectRatio: 1,
                        contentMode: .fill,
                        cornerRadius: ResponsiveImageConstants.mediumCornerRadius
                    )
                    .onTapGesture {
                        selectedIndex?.wrappedValue = index
                        onImageTap?(index)
                    }
                }
            }
            .responsiveHorizontalSpacing(16)
        }
    }
}

// MARK: - Responsive Profile Image

struct ResponsiveProfileImage: View {
    let image: UIImage?
    let size: CGFloat
    let cornerRadius: CGFloat?
    
    init(
        image: UIImage?,
        size: CGFloat = ResponsiveImageConstants.mediumImageSize,
        cornerRadius: CGFloat? = nil
    ) {
        self.image = image
        self.size = size
        self.cornerRadius = cornerRadius ?? size / 2
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.gray)
            }
        }
        .responsiveSquareImage(size: size)
        .clipShape(Circle())
    }
}


