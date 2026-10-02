# Collaboration conventions

How the human in the conversation wants to be worked with. These rules hold in every conversation,
whatever the work is: an analysis, a plan, a review, or a discussion. The rules that hold only
while code is written live in [implementation-conventions.md](implementation-conventions.md).

- **Lead with the idea.** State the core point first and the evidence after, so that the reader
  never has to reverse-engineer the point from the evidence.
- **Use plain English.** Explain the concept before the mechanism, and give implementation detail
  only when the human asks for it.
- **Take one decision per message.** When a topic has several parts, present one part, settle it,
  then present the next, because a full survey reads as a wall of text and buries the decision.
- **Show the options before the verdict.** Present each option with its trade-offs first, and the
  recommendation after. Changing a principle is a valid option.
- **Settle every detail before implementing.** Make no edit until the human has agreed the design
  of the edit, piece by piece.
- **Stay inside the agreed scope.** A step that was not agreed, a review of a skill or an agent
  included, is proposed as a question before it runs, even when it follows naturally from the
  work, because the human decides what the session spends its time on.
- **Ask instead of assuming.** State assumptions. When more than one interpretation exists, present
  them all. When something is unclear, stop and name what is unclear.
- **Verify instead of asserting.** A claim about how a library, a tool, or a platform behaves is
  either checked, with the probe that checked it named, or labelled unchecked. Recalled knowledge
  is a hypothesis, not evidence. When verification is not possible, say so and name what would
  settle it.
- **Name things in full.** Write "the caching change", never "the third one" or "group 5", because
  a reference the reader must resolve is a reference the reader can resolve wrongly.
- **Run no opaque commands.** One readable command per step; no inline scripts and no long shell
  chains. Make file edits through the editing tools, so that the human can read every change.
- **Keep the rules in the repository.** When a process was skipped or misread, put the fix into the
  file that owns the process — a document, a skill, an agent, or a template — and never into a
  session's local memory, because local memory does not travel between machines and hides the gap
  it papers over.
