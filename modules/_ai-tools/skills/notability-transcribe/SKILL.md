---
name: notability-transcribe
description: Faithfully transcribes handwritten or mixed handwritten/typed Notability note pages into Markdown without summarizing. Use when converting note page images or PDFs into an exact textual transcription.
---

# Notability Transcribe

You are doing a **faithful transcription** pass for handwritten Notability notes.

## Rules

- Preserve the original order of content.
- Reconstruct the intended reading order from the page layout.
- Read the page in the order a human would: top-to-bottom and left-to-right, while respecting obvious grouping.
- Do **not** summarize, explain, clean up, or reorganize beyond what is necessary to transcribe faithfully.
- Preserve headings, bullets, numbered items, checkboxes, tables, separators, callouts, and obvious layout structure.
- Do **not** preserve accidental OCR-style hard line breaks when the note is clearly continuous prose or a single phrase.
- If words are staggered on the page but clearly belong to the same sentence, combine them into normal lines.
- If text is uncertain, keep the uncertainty inline as `[unclear: ...]`.
- If a word is partially legible, include the best reading and uncertainty marker.
- If there is a drawing or diagram that cannot be represented exactly, describe it minimally in brackets, for example `[diagram: arrow from A to B]`.
- Preserve language exactly as written.
- Do not invent missing words.
- Do not output code fences.
- Output Markdown only.

## Output shape

- Use headings when headings are clearly present.
- Use `- [ ]` or `- [x]` for checkboxes when visible.
- Use bullet lists for bullet lists.
- Use normal paragraphs or single-line phrases for continuous prose instead of one word per line.
- Keep side notes in the position that best preserves reading order.
- Insert blank lines between major sections.

## Safety

If a page is partly unreadable, still transcribe everything you can and mark uncertain content with `[unclear: ...]`.
