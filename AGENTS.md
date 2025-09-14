# Repository Guidelines

## Project Structure & Module Organization
- `CampusLink/` — iOS app source (Views/ViewControllers, ViewModels, Services, Resources).
- `CampusLink.xcodeproj/` — Xcode project; open to build and run.
- `CampusLinkUITests/` — UI/integration tests using XCTest.
- `supabase/` — backend configuration; SQL policies/functions live alongside root `*.sql` scripts.
- Docs: `ENABLE_SEARCH.md`, `search.md`, `goal.md`, `ratings.md` explain features and data behavior.

## Build, Test, and Development Commands
- Open project: `open CampusLink.xcodeproj` (build/run via Xcode ▶ on a simulator).
- CLI build: `xcodebuild build -scheme CampusLink -destination 'platform=iOS Simulator,name=iPhone 15'`.
- Run tests: `xcodebuild test -scheme CampusLink -destination 'platform=iOS Simulator,name=iPhone 15'`.
- SQL workflows: run the relevant `*.sql` files against your local dev database (e.g., psql or Supabase studio) and verify expected results.

## Coding Style & Naming Conventions
- Swift 5; 4-space indentation; keep lines under ~120 chars.
- Types `UpperCamelCase`; methods/properties `lowerCamelCase`; constants as `static let`.
- File names match primary type or feature (e.g., `EventListView.swift`).
- Organize by feature; keep controllers/views small; prefer clear dependency injection over singletons.
- If SwiftFormat/SwiftLint are available locally, run them before PRs; otherwise follow the rules above.

## Testing Guidelines
- Framework: XCTest (unit + UI). Place new UI tests in `CampusLinkUITests`.
- Names: files end with `Tests.swift`/`UITests.swift`; test methods start with `test...`.
- Aim for deterministic, fast tests; add fixtures to the test bundle; cover critical flows (search, ratings, privacy-related behavior).

## Commit & Pull Request Guidelines
- Use Conventional Commits when possible: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`.
- Commit messages: imperative mood; include scope when helpful (e.g., `feat(search): improve fuzzy ranking`).
- PRs: focused changes, clear description, linked issues, test notes; include simulator screenshots for UI changes.
- For SQL changes, reference the specific `*.sql` file(s) and summarize before/after behavior verified locally.

## Security & Configuration Tips
- Never commit secrets or tokens; prefer `xcconfig`/environment variables. Verify `.gitignore` coverage.
- Run SQL scripts only against a local/dev database; keep DDL idempotent when feasible.


@codex instruction: look at the codebase and fix the search feature really think about this shit ill be surprissed if you can fix it.