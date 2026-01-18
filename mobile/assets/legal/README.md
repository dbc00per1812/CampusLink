# Legal Documents

This folder contains the legal documents displayed in the CampusLink app.

## PDF Files (Recommended)

For the best display of legal documents, add your PDF files here:

1. **Terms of Service**: `terms.pdf`
2. **Privacy Policy**: `privacy.pdf`
3. **Community Guidelines**: `community-guidelines.pdf`

### How to Enable PDF Display

After adding the PDF files, update `LegalDocumentScreen.tsx`:

```typescript
// Change from:
const PDF_ASSETS: Record<DocumentType, any> = {
  terms: null,
  privacy: null,
  community: null,
};

// To:
const PDF_ASSETS: Record<DocumentType, any> = {
  terms: require('../../../assets/legal/terms.pdf'),
  privacy: require('../../../assets/legal/privacy.pdf'),
  community: require('../../../assets/legal/community-guidelines.pdf'),
};
```

You'll also need to add to `app.json` in the `assetBundlePatterns`:
```json
"assetBundlePatterns": [
  "assets/legal/*.pdf"
]
```

## HTML Files (Current Fallback)

The HTML files in this folder are standalone web versions:
- `terms.html`
- `privacy.html`
- `community-guidelines.html`

The app currently uses embedded HTML content in `LegalDocumentScreen.tsx` as a fallback when PDFs are not available.

## Updating Content

### Option 1: Update PDF Files
Replace the PDF files with updated versions.

### Option 2: Update HTML Content
Edit the `TERMS_CONTENT`, `PRIVACY_CONTENT`, and `COMMUNITY_CONTENT` constants in `LegalDocumentScreen.tsx`.
