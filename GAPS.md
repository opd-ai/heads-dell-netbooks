# Implementation Gaps — 2026-05-28

## No Implementation Exists

- **Stated Goal**: The repository defines a comprehensive 8-stage HEADS firmware porting assistant workflow with safety gates, board verification, guided walkthroughs, troubleshooting modes, and risk assessment capabilities.
- **Current State**: The repository contains only documentation (`README.md` and `ROADMAP.md`). There is no source code, no Go module, no tooling, no automation, and no programmatic enforcement of any described workflow.
- **Impact**: All stated goals exist only as written specifications. Users cannot use this repository as a tool — they can only read the documentation. No safety gates are programmatically enforced, no board compatibility checks are automated, and no guided walkthrough logic exists in code.
- **Closing the Gap**: Implement the assistant workflow as software (e.g., a Go CLI tool or interactive application) that enforces the safety gate, validates hardware IDs, guides users through stages, and provides the four response modes described in the README.

## Safety Gate Not Enforced Programmatically

- **Stated Goal**: "Always verify all items below before proceeding with guidance" — HWID verification, firmware backup with SHA256, restore test, and 3120 exclusion.
- **Current State**: Safety gate is documented as a requirement but has no code to enforce it. Any assistant consuming this spec must implement the checks externally.
- **Impact**: A user or assistant could skip safety prerequisites, potentially leading to device bricking (especially the Dell Chromebook 3120 / wolf mismatch scenario).
- **Closing the Gap**: Implement programmatic safety gate checks that block workflow progression until all four prerequisites are verified and logged.

## Board Compatibility Validation Not Automated

- **Stated Goal**: Only WOLF and LULU boards are supported. Dell Chromebook 3120 must be explicitly excluded from the wolf path.
- **Current State**: Board compatibility is stated in documentation only. No code validates hardware IDs or prevents misidentification.
- **Impact**: Users could attempt to flash incompatible firmware without automated guardrails.
- **Closing the Gap**: Implement HWID prefix parsing and validation logic that rejects unsupported boards and flags the 3120/wolf conflict with a hard stop.

## Knowledge Base Stages Have No Structured Data

- **Stated Goal**: 8 stages of structured knowledge covering prerequisites, hardware prep, build, flash, TPM, OS install, hardening, and documentation.
- **Current State**: Stages are described as markdown sections. There is no structured data format (JSON, YAML, database) that would enable programmatic stage tracking, prerequisite validation, or progress persistence.
- **Impact**: Cannot build automated tooling that tracks user progress through stages or validates prerequisite completion.
- **Closing the Gap**: Define a structured schema for stages, steps, prerequisites, and success criteria. Implement stage progression logic with prerequisite gating.

## Response Modes Not Implemented

- **Stated Goal**: Four response modes — Guided Walkthrough, Technical Lookup, Troubleshooting, and Risk Assessment — each with specific behavioral contracts.
- **Current State**: Modes are described textually but no code implements their logic, decision trees, or output formatting.
- **Impact**: The response mode specification cannot be consumed programmatically by any assistant or tool.
- **Closing the Gap**: Implement each response mode as a distinct code path with defined inputs, outputs, and behavioral rules matching the specification.
