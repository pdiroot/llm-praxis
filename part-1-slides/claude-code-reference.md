# Claude Code reference

For the hands-on session, open [Claude Code 101](../part-2-playground/README.md).

## What Claude Code is
**A harness in your terminal.** Claude Code is the harness from AI basics; Claude is the model inside it. It reads your files, runs commands, edits code and checks its own work.
**Permission modes set the rules.** They decide what it may do without asking you.
Model = brain. Claude Code = hands, eyes, notebook and rules.


## Install and first run
**Install, then start in a project.** Install the CLI, open a project folder and type `claude`. The first start asks you to log in in the browser.
**Four ways to start.** `claude` for a session, `claude -p` for one answer in a script, `claude -c` to continue the last chat, `claude -r` to pick an older one.
Start Claude Code inside the folder it should work on.


## First session
**Ask before you change.** Start with questions about the code. Then run `/init`: Claude writes a `CLAUDE.md` with the build commands and the rules it found.
**CLAUDE.md is loaded in every session.** Keep it short: commands Claude cannot guess, rules that differ from the defaults, known traps. Edit it with `/memory`: pick the file, and it opens in your editor (the first row turns auto memory on or off). Commit it to git.
**Edits load later.** Claude reads CLAUDE.md when the session starts. An edit applies after `/clear`, `/compact` or a restart, and it does not break the prompt cache.
Each mistake Claude repeats becomes one line in CLAUDE.md.


## Project or workspace
**Per project.** Start Claude Code in one git repository. Its `CLAUDE.md` holds that project's rules.
**Per workspace.** Start it in a folder that holds knowledge files, guides for Claude and several cloned repositories. Claude then sees how the repositories connect.
**One prompt, three merge requests.** Change the application and its pipeline in one repository, its Helm chart in a second and the Terraform for AWS in a third. One session makes all three changes and opens three merge requests, instead of three separate runs.


## Context hygiene
**Watch the window.** `/context` shows what fills it. One task, one conversation: `/clear` when you start something new.
**Compact with a focus.** `/compact keep the API decisions` replaces the chat with a summary. Press Ctrl+O to read the full summary, and run `/context` after it to see what is still loaded.
**What survives compaction.** The system prompt, the project's `CLAUDE.md`, skill descriptions, the plan and a few recent files. Rules you gave only in the chat can be lost, so put lasting rules in `CLAUDE.md`.
**Side questions.** `/btw` asks something that does not go into the conversation.


## Models, effort and cost
**Pick the model and the effort.** `/model` switches the model. `/effort` sets how hard it thinks: low, medium, high, xhigh, max or auto.
**Watch the cost.** `/usage` shows the session cost and your plan limits. `/statusline` can show the context use all the time.
Low effort for simple edits. High effort for a hard bug or a design.


## Permission modes
**New sessions usually start in auto mode.** File edits run, and a safety check decides about commands. Press Shift+Tab to change the mode.
**Manual mode asks first.** Start in it with `claude --permission-mode default`, or press Shift+Tab once from auto mode. Plan mode (`/plan`) reads and plans, and edits nothing.
**Allow narrow rules.** `/permissions` manages allow, ask and deny rules, for example one test command, not "any shell command".
Remember the deleted kube-system from AI basics. Give freedom only where a mistake is cheap.


## Plan, then execute
**Plan first.** Press Shift+Tab until the status bar shows plan mode, or type `/plan` with the task. Claude reads the code and writes a plan; it edits nothing.
**Read and change the plan.** Ctrl+G opens the plan in your text editor. Change it, save, and Claude uses your version.
**Approve to execute.** Pick "Yes, and use auto mode", "Yes, manually approve edits" or "Tell Claude what to change". Claude then works through the plan in the mode you picked.
**Check at the end.** Ask it to run the tests or the check named in the plan, then read the changes with `/diff`.


## Undo and review
**Roll back, do not argue.** Esc Esc or `/rewind` lets you pick an earlier point and restore the code, the chat or both. Files that only shell commands changed stay as they are, so use git too.
**Review before you commit.** `/diff` shows all changes in the working tree. `/review` checks the diff for bugs.


## Customize: the feature map
**Seven ways to teach Claude Code.** CLAUDE.md, skills, subagents, hooks, MCP servers, mods and plugins. Click a card to see what each one is and when to use it.
Start with CLAUDE.md. Add the others when you repeat yourself.


## Plugins and skills
**A plugin installs many things at once.** Skills, commands, subagents and hooks. The official marketplace is already added: open `/plugin` to browse it.
**Skills load when needed.** Claude loads a skill when the task fits, or you type its name as a slash command. `/skills` lists them with their size.
**Reloading.** Edits to a skill load by themselves. `/reload-skills` finds skills you added during the session. `/reload-plugins` applies plugin changes such as hooks, MCP servers and agents.
Good first plugins: frontend-design, claude-md-management, explanatory-output-style.


## MCP
**Connect outside systems.** An MCP server gives Claude new tools: a docs site, a database, Slack, a monitoring tool. Add one with `claude mcp add` and manage it with `/mcp`.
**Only names load at the start.** Full tool details load when Claude uses a tool, so idle servers cost little context.
An MCP server can read and change data in the outside system. Treat it as a new colleague with that access.


## Subagents
**A helper with its own context.** Claude hands a side task to a subagent. The helper does the work and returns only a short answer, so the main conversation stays small.
**Fresh or forked.** Built-in subagents (such as Explore and Plan) and your custom subagents start fresh: they see only the brief Claude writes. A fork inherits the entire conversation, so it needs no brief and starts from the same cache.
**Your own agents and forks.** A custom subagent is a Markdown file in `.claude/agents/` with a name, a description and its tools. It can also set its own `model` and `effort`, for example a cheap model for searches. `/subtask` starts a forked subagent for a task.


## Output styles
**How Claude answers you.** An output style is a set of instructions for the tone and format of every reply in the session. What Claude should know about the project still goes in `CLAUDE.md`.
**Four built-in styles.** Concise leads with the result and skips the narration. Explanatory adds short Insight blocks on why the code looks the way it does. Learning leaves small pieces of code for you to write. Proactive starts work at once and asks fewer routine questions.
**Switch any time.** `/output-style concise` switches, `/output-style` alone lists the styles, and `/config` has the same choice. Your own style is a Markdown file in `.claude/output-styles/`.
New to a codebase? Try Explanatory. Replies too long? Try Concise.


## Good habits
**Give a full brief.** The goal, the limits and how to check the result.
**Let Claude verify.** A test or a command it can run is the biggest quality boost you can give it.
**Plan big tasks, review every diff.** And when Claude repeats a mistake, add one line to `CLAUDE.md`.
**Keep secrets out.** Not in prompts, not in `CLAUDE.md`.


## Cheat sheet
**All commands from this page.** Type to filter, or pick a stage. Type / in Claude Code to see the full menu.
Every command, workflows, prompting and popular plugins are in Claude Code 201. Back to AI basics. Many tips here come from How Boris uses Claude Code (https://howborisusesclaudecode.com/).
