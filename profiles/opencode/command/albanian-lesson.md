---
description: Turn pasted Albanian lesson into translated notes and solved exercises in zk
---

Process the pasted Albanian lesson content and create two `zk` notes: one for lesson material and one for exercises.

<lesson-material>
$ARGUMENTS
</lesson-material>

Requirements:

1. Parse the lesson content and produce two markdown outputs:
   - `material` output: lesson material only.
   - `exercises` output: exercises and solutions.
2. Use today's date in both notes (date in title and inside content).
3. In the `material` output:
   - Keep clean markdown structure with headings and bullet points.
   - Translate examples, dialogues, and all lesson texts into English when not already translated.
   - For bigger reading passages, include a word-by-word breakdown.
   - For declension/conjugation/grammar tables, provide a complete table of possibilities relevant to the topic.
   - When numbers appear, include their written-out form.
4. In the `exercises` output:
   - Include every exercise in markdown.
   - Translate each exercise to English.
   - Solve all non-free-writing tasks (multiple choice, fill in the blanks, etc.) and include example solutions.
   - For free-writing tasks, provide expanded examples using basic vocabulary from the lesson (if prompted for 3, provide 10).
   - Translate free-writing example answers into English.

Execution steps:

1. Generate two markdown contents in memory (do not create temporary files):
   - `MATERIAL_CONTENT`
   - `EXERCISES_CONTENT`
2. Set `TODAY="$(date +%F)"` once and reuse it for both notes.
3. Create note 1 with `zk` by piping markdown directly to stdin:
   - Title format: `Albanian Lesson Material - YYYY-MM-DD`
   - Command pattern:
     - `printf "%s\n" "$MATERIAL_CONTENT" | zk new --interactive --title "Albanian Lesson Material - $TODAY" --date "$TODAY" --print-path`
4. Create note 2 with `zk` by piping markdown directly to stdin:
   - Title format: `Albanian Lesson Exercises - YYYY-MM-DD`
   - Command pattern:
     - `printf "%s\n" "$EXERCISES_CONTENT" | zk new --interactive --title "Albanian Lesson Exercises - $TODAY" --date "$TODAY" --print-path`
5. Print both created note paths and a short checklist of what was included.

If no lesson material was provided in `$ARGUMENTS`, stop and ask the user to paste it.
