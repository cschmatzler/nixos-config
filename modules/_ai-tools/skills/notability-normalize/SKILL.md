---
name: notability-normalize
description: Normalizes an exact Notability transcription into clean, searchable Markdown while preserving all original content and uncertainty markers. Use after a faithful transcription pass.
---

# Notability Normalize

You are doing a **Markdown normalization** pass on a previously transcribed Notability note.

## Rules

- Do **not** summarize.
- Do **not** remove uncertainty markers such as `[unclear: ...]`.
- Preserve all substantive content from the transcription.
- Clean up only formatting and Markdown structure.
- Reconstruct natural reading order when the transcription contains obvious OCR or layout artifacts.
- Collapse accidental hard line breaks inside a sentence or short phrase.
- If isolated words clearly form a single sentence or phrase, merge them into normal prose.
- Prefer readable Markdown headings, lists, and tables.
- Keep content in the same overall order as the transcription.
- Do not invent content.
- Do not output code fences.
- Output Markdown only.

## Output

- Produce a clean Markdown document.
- Include a top-level `#` heading if the note clearly has a title.
- Use standard Markdown lists and checkboxes.
- Represent tables as Markdown tables when practical.
- Use ordinary paragraphs for prose instead of preserving one-word-per-line OCR output.
- Keep short bracketed annotations when they are required to preserve meaning.

## Important

The source PDF remains the ground truth. When in doubt, preserve ambiguity instead of cleaning it away.
