---
name: flutter-development
description: Implement or review SmartUMC Flutter/Dart application features across the Android student app and lecturer web interface.
---

# Flutter development

- Read the relevant source, project `AGENTS.md`, and current feature conventions before implementation. Treat existing code as evidence; do not infer a feature from a plan or UI alone.
- Preserve the confirmed shared Flutter repository, Android student experience, separate lecturer web interface, and limited Super Admin role. Do not expand scope independently.
- Separate presentation, application/domain behavior, and data access in a way that fits the existing project. Prefer reusable widgets when they reduce duplication without obscuring feature-specific behavior.
- Follow existing state-management and routing conventions. If none exist or they are insufficient, propose a minimal approach and explain the trade-offs before introducing a package.
- Keep Dart readable, typed, and consistent with analyzer/lint settings. Avoid unrelated rewrites and unnecessary abstractions.
- Do not introduce dependencies without explaining the purpose and obtaining project director approval.
- Keep shared code compatible with Android and web where it is used by both. Account for platform-only APIs at explicit boundaries; verify relevant Android and web targets when authorized and feasible.
- Use synthetic demonstration data only. Do not change Firebase production configuration or deploy services without explicit approval.
- Test changed behavior at appropriate layers and report commands/results, including any verification that could not be run.
