# CampusLink Code Audit

## Overall Summary

This audit provides a comprehensive review of the CampusLink Swift codebase, focusing on security, scalability, maintainability, and overall quality. The application is a solid starting point, demonstrating good use of modern SwiftUI and the Supabase backend-as-a-service. However, several key areas require attention to ensure the application is robust, secure, and easy to maintain as it grows.

The most critical issues identified are the duplication of code, particularly between `ProfileView` and `ProfileTabView`, and the need for a more robust data access layer to handle scalability concerns like pagination. Addressing these will significantly improve the long-term health of the codebase.

---

## 1. Security

The application has a decent security posture, leveraging Supabase for authentication and storage. However, there are areas for improvement.

### Findings & Recommendations

*   **Secrets Management:**
    *   **Finding:** The app initializes the Supabase client using `Secrets.supabaseURL` and `Secrets.supabaseKey`. It's assumed this `Secrets.swift` file is correctly managed and excluded from version control via `.gitignore`.
    *   **Recommendation:** Ensure `Secrets.swift` is never committed to the repository. For a production environment, consider more robust secrets management solutions like Xcode Configurations (`.xcconfig`) or a service like Azure Key Vault or AWS Secrets Manager to avoid hardcoding keys in the source.

*   **Input Validation:**
    *   **Finding:** The sign-up process correctly validates that an email ends with `.edu`. However, other user-provided inputs (name, bio, listing details) are not validated for length, format, or potential malicious content.
    *   **Recommendation:** Implement input validation on all user-generated content. For example, limit the length of names and bios, and sanitize description fields to prevent potential injection attacks if the content is ever rendered in a web view.

*   **Authorization:**
    *   **Finding:** The app relies on Supabase's Row Level Security (RLS), which is excellent. However, the client-side code makes assumptions about what the user can and cannot do. For example, the `deleteListing` function is available to the user who created it, which is good, but this must be enforced by RLS on the backend.
    *   **Recommendation:** Double-check all Supabase RLS policies. Ensure that a user cannot access or modify data they don't own, even if they bypass client-side UI checks. For instance, a user should not be able to update or delete a listing belonging to another user.

---

## 2. Scalability

The current implementation may face challenges as the user base and data volume grow.

### Findings & Recommendations

*   **Data Fetching & Pagination:**
    *   **Finding:** The `HomeTabView` fetches all listings associated with a user's university domain (`.eq("users.email", value: "%@\(domain)")`). For a large university with thousands of listings, this will be slow and inefficient, potentially leading to high memory consumption and long load times.
    *   **Recommendation:** Implement pagination for all list views (home feed, my listings). Fetch data in smaller chunks (e.g., 20-30 items at a time) and load more as the user scrolls. Supabase supports range queries (`.range()`) for this purpose.

*   **Image Handling:**
    *   **Finding:** The app uploads and downloads full-resolution images, which can be slow and consume significant bandwidth. While JPEG compression is used, the image dimensions are not constrained.
    *   **Recommendation:**
        1.  **Client-Side Resizing:** Before uploading, resize images to a maximum dimension (e.g., 1080p). This will significantly reduce upload time and storage costs.
        2.  **Use a CDN with Image Transformation:** For displaying images, use a service like Supabase Storage transformations or a dedicated CDN (Cloudinary, Imgix) to request images at the exact size needed for the view. This avoids downloading large images for small thumbnails.

*   **Client-Side Filtering:**
    *   **Finding:** The query in `HomeTabView` to get listings from the same university domain is inefficient (`.eq("users.email", value: "%@\(domain)")`). This requires a join and a text search on the email column.
    *   **Recommendation:** It would be more scalable to have a `university_id` on both the `users` and `listings` tables. This would allow for a much faster and more direct query.

---

## 3. Maintainability

This is the area with the most need for immediate improvement. Refactoring now will prevent significant issues down the line.

### Findings & Recommendations

*   **Code Duplication:**
    *   **Finding:** The `ProfileView` and `ProfileTabView` are nearly identical. They share the same UI, state variables, and functions for loading and saving a user profile. This is a significant violation of the Don't Repeat Yourself (DRY) principle. Similarly, `HomeView` and `HomeTabView` have overlapping purposes and could be consolidated.
    *   **Recommendation:**
        1.  **Refactor Profile Views:** Create a single, reusable `ProfileView` that contains all the UI and logic. The `ProfileTabView` can then simply embed this view. Any logic for navigation or context can be passed in as parameters.
        2.  **Consolidate Home Views:** Decide on a single, unified home screen experience. `HomeTabView` appears to be the intended primary home screen. `HomeView` seems to be a remnant of an earlier design and should be removed or integrated.

*   **Separation of Concerns:**
    *   **Finding:** The SwiftUI views contain a large amount of business logic, including data fetching, state management, and direct API calls to Supabase. This makes the views complex and difficult to test.
    *   **Recommendation:** Adopt a more structured architectural pattern like MVVM (Model-View-ViewModel).
        *   **ViewModel:** Create a `ViewModel` for each complex view (e.g., `HomeViewModel`, `ProfileViewModel`, `PostViewModel`). This ViewModel would be an `ObservableObject` responsible for handling business logic, API calls, and preparing data for the View.
        *   **View:** The View's responsibility should be limited to displaying data from the ViewModel and forwarding user actions to it.

*   **Hardcoded Strings:**
    *   **Finding:** UI text, alert messages, and navigation titles are hardcoded as strings throughout the app (e.g., "Check Your Email", "Loading listings...").
    *   **Recommendation:** Externalize all user-facing strings into a centralized file (e.g., a `Strings.swift` struct or a `.strings` file for localization). This makes it easier to manage text and prepare for future localization.

---

## 4. Overall Quality & UX

The app provides a good user experience with clear loading states and feedback.

### Findings & Recommendations

*   **Error Handling:**
    *   **Finding:** Error handling is present, but the messages shown to the user are often technical (e.g., `underlyingError.localizedDescription`). These are not always user-friendly.
    *   **Recommendation:** Create a mapping of common technical errors to user-friendly messages. For example, instead of "Request failed: notFound (404)", show "We couldn't find what you were looking for. Please try again."

*   **UI/UX Consistency:**
    *   **Finding:** The UI is generally consistent. However, there are minor inconsistencies in button styles and navigation patterns. For example, some views have a custom back button, while others would rely on the `NavigationView`'s default.
    *   **Recommendation:** Create a design system or a style guide for common UI components (buttons, text fields, colors, etc.). This can be done by creating reusable SwiftUI components (e.g., `PrimaryButton`, `SecondaryButton`).

*   **Redundant Views:**
    *   **Finding:** As mentioned in the maintainability section, there are redundant views (`ProfileView`/`ProfileTabView`, `HomeView`/`HomeTabView`). This not only affects maintainability but also creates confusion about the app's intended navigation flow.
    *   **Recommendation:** Consolidate these views to create a single, clear path for each feature.

---

## Actionable Next Steps (Prioritized)

1.  **Refactor Profile Views:** Merge `ProfileView` and `ProfileTabView` into a single, reusable component. This is the highest-priority maintainability fix.
2.  **Implement Pagination:** Add pagination to the `HomeTabView` to make the app scalable for a large number of listings.
3.  **Introduce ViewModels:** Begin separating logic from views by creating a `ProfileViewModel` and a `HomeViewModel` to handle data fetching and business logic.
4.  **Optimize Image Handling:** Implement client-side image resizing before upload.
5.  **Review RLS Policies:** Conduct a thorough review of all Supabase Row Level Security policies to ensure data is secure.
