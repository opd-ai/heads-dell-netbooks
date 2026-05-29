TASK: Complete the next actionable stage in ROADMAP.md for Dell Chromebook 11 (wolf) and 13 (lulu) HEADS firmware port. Generate configs, scripts, and documentation. For hardware tasks, generate handoff reports and mark complete.

EXECUTION:
1. Read ROADMAP.md, identify first incomplete stage
2. Classify items: **Type A** (configs/docs/scripts) | **Type B** (hardware/runtime → handoff report) | **Type C** (script + handoff)
3. Execute all Type A/B/C work in stage
4. Update ROADMAP.md with completions
5. Report results

AUTONOMY BOUNDARIES:
- ✓ Create/modify: configs, docs, scripts, handoff reports
- ✗ Never: execute builds, flash hardware, modify running systems
- ✗ Never: fabricate blob content (document acquisition only)

OUTPUT FORMAT:

**Type A (Config/Doc/Script):**
```
FILE: path/to/file
ROADMAP: Stage X.Y - [checklist text]
PURPOSE: [one sentence]

---BEGIN---
[complete file content]
---END---

VALIDATION: command → expected_output
```

**Type B (Hardware Handoff):**
```
HANDOFF: reports/stage-X.Y-task-name.md
ROADMAP: Stage X.Y - [checklist text]
BOARD: [wolf|lulu|both] | RISK: [Low|Medium|High|Critical]

---BEGIN---
---
title: "[Stage X.Y] [Task]"
type: [hardware|flash|validation]
estimated_time: [X hours]
date_generated: YYYY-MM-DD
---

## Task: [what human must do]

## Prerequisites
- [ ] Item 1
- [ ] Required tool

## Procedure
### Step 1: [Action]
Do: [exact command/action]
Expected: [success indicator]
Verify: `command` → output
If fails: [fix]

### Step 2: [Next Action]
[same structure]

## Success Criteria
- [ ] Measurable result 1
- [ ] Measurable result 2

## Next Steps
1. Document in reports/stage-X.Y-results.md
2. Mark ROADMAP.md complete
3. Continue to next stage

## Troubleshooting
**Problem:** [symptom] → **Fix:** [solution]
---END---
```

**Type C (Script + Handoff):**
Generate both Type A output (script file) and Type B output (execution instructions).

CONSTRAINTS:
- Placement: boards/<board>/<board>.config | config/<type>-<board>.config | docs/<board>-<type>.md | reports/stage-X.Y-<task>.md | blobs/<board>/README.md
- Blobs: Document (URL, version, SHA256) never include binary content
- Configs: Upstream Kconfig symbols, pin versions, reference x230-flash patterns
- Handoffs: Include rollback procedure for risky operations

ROADMAP UPDATES:
```
- [x] Item (YYYY-MM-DD: file.config created, validated)
- [x] Item (YYYY-MM-DD: Handoff → reports/stage-X.Y.md)
- [ ] Item (Blocked: prerequisite Stage X.Y incomplete)
```

ERROR HANDLING:
If prerequisites incomplete, required blob undocumented, or checklist ambiguous:
```
⚠️ BLOCKED: [issue]
CONTEXT: Stage X.Y "[item]"
NEED: [specific requirement]
```
Then stop and request clarification.

EXECUTION SUMMARY (After Completing Work):
```
STAGE X COMPLETED: [N/M items]

Type A generated:
- file1.config (validated: pass)
- doc.md

Type B handoffs:
- reports/stage-X.Y-task.md (Risk: High, Time: 2hrs)

ROADMAP updated: [X new checkboxes]

BLOCKED items:
- Item Z (needs: Stage Y completion)

NEXT: [Stage X+1 ready | Blocked until human completes Stage X handoffs]
```

FINAL INSTRUCTION:
Read ROADMAP.md now. Execute all actionable work in first incomplete stage. Generate all files. Update ROADMAP.md. Report completion summary.
