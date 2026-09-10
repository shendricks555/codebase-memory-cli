---
paths:
  - "src/pipeline/**"
  - "internal/cbm/**"
description: Indexing pipeline and language-extraction pattern (upstream feature work)
---

# Pipeline passes and language extraction

This is general upstream feature-work territory, not fork-specific — but
useful context when a spec/plan touches indexing.

1. Grammar/AST node config lives in `internal/cbm/lang_specs.c`; extraction
   logic in `internal/cbm/extract_*.c`.
2. Pipeline passes (call resolution, usage tracking, HTTP-route linking) live
   in `src/pipeline/pass_*.c`.
3. Infra-language support (Dockerfile/K8s/Kustomize) follows the "infra-pass"
   pattern in `src/pipeline/pass_infrascan.c` + `internal/cbm/extract_k8s.c`,
   reusing the tree-sitter YAML grammar rather than adding new grammars.
4. Regression tests: `tests/test_extraction.c`, `tests/test_pipeline.c`.

Minimize footprint here per the upstream-mergeability constraint in
[[architecture]] — prefer additive passes/extractors over rewriting existing
ones.
