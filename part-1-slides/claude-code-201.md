# Claude Code 201

## What 201 covers
**For people who ran a first session.** You know `/init`, `/context`, the permission modes and `/rewind` from Claude Code 101.
**How to run real work.** The working loop, spec-driven work, prompting, course-correcting, parallel sessions and long-running commands.
**How to extend it.** Workflows, mods, the official marketplace and popular public plugins.
**A full reference.** The last section lists every slash command in Claude Code 2.1.302, with a filter.


## The working loop
**Explore, plan, code, verify, commit.** Let Claude read the code first in plan mode (Shift+Tab or `/plan`). Read its plan and edit it with Ctrl+G. Then let it code.
**Skip the plan for small changes.** If you can describe the diff in one sentence, ask for it directly.
**Verify with evidence.** Give Claude a check it can run: a test, a linter, `tofu plan`, `kubectl get`. Ask for the output, not for "it works".
**Commit in small steps.** Each step that passes its check is a commit. Git is your real undo.


## Spec-driven work
**One big prompt fails on big tasks.** The context fills, the model forgets early decisions, and the result drifts.
**Interview, spec, plan.** Ask Claude to interview you one question at a time, then to write the spec to a file. Then a plan with small tasks, each with its own check.
**Implement in a fresh session.** Start a new session with only the spec and the plan. Subagents can take one task each, and a reviewer checks each task.
**Plugins help.** The superpowers plugin (section 12) packages this flow as skills.


## Prompting: the brief
**Goal, limits, check, context.** Say what you want, what must not change, how to prove it is done, and where to look.
**Act, do not suggest.** "Make the test deterministic" works better than "can you suggest a fix".
**Name the scope.** A file, a module, a namespace. Say "no other changes" when you mean it.
Pick an example on the right and compare the two prompts.


## Prompting: tricks that work
**Point at files.** Type `@path/to/file` to add a file. Paste a screenshot or pipe a log: `cat error.log | claude`.
**Let Claude ask.** "Interview me one question at a time" before a big change. "Grill me on these changes" before a merge request.
**Ask for proof.** "Prove to me this works: run it and show the output."
**Thinking.** `/effort` sets the level for the session. The word `ultrathink` in a prompt asks for deep reasoning on that one turn. Other phrases are plain text.


## Course-correcting
**Stop early.** Press Esc as soon as Claude goes the wrong way. Your next message steers it.
**Roll back, do not argue.** Esc Esc or `/rewind` lets you pick a point and restore the code, the chat or both. It does not undo shell commands, so keep using git.
**The two-correction rule.** After two failed corrections, `/clear` and start again with a better prompt.
**Clear or compact.** `/clear` between unrelated tasks. `/compact keep the API decisions` to continue the same task. `/btw` for a side question that stays out of the history.


## Parallel work
**One worktree per session.** `claude -w fix-login` creates a git worktree on its own branch, so two sessions do not edit the same files.
**Fresh or forked subagents.** Built-in and custom subagents start fresh with only Claude's brief: use them for independent review or big searches. A fork inherits the entire conversation and starts from the same prompt cache: use it when the helper needs all the background. `/subtask` starts a forked subagent; `/fork` copies the conversation into a new background session.
**Agent view.** `claude agents` shows your sessions and background agents in one place. Ten agents use your quota about ten times as fast as one.


## Long-running commands
**/goal keeps working until a condition is true.** A small model checks the condition after each turn. Add a limit yourself:
> /goal 'ruff check .' exits 0, pytest passes, nothing in migrations/ changed, or stop after 20 turns
**/loop repeats a prompt.** `/loop 10m check the CI of my branch` runs while the session is open.
**/schedule runs in the cloud.** Tasks run as you, also when your laptop is closed, at most once an hour.
**/batch splits a big change.** It plans 5 to 30 units, shows the plan for your approval, then runs each in its own worktree.


## The Workflow tool and ultracode
**A workflow is a script of agents.** Claude writes a small JavaScript script that starts many subagents in parallel or in stages, and the script keeps their results.
**You opt in.** Say "use a workflow", type the word `ultracode` in a prompt, or run `/effort ultracode`.
**Watch and control it.** `/workflows` shows the progress; you can pause, stop or save a script as a command. `/deep-research` is a built-in workflow.
**It costs a lot.** Up to 16 agents run at once. Start on a small slice of the job before you run it on everything.


## Mods
**A mod changes Claude Code itself.** It is a plugin with JavaScript or TypeScript code that runs inside Claude Code. `/diff` is a built-in mod.
**What it can do.** Draw a pane or a band with buttons, redraw the spinner or a tool row, hold a risky tool call and ask you first, or add a command that runs at once with no Claude turn.
**Get one.** Describe it to Claude and it writes the mod, or install one with `/plugin install`. A mod runs with your permissions: install only from people you trust. See the mods overview (https://code.claude.com/docs/en/plugins/mods/overview).


## The official marketplace
Claude Code adds `claude-plugins-official` on the first start. It has more than 300 plugins. Install one with `/plugin install name@claude-plugins-official`.
- **commit-commands:** commands to commit, push and open a pull request.
- **code-review** and **pr-review-toolkit:** parallel review agents for a diff or a pull request.
- **feature-dev:** a guided flow from idea to tested feature.
- **security-guidance:** warnings about risky code while Claude edits.
- **hookify:** write hooks from a plain description.
- **claude-md-management:** audit and update your CLAUDE.md.
- **skill-creator:** write and test your own skills.
- **frontend-design:** better looking web pages.
- **pyright-lsp** and other **-lsp** plugins: code intelligence for a language.


## Popular public plugins
**superpowers (Jesse Vincent).** Skills for brainstorming, specs, plans, test-driven work and reviews by subagents. About 1 million installs. `/plugin install superpowers@claude-plugins-official`. It adds steps and reviews, so it uses more tokens.
**caveman (Julius Brussee).** Short, terse replies to save output tokens. `/plugin marketplace add JuliusBrussee/caveman`, then `/plugin install caveman@caveman`. It changes the tone of every reply.
**ponytail (Dietrich Gebert).** Asks for the smallest change that solves the task, plus review and audit commands. `/plugin marketplace add DietrichGebert/ponytail`, then `/plugin install ponytail@ponytail`.
**Anthropic skills.** `/plugin marketplace add anthropics/skills` gives document skills for Excel, Word, PowerPoint and PDF files.


## Recommendations
**Start small, add when you repeat yourself.** CLAUDE.md first. A skill or a hook when you explain the same thing the third time. A plugin when the team needs it too.
**Watch tokens per task.** Keep `/context` low, use subagents for searches, and pick the effort per task. Check `/usage` after a long session.
**Stay safe.** Read permission requests on shared systems. Install plugins and mods only from trusted sources: they run with your permissions.
**Check the facts.** A flag or an API name is a guess until you see it work.


## Every slash command
All commands from the Claude Code docs for version 2.1.302. Type to filter, pick a group, or show only the bundled skills. Removed commands are not listed.
Type / in Claude Code to see the same menu for your version.


## Tips from the Claude Code team
**147 tips in 27 parts.** Boris Cherny created Claude Code, and the community site How Boris uses Claude Code collects his and his team's tips. This explorer retells each tip in our own words.
**Pick a part, then a tip.** Each tip has a short demo and one takeaway. A tip marked as replaced has a newer version in a later part.
**Some commands are personal.** Tips can show a custom skill from the author's own setup, such as a "go" command. Check `/` in your Claude Code before you rely on one.
Source: howborisusesclaudecode.com (https://howborisusesclaudecode.com/); each tip links to its original post.


## Links
- Best practices (https://code.claude.com/docs/en/best-practices) and Common workflows (https://code.claude.com/docs/en/common-workflows)
- All commands (https://code.claude.com/docs/en/commands) and Mods (https://code.claude.com/docs/en/plugins/mods/overview)
- Prompt engineering guide (https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/overview)
- How Boris uses Claude Code (https://howborisusesclaudecode.com/) (community collection of tips)
- superpowers (https://github.com/obra/superpowers), caveman (https://github.com/JuliusBrussee/caveman), ponytail (https://github.com/DietrichGebert/ponytail), Anthropic skills (https://github.com/anthropics/skills)
- awesome-claude-code (https://github.com/hesreallyhim/awesome-claude-code): a community list
- Back to AI from scratch and Claude Code 101
