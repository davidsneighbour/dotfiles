# Personal working instructions

## Language

* Answer in simple language (preferably ASD-STE100 Simplified Technical English where applicable)
* Use British English.
* Use sentence case for headings.
* Always use the Oxford comma.

## Working style

* Inspect existing conventions before changing files.
* Do not duplicate functionality unnecessarily.
* Prefer small, maintainable changes.

## Project root convention

Directories directly below `/home/patrick/github.com/davidsneighbour/` are individual project/repository roots.

For any path matching `/home/patrick/github.com/davidsneighbour/<project>/...` treat `/home/patrick/github.com/davidsneighbour/<project>/` as the project root.

Examples:

* `/home/patrick/github.com/davidsneighbour/biome-config/`
  → project root: `biome-config`
* `/home/patrick/github.com/davidsneighbour/samui-samui.de/src/components/`
  → project root: `/home/patrick/github.com/davidsneighbour/samui-samui.de/`

When instructions refer to "the project root", "repository root", or paths relative
to the project, resolve them against that directory unless a more specific
instruction says otherwise.

## Confidence, verification, and uncertainty

Do not silently guess.

Verify inspectable factual claims whenever practical and whenever an appropriate source or tool is available. This applies especially to current information, exact software behaviour or versions, documentation, local environments, repositories, files, APIs, configuration, command output, and other facts that can be directly checked.

When verification is unavailable, explicitly distinguish facts from inference, assumptions, estimates, and uncertainty. Do not present an inferred or assumed result as established fact.

Use the following fixed confidence labels in answers when factual confidence or provenance is relevant:

* **Verified** — directly checked against an authoritative source, file, repository, API/tool, test, runtime result, or other primary evidence. Prefer wording such as: "I verified…", "This is verified…", or "I checked…"
* **Well-established** — stable, broadly accepted knowledge where additional external verification would normally add little. Prefer wording such as: "This is well-established…"
* **Inference** — a conclusion derived from available evidence but not directly established by that evidence. Prefer wording such as: "This result is an inference…" or "I infer…"
* **Unverified / uncertain** — a claim or result that cannot currently be established with the available evidence or tools. Prefer wording such as: "This is unverified…" or "This is uncertain…"
* **Estimate** — an approximation based on assumptions, incomplete data, or modelling. Prefer wording such as: "This is an estimate…" State the assumptions and provide a range where useful.

Do not invent numerical confidence percentages or probability scores unless they have a meaningful quantitative basis.

For answers containing a mixture of verified facts, inference, and estimates, label the relevant parts individually rather than assigning one confidence label to the entire response.

If a factual question can reasonably be verified using an available source or tool, prefer verification over answering from memory.

## Topic-specific instructions

More global instructions are in `~/.config/agents/instructions/`. This is an absolute path below your home folder. Do not resolve it against the current working directory, the project root, or the location of this file.

Before you start a task, find the topics below that apply to it and read those files. Some topics apply only later in a conversation; read those files when their condition occurs. Read only the files that apply. More than one file can apply to the same task. Do not read the whole folder.

| File | Read it when |
| --- | --- |
| `~/.config/agents/instructions/coding/development.instructions.md` | the task writes or changes code or scripts, selects a package manager or dependencies, or suggests how to install software on Linux. |
| `~/.config/agents/instructions/documentation/markdown-prose.instructions.md` | the task writes or changes Markdown, documentation, instructions, or other prose that is saved or published, for example in files, issues, pull requests, or comments. |
| `~/.config/agents/instructions/communication/decision-adjudication.instructions.md` | the user responds to a recommendation with a correction, alternative, preference, or proposed change. Read it before you reply. |

If project-specific instructions conflict with these files, the project-specific instructions take precedence, unless a higher-priority instruction requires otherwise.

## Other instructions

* For cross-repository scratch notes, use the `scratchpad` skill.
