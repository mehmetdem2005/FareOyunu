# P1.9.2 / P1.9.3 candidate — independent geometry kernels

Base: 7cd8f58247d3ff44654e208f58124cd9c083597e; package CI 46026392317 passed. Native fixture preserved (64 regions / 16,777,216 exact height samples). 22/43 package/source milestones, no device FPS improvement inferred.

Parallel candidate work:
- D8 strict downhill flow graph; linear topological processing, uniform unit runoff, closed boundaries, conservative sediment pass, bounded local cut, sinks retain material. This is a single-pass approximation, not hydraulic simulation or depression filling. 256x256 max, rectangular Float32 input. Source conversion and setup synchronous; step budget is soft, device latency unknown. Closed sinks can accumulate excessive deposits; do not promote as production erosion until evaluation. No runtime worker, no native resource mutation.
- Compact physical-scale rotated elliptical bump/hollow/trench stamp; zero first derivative at footprint boundary, negative/positive relief, resolution guard (two samples per radius). RF source unchanged. Local work after full source duplication; duplication cost and mobile latency not measured. Does not solve cross-region brush seams or sub-sample micro detail.
- Three independent correctness jobs, no benchmark; existing ridge tested too. No gameplay/default quality changes. No package build on candidate branch.
- User panel contract: existing Terrain toggle, Brush switch, collapsible panel, existing save/undo/quality controls must remain. New tools are independent kernels until integrated into the existing panel with cancel/undo/redo and safe native region write workflow. Do not replace the user's editor panel with the standalone test scene. No UI change in candidate.
- Pending: CI results, usability integration, erosion preview + export, micro detail brush and cross-region consistency, performance measurement before any default promotion. P1.9.2/3 not counted complete on kernel-only evidence.
