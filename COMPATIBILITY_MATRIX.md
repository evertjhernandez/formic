# PDFKit Compatibility Matrix

Milestone 0 must prove that supported documents can be opened, edited, saved, closed, and reopened without unexplained data loss.

## Test categories

| Category | Minimum samples | Open/render | Search | Annotate round-trip | Page operation round-trip | Print/export | Notes |
| --- | ---: | --- | --- | --- | --- | --- | --- |
| Normal text PDFs | 10 | Pending | Pending | Pending | Pending | Pending | Mixed generators and fonts |
| Scanned/image PDFs | 5 | Pending | N/A before OCR | Pending | Pending | Pending | Include high-resolution scans |
| Encrypted PDFs | 5 | Pending | Pending | Pending | Pending | Pending | User/owner passwords and restrictions |
| Existing annotations | 5 | Pending | Pending | Pending | Pending | Pending | Preview, Acrobat, and third-party authors |
| AcroForms | 5 | Pending | Pending | Pending | Pending | Pending | Text, checkbox, radio, and choice widgets |
| Signed PDFs | 5 | Pending | Pending | Pending | Pending | Pending | Confirm whether edits invalidate signatures |
| Mixed page geometry | 5 | Pending | Pending | Pending | Pending | Pending | Sizes, crop boxes, and rotations |
| Large documents | 5 | Pending | Pending | Pending | Pending | Pending | At least one 500+ page document |
| Damaged/unusual PDFs | 5 | Pending | Pending | Pending | Pending | Pending | Must fail safely if unsupported |

## Automated generated baseline

`PDFDocumentRoundTripTests` provides a fast local safety baseline. It does not replace the 50-file, cross-viewer corpus above.

| Check | Status | Notes |
| --- | --- | --- |
| Searchable vector text save/reopen | Pass | Case-insensitive PDFKit search finds generated text after serialization. |
| Text-note save/reopen | Pass with normalization | Contents, author, and subtype persist. PDFKit may create an associated popup annotation and normalize the note icon to a 24×24 rectangle. |
| Page reorder, duplicate, rotate, and delete | Pass | Page order, text, media-box size, and rotation persist after serialization. |
| Invalid data rejection | Pass | Invalid bytes do not produce a `PDFDocument`. |

## Go/no-go rule

Proceed with PDFKit only when:

- No supported operation corrupts a source document.
- Failed or cancelled saves leave the original untouched.
- Known lossy behavior is detected and communicated before writing.
- Annotation and page-operation output reopens correctly in Preview and one independent viewer.
- Performance remains usable on the large-document samples.

If these conditions are not met, evaluate Apryse, Foxit, and Nutrient against the same files before expanding the UI.
