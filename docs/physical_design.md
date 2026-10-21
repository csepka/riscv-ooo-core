# Synthesis and physical-design evidence

`make synth` runs `scripts/synthesize.py` for the baseline, both ROB sizes and a
standalone 16-line cache, using the same flattened generic Yosys mapping. The
measured cell breakdown, bit flip-flop counts, exact script commands, warnings,
RTL hash and tool version are saved in `results/synthesis.json`. Full netlists
and logs are regenerated in `build/`.

| Configuration | Generic cells | Bit flip-flops |
|---|---:|---:|
| Sequential RV32IM baseline | 10,432 | 1,845 |
| RV32IM OoO, 16 ROB entries | 41,029 | 6,452 |
| RV32IM OoO, 32 ROB entries | 70,966 | 11,113 |
| Standalone 16-word cache | 2,710 | 1,151 |

These are generic logic elements, **not** standard-cell area. Core counts exclude
external caches. Cache counts include the exposed performance counters. No
technology library or operating corner was used. The expected Yosys warning
lowers the dynamically accessed `dest` array into registers; it is recorded in
the report. `check -assert` and an explicit no-latch selection pass completed.

## Physical-stage status

| Stage | Evidence/status |
|---|---|
| RTL simulation and elaboration | Executed, reported separately |
| Generic synthesis | Executed for four configurations |
| Standard-cell mapping/area | Not run: no Liberty/PDK supplied or found |
| Static timing/critical paths/Fmax | Not run: OpenSTA unavailable, no library/netlist mapping |
| Floorplan, placement, CTS, routing | Not run: OpenROAD unavailable |
| DRC/LVS/parasitic extraction | Not run: tools/PDK absent |
| GDSII/signoff | Not produced |

Tool discovery found no `openroad`, `sta`, `magic` or `klayout` on PATH. Sky130
was not present in `/opt/pdks`, `/opt/homebrew/share/pdk`, `~/.volare` or
`~/.cache/volare`. Docker CLI is installed, but `docker info` failed because
`~/.docker/run/docker.sock` does not exist. This is an environment limitation,
not evidence that physical implementation would pass or fail.

## Reproducible preparation for a supplied library

The following optional flow is provided but **not executed** here:

```sh
LIBERTY=/absolute/path/to/your/library.lib ROB_DEPTH=16 make technology-synth
LIBERTY=/absolute/path/to/your/library.lib make sta
```

`technology-synth` uses Yosys flip-flop/library mapping and ABC with the supplied
library, and writes `build/mapped.v` and library-based statistics. OpenSTA then
reads that same library and netlist. `physical_design/constraints.sdc` contains an
**example** 20 ns clock budget, 0.2 ns uncertainty and 2 ns I/O delays. These are
starting assumptions to replace with actual integration requirements, not timing
results. A future flow must add valid input transition/output load models,
operating corners, clock/reset assumptions and parasitics. Check all unconstrained
paths before interpreting slack. Do not infer Fmax from this template.

For a Sky130 implementation, install a compatible legal PDK and the tools from
[OpenROAD-flow-scripts](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts),
record exact tool/PDK revisions, and integrate this top into the `sky130hd`
platform. Preserve the core's two memory-port contracts in the chip wrapper.
Then execute and archive each physical stage independently. Placement/route,
clock-tree, extraction and signoff are additional work; a synthesis report is
not a substitute for those results.

The most likely RTL scaling pressure points are the oldest-ready scans,
variable-index operand muxes and broadcast comparators. This is structural
reasoning, not a measured critical-path report. Use actual STA to decide whether
to bank queues, pipeline selection, reduce ports or adopt a separate PRF.
