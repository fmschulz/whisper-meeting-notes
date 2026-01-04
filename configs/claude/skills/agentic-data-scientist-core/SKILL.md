---
name: agentic-data-scientist-core
description: Multi-agent workflow for complex data science requests. Emphasizes planning, iterative execution, validation, and use of Claude scientific skills for analysis, modeling, and reporting.
---

# Agentic Data Scientist (Core)

## When to Use
- End-to-end data/ML work that needs planning, experiments, and validation.
- Requests that span EDA, feature work, modeling, and reporting.
- Situations where progress should be checkpointed and reviewed, not just quick scripts.

## Operating Principles
1. **Clarify + Plan**: Restate the goal, surface assumptions, and draft a minimal plan with success criteria and deliverables. Prefer orchestrated steps over one-shot coding.
2. **Workspace Hygiene**: Keep work in a dedicated project folder (e.g., `agentic_output/` or repo sandbox). Track artifacts (data, notebooks, reports, metrics) explicitly.
3. **Skill-First Execution**: Use Claude skills before ad-hoc coding:
   - `get-available-resources` to size compute before heavy jobs.
   - `exploratory-data-analysis` for first-pass profiling of any dataset.
   - `statistical-analysis` + `matplotlib` for quick stats/plots.
   - `scikit-learn` for classical baselines; `pytorch-lightning` for deep learning.
   - `research-lookup` + `citation-management` when citing methods or prior art.
4. **Iterate with Checks**: After each major step, validate against the plan; revise if data insights contradict assumptions.
5. **Review + Report**: Summarize metrics, decisions, risks, and next steps. Save concise READMEs or reports with commands to reproduce.

## Default Workflow
1. Inventory files + data; note formats and sizes.
2. Run EDA with the EDA/statistics/matplotlib skills; capture findings in markdown.
3. Define modeling path (baseline first). Track configs and seeds.
4. Train/evaluate; log metrics and plots; compare against success criteria.
5. Reflect and adjust plan; propose follow-ups or deployment steps.

## Notes
- If the `agentic-data-scientist` CLI is available, prefer orchestrated mode for complex jobs and simple mode for quick scripts. Otherwise, follow this workflow manually inside Claude Code.
- Avoid silent assumptions; narrate changes to plan and highlight blockers (missing data, compute, keys).
