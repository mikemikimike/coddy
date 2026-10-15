---
name: triage
description: Turn review findings into tracker issues
when_to_use: Use when the user asks to file, log or create issues or tickets from findings, a review, an audit or a list of problems.
allowed-tools: Bash(bash "${CLAUDE_PLUGIN_ROOT}/scripts/config.sh"), Bash(bash "${CLAUDE_PLUGIN_ROOT}/scripts/issue.sh" status), Bash(bash "${CLAUDE_PLUGIN_ROOT}/scripts/issue.sh" state *), mcp__plugin_github_github__search_issues, mcp__plugin_github_github__issue_write, mcp__plugin_atlassian_atlassian__getAccessibleAtlassianResources, mcp__plugin_atlassian_atlassian__atlassianUserInfo, mcp__plugin_atlassian_atlassian__searchJiraIssuesUsingJql, mcp__plugin_atlassian_atlassian__createJiraIssue
---

# Triage

## Config
!`bash "${CLAUDE_PLUGIN_ROOT}/scripts/config.sh"`

## Worktrees
!`bash "${CLAUDE_PLUGIN_ROOT}/scripts/issue.sh" status`

`NOT_ONBOARDED` → stop and say: run `/coddy:onboard` first.
`tracker: jira` → every Atlassian MCP call takes `cloudId`: call `getAccessibleAtlassianResources` once and use the entry whose url is `jira.site`; me is `atlassianUserInfo`'s `accountId`. Those tools not loaded → stop and say the atlassian plugin needs to be authenticated.

## Source
Findings come from this conversation, or from `$ARGUMENTS` when given (a file path or pasted text), and from the `triage` lines of `bash "${CLAUDE_PLUGIN_ROOT}/scripts/issue.sh" state <issue>` for each claimed issue of mine in Worktrees (`owners` is `me`; empty `triage` lines are ignored): say which issue they came from.

## Steps

1. List the findings, one issue per finding. Merge duplicates.
2. Search for each finding, never one list of all open issues (it stops at a page and misses the rest): 2-4 distinctive words from the finding, then github `search_issues` with `owner` and `repo` from `repo`, `query: "is:open in:title <words>"` and `fields: [number, title, labels]`; jira `searchJiraIssuesUsingJql` with JQL `project = <project> AND statusCategory != Done AND summary ~ "<words>"`. No hit → once more with other words. A finding a hit already covers is skipped and cited.
3. Show a table: title, label, covered-by. Ask once to confirm.
4. Create each issue (github `issue_write` `create` with `title`, `body` and `labels`; jira `createJiraIssue`) with this body:
   - **Problem**: what is wrong, with evidence (`file:line`, command output).
   - **Fix**: checklist of concrete steps.
   - **Acceptance**: checklist of observable checks.
   Labels: `bug` or `enhancement` (github); issue type Bug or Task (jira).
5. Each issue whose `triage` lines were used → `bash "${CLAUDE_PLUGIN_ROOT}/scripts/issue.sh" state <issue> triage=`.
6. Print the created links.
