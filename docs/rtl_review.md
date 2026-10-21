# RTL and microarchitecture review

The review examined the source contracts, all RTL modules, reset/flush priority,
queue lifetime, exception effects, synthesis results and verification coverage.

| Concern | Resolution / retained tradeoff |
|---|---|
| Two writers to one architectural register | ROB renaming; retiring map clear requires tag equality |
| Consumer dispatch on producer completion | Explicit bypass from all three result paths |
| Circular tag reuse | No outstanding old memory result at retirement; M cancellation on flush; dependent wakeup before producer retirement |
| Full/empty and simultaneous allocation/retire | Extra occupancy bit, conservative full handling, circular-interval and shadow-sequence assertions |
| Wrong-path stores and loads | Only head accesses external data memory |
| Redirect with blocked or pending fetch | Stable old request plus discard/drain protocol |
| Wrong-path faults | Recorded in ROB; only the completed head can halt |
| Signed arithmetic and RV32M corners | Explicit widths/sign correction; unit vectors and QEMU cross-check |
| Multiple results at one edge | Separate completion writes and three source wakeup comparisons; collision coverage |
| Cache errors and partial writes | Successful-response-only allocation/update, per-byte masks, standalone checker |
| Reset during pending work | Core and responder reset together; integrated reset programs and cache invalidation checks |
| Avoidable fetch bubble | Measured refinement with retained legacy mode for comparison |
| Synthesis parameter handling | Fixed script to rename the elaborated parameterized top before flattened synthesis |
| Width/unused RTL warnings | Explicit casts, separated load module and intentional unused signals; strict lint clean |

Retained constraints are explicit: no separate high-performance LSQ, no memory
replay, no register free list, no early selective branch recovery, one M operation
in flight, no privileged platform, no interrupts, no coherent/self-modifying
code, and no physical timing characterization. The integrated ROB/RS organization
is kept readable rather than split into modules with large bidirectional update
interfaces. The shared execution module serves baseline, ALU and address logic;
flattened synthesis removes unused outputs.

Future validation should add official architectural-suite integration and formal
proofs of queue/tag/recovery properties. Current evidence is finite testing,
assertions, two simulators, independent semantic checks and generic synthesis.
