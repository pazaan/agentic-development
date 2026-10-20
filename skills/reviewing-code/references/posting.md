# Posting to GitHub

Load this when the review goes onto a pull request rather than back to the
person who asked for it.

- Submit one review (`POST /repos/{owner}/{repo}/pulls/{n}/reviews` with a
  `comments` array), not N comments.
- A comment lands only inside a diff hunk. Compute ranges first
  (`git diff -U3 BASE..HEAD -- <path> | grep '^@@'`). An out-of-hunk finding
  becomes a plain comment on the nearest in-hunk line naming the real lines.
  Long-lived modified files bite; new files never do.
- The body carries only what no inline comment can: manual steps no
  suggestion covers, a caveat no anchor owns. Otherwise empty. Comments that
  must land together say so themselves.
- GitHub renders no numbering; refer to a comment by file and symbol. Replace
  a submitted body with `PUT .../pulls/{n}/reviews/{review_id}`.
