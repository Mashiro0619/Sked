# Offline Agent host benchmarks

`agent_performance_benchmark_test.dart` measures application-owned Agent loading,
bounded read tools, context compaction and durable main-store batches in the
already-running Flutter test host. It uses production implementations with
synthetic data and isolated storage. No model or external network is involved.

This document defines a reproducible protocol. Adding the target, or passing its
verification-only mode, supplies no performance result. Source SHA, benchmark
hashes, dataset hashes, commands and actual runtime population belong in every
measurement record. Keep physical-device acceptance separate; this target can
only establish the recorded host behavior.

## Workloads

| Case | Measured work | Validation outside timing |
| --- | --- | --- |
| `load-agent-disabled` | Construct AppRuntime, load the main archive, drain accepted startup work with the Agent disabled in the seed | Exact main snapshot; no chat, knowledge or credential load; storage counters |
| `load-entry-enabled-unopened` | Same lifecycle with the Agent entry enabled in the seed, without calling initialize | Exact main snapshot; chat/knowledge/credential stores remain dormant |
| `load-chat-opened` | Same lifecycle plus the production Agent initialize path and its accepted attachment collection | All 32 conversations decoded unchanged; one chat archive load; knowledge remains dormant |
| `long-context-compaction` | Production `boundConversationContext` over 514 provider messages | Complete ordered user requirements, unchanged system/newest group, intact tool-call/result groups, size limits and full output digest |
| `long-history-all-pages` | Every 50-message page of the 512-message conversation through `conversation.history` | Every message ID, role, timestamp, tool identity, page boundary and result order |
| `long-message-all-slices` | Every 512-Unicode-character slice of the first long reply through `conversation.read` | Full original message JSON reassembled exactly, including non-BMP characters |
| `all-timetable-pages` | All five timetables, two records per tool page | Complete selected fields and order, including noncurrent tables in a disabled student workspace |
| `all-course-pages` | All 5,000 courses, at most 100 per tool page | Every stable parent/child reference and selected field; no omitted pages or duplicate cursors |
| `complete-tool-catalog` | All application-registered capabilities, eight definitions per page | Exact registry membership, every description/schema, page boundaries and frozen full output digest |
| `rename-one-timetable` | `mutation.prepare` and awaited `mutation.commit` for the first existing timetable's name | Exactly one main save; the other four complete timetables and every course remain unchanged; full expected business snapshot, actual receipt and independent physical readback |
| `batch-one-hundred-course-locations` | Same path for 20 existing courses in each of five timetables | All 100 changes, all untouched fields, one main save and full durable readback |

The read cases reuse a loaded, immutable snapshot and a primed Skill loader.
Resource readers are warm after the normal five warm-ups. History calls bind the
actual decoded conversation to `ApplicationToolHost`'s existing caller callback;
they do not start a model run or add measurement messages to the history being
read. The catalog and resource cases use AppRuntime's actual registered host.
This measures these production tool implementations, not model round latency.

Bulk operations run inside the production `runtime.runHostAction` scope, with its
ordinary permission and lifetime gates. The timer begins immediately before
preparation and stops only after the main-store commit future completes.
Enclosing host-run chat bookkeeping, fixture creation, Skill preparation,
checksums, full independent readback and cleanup are outside that interval.
The actual save retains production codecs, flush, verification and rename.
Notification delivery and UI response are not part of the measured interval.

The initial `batch-five-timetable-names` draft did not complete. Renaming all
five 1,000-course timetables produced 3,707,556 bytes of undo change JSON alone.
The production receipt admits at most 1 MiB and 100,000 JSON nodes, so
preparation rejected that workload before any main save. The full reversible
snapshots and admission limits remain in force. `rename-one-timetable` measures
the first timetable only, retaining all 5,000 courses in the fixture and checking
that the other four complete timetables stay unchanged. Its admitted undo change
JSON is 741,512 bytes. This single-table measurement does not establish that the
original five-table operation succeeds. The manifest and frozen contract retain
the original unfinished workload and its capacity boundary explicitly. The
100-course batch still changes 20 courses in each of all five timetables.

## Fixed data and output contract

The main fixture derives from performance dataset 8: five timetables with 1,000
courses each and 5,000 events. Course/event records are preserved. The Agent
fixture explicitly sets the local feature flag, English locale, general active
workspace, a disabled student workspace and a fixed empty ledger generation.
Both enabled and disabled complete snapshot hashes are recorded. Each mutation
case uses sequence 1 and its own fixed UUID nonce within this generation.
Before seeding disk, the production normalizer resolves synthetic conflict
choices and fills deterministic course-color preferences. Complete timetable
and calendar records must remain identical to performance dataset 8. This
preparation stays outside timing and prevents a migration save during loading.
The storage decoder also validates acknowledgement ownership: dataset 8 has
256 synthetic reminder acknowledgements, of which 86 reference the owning
calendar/event correctly. Only those 86 enter the stored fixture. The manifest
records both counts and this reason; complete stored acknowledgements remain
in every full snapshot comparison. The subsequent preference normalizer must
leave the entire decoded general-workspace snapshot unchanged. The shared
performance dataset itself is not modified by this Agent fixture preparation.

The chat fixture has 32 conversations and 753 messages: one 512-message long
conversation, 30 short conversations with eight messages each, and one explicit
host-command request. The long transcript contains 128 synthetic read-only
query groups and fixed Unicode text. It contains no manufactured write receipt
or undo ownership. Knowledge and binary attachments are empty. Dates, IDs,
commands, paging limits and context limits are fixed in
`src/agent_performance_fixtures.dart`.

The first verification-only run writes a contract report. A timed run requires
that report through `SKED_AGENT_BENCHMARK_CONTRACT`. It verifies the complete
dataset manifest, all seven benchmark source file hashes, and each selected
case's result SHA-256. Every warm-up and measured observation must produce the
same full semantic result. Changing a benchmark or fixture requires new
verification; it cannot silently replace expectations during timed sampling.

Only declared volatile metadata is excluded from semantic hashes:

- Catalog `now` must remain a valid timestamp, then is omitted. All descriptions,
  parameters, tool ordering and page boundaries remain in the fixed hash. The
  verification report retains the complete normalized catalog for inspection.
- Bulk receipt completion time is absent from the fixed business-result hash.
  The fixed operation ID, generation, sequence, command digest and full business
  snapshot remain. The exact complete main snapshot, including the actual
  receipt and its timestamp, must match independent disk readback. Each raw
  physical readback hash and receipt time is retained with its observation.

Neither exclusion removes business records, user messages, result pages or
unknown outcomes. A failed assertion aborts the run and writes a failed report;
it cannot count toward a complete comparison. Failed reports retain completed
cases and all verified samples of the interrupted case. The failed observation
also retains returned timing, digest and expected digest when available; an
operation that never returned a sample has no invented timing or result.
Only a report marked `complete` can become a frozen verification contract.

## Isolation and memory scope

Each load/batch observation creates its own `Directory.systemTemp` root. The
main archive, native two-slot chat archive, native knowledge archive, school-site
store and legacy restore journal resolve only beneath that root. The benchmark
waits for Agent, selective-backup and session shutdown, then drains the main
repository before deleting its own directory. Cleanup also awaits these owners
when quiescence fails. It does not clear the system temporary root or retain test
data in the repository.

Credentials, device preferences, empty attachment storage, selective-restore
journal and backup staging use explicit memory owners. They cannot fall back
to user data paths. The notification mutation-lock boundary is scoped to this
test target. The provider always rejects model calls, and HTTP clients created
inside the benchmark zone reject request operations. The declared cases invoke
no socket or native web-view APIs. Accepted reports require zero HTTP and model
attempts.

Load and batch observations record whole-process `ProcessInfo.currentRss` before
and after the measured interval, the process-lifetime `maxRss`, relative
observation times and getter costs. RSS getters are outside the timed interval.
These endpoints include Flutter, VM/native allocations, the test framework,
retained fixtures and previous observations in the process. The lifetime peak
does not identify a peak within this operation. Negative RSS deltas are retained;
there is no forced GC, heap-size inference or exact attribution to one feature.

Each load observation constructs a new AppRuntime, but it runs in an already
started test process after fixture preparation. OS caches remain warm. It is not
a native process-cold startup, first raster, rendered Agent page or physical
input measurement. The enabled/unopened case seeds the flag directly: calling
the product's `setEnabled(true)` would itself initialize the Agent and describe
a different workload.

## Verification, then three independent processes

Use a fixed Flutter SDK and an otherwise idle machine. Coordinate with other
tasks before any verification, analysis, build or performance window. Complete
formatting, analysis and correctness checks before sampling. Record a clean
source SHA, or preserve the exact production overlay and describe it with
`SKED_BENCHMARK_SOURCE_NOTE`; the supplied SHA alone cannot identify local edits.

Run from the repository root in PowerShell. Keep reports in the newly created
system temporary directory:

```powershell
$agentPerfEvidence = Join-Path ([IO.Path]::GetTempPath()) ('sked-agent-perf-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $agentPerfEvidence | Out-Null
$agentPerfRevision = (git rev-parse HEAD).Trim()
flutter test --no-pub --concurrency=1 --timeout=none --reporter=expanded `
  benchmark/agent_performance_benchmark_test.dart `
  --dart-define=SKED_BENCHMARK_VERIFY_ONLY=true `
  --dart-define=SKED_BENCHMARK_LABEL=agent-contract `
  --dart-define=SKED_BENCHMARK_REVISION=$agentPerfRevision `
  --dart-define=SKED_BENCHMARK_OUTPUT_DIR=$agentPerfEvidence
if ($LASTEXITCODE -ne 0) { throw 'Agent protocol verification failed.' }
$agentPerfContract = Join-Path $agentPerfEvidence 'agent-host-agent-contract.json'
```

Verification performs one operation per case with zero warm-ups. Its elapsed
values are diagnostic only, its report is marked `verification-only`, and it
omits performance summaries. Inspect the fixture manifest, complete catalog,
eleven successful case contracts and zero network-attempt counts before using
it as the immutable comparison contract.

Only after an exclusive performance window has been agreed, run three fresh
processes against that unchanged contract:

```powershell
foreach ($agentPerfRepeat in 1..3) {
  flutter test --no-pub --concurrency=1 --timeout=none --reporter=expanded `
    benchmark/agent_performance_benchmark_test.dart `
    --dart-define=SKED_BENCHMARK_LABEL=agent-r$agentPerfRepeat `
    --dart-define=SKED_BENCHMARK_REVISION=$agentPerfRevision `
    --dart-define=SKED_BENCHMARK_OUTPUT_DIR=$agentPerfEvidence `
    --dart-define=SKED_AGENT_BENCHMARK_CONTRACT=$agentPerfContract
  if ($LASTEXITCODE -ne 0) { throw 'Agent performance run failed; retain its evidence.' }
}
```

Every case uses five warm-up batches and eleven measured batches, with one
complete declared workload per batch. Async traversal and disk sequences are
not calibrated to 250 ms, preserving fixed page/command counts. Reports retain
every observation, per-process median, median absolute deviation and minimum.
Compare the median of the three independent per-process medians. Do not add
absolute timing thresholds to CI or treat eleven within-process observations
as eleven independent starts.

`SKED_AGENT_BENCHMARK_CASES` accepts a comma-separated subset of the declared
names. For comparing the three loading states' RSS observations, run each state
alone in three fresh processes with the same all-case contract; this avoids
mixing different preceding case histories. Keep case order, fixture bytes,
SDK/engine, source instrumentation, Windows settings and background load fixed.
The existing before/after ABBAAB ordering can be used for two-source comparisons.
Keep Windows host JIT and emulator/device profile populations separate.

## Existing coverage and remaining platform work

| Requirement | Existing entry | Relationship to this target |
| --- | --- | --- |
| Fresh Windows process, first/ready/response raster and four timestamped RSS points | [STARTUP.md](STARTUP.md), `startup_main.dart`, `run_startup_windows.ps1` | Retains its native clock/window/lock proof. This target does not replace or extend its readiness contract. |
| Native in-process workspace/settings engine frame timing | [UI_PERFORMANCE.md](UI_PERFORMANCE.md), `integration_test/ui_performance_benchmark_test.dart` | Uses real FrameTiming. Adding an Agent open/long-history scroll journey and accepting it on Windows is a separate platform task. |
| Ordinary durable course/event saves, import/export/restore | [DATA_OPERATIONS.md](DATA_OPERATIONS.md) | Reuse the existing operation matrix rather than duplicating it as Agent work. |
| Eligible preference save coalescing | [README.md](README.md#durable-preference-write-batching) | Existing one/five-disjoint/five-same-field controls remain authoritative for that optimization. |
| Real provider tool behavior and new history/attachment/knowledge flows | Agent acceptance and explicit real-model synthetic scenarios | Functional evidence, independent of this fully offline host timing protocol. |

No physical device is required to prepare or verify this host target. Local and
emulator results must carry their actual platform labels. They do not establish
physical-device performance, native mobile API acceptance, notification delivery,
power-loss behavior or production model reliability.
