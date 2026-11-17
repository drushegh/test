# Claude API — messages, streaming, errors, model selection

Use the official SDK for the project language (`anthropic` /
`@anthropic-ai/sdk` / `Anthropic.SDK` etc.); raw HTTP only for shell
contexts or unsupported languages. Never mix the two in one codebase, and
never infer one language's binding names from another's.

## Messages essentials

```python
import anthropic

client = anthropic.Anthropic()  # reads ANTHROPIC_API_KEY
response = client.messages.create(
    model="claude-sonnet-5",
    max_tokens=1024,
    system="You are a precise extraction engine. Output only JSON.",
    messages=[{"role": "user", "content": user_text}],
)
text = "".join(b.text for b in response.content if b.type == "text")
```

- `system` is the operator channel — instructions, persona, rules. User
  data goes in `messages`, clearly delimited (XML tags work well).
- Content is a list of typed blocks (`text`, `tool_use`, `tool_result`,
  `thinking`, images, documents) — iterate by type, never assume
  `content[0]` is text.
- Always check `stop_reason`: `end_turn` (done), `max_tokens`
  (truncated — raise the limit or continue), `tool_use` (dispatch tools),
  `pause_turn` (server-side loop paused — resend as-is to resume),
  `refusal` (handle gracefully, don't retry-loop).
- Multi-turn = resend full history; the API is stateless.

## Model selection (September 2026 — re-verify via Models API)

| Tier | Alias | Use for |
|---|---|---|
| Fable 5.1 | `claude-fable-5-1` | Most demanding reasoning/agentic work (thinking always on; no prefill; forced `tool_choice` returns 400) |
| Opus 5.5 | `claude-opus-5-5` | Newest Opus — thinking can't be disabled, effort defaults to `medium`, forced `tool_choice` returns 400 |
| Opus 5 | `claude-opus-5` | Long-horizon agents, complex knowledge work (thinking on by default — see `opus-5-calibration`) |
| Sonnet 5 | `claude-sonnet-5` | Default workhorse — speed/intelligence balance |
| Haiku 4.5 | `claude-haiku-4-5` | Classification, extraction, sub-agents, high volume |

Previous generation, still served: Fable 5 (`claude-fable-5`), Opus 4.8
(`claude-opus-4-8`), Sonnet 4.6 (`claude-sonnet-4-6`). Assistant prefill
returns 400 on everything above except Haiku 4.5.

Pick the smallest model that passes your evals; capability questions are
answered live, not from memory:

```python
m = client.models.retrieve("claude-opus-5")
m.max_input_tokens, m.max_tokens   # context window, max output
m.capabilities["thinking"]["types"]["adaptive"]["supported"]
```

Recent Opus-tier/Fable/Sonnet 5 models use adaptive thinking
(`thinking: {"type": "adaptive"}`) and `output_config.effort` instead of
manual budgets/sampling knobs (`budget_tokens` and sampling params return
400 there); older models differ — check before porting
parameters across model generations. Pin exact model aliases in config,
not scattered through code; migrations then become one change + eval run.

## Streaming

Default to streaming whenever input or output may be long — it avoids
request timeouts and enables progressive UX:

```python
with client.messages.stream(
    model="claude-sonnet-5", max_tokens=8000,
    messages=[{"role": "user", "content": prompt}],
) as stream:
    for text in stream.text_stream:
        emit(text)
final = stream.get_final_message()   # complete Message when you need it
```

## Errors and retries

| Status | Meaning | Action |
|---|---|---|
| 400 | Invalid request (bad model ID, malformed blocks, unsupported param) | Fix — never retry |
| 401/403 | Auth/permissions | Fix credentials |
| 413 | Request too large | Reduce content |
| 429 | Rate limit | Backoff using `retry-after`; respect token-bucket headers |
| 500/529 | Server error / overloaded | Bounded exponential backoff with jitter |

The SDKs retry transient errors automatically (configurable
`max_retries`); add an application-level circuit breaker for sustained
429/529 rather than hammering. Log `request_id` from responses/errors for
support escalation.

## Structured output

Prefer mechanisms that *enforce* shape over prose instructions: structured
outputs (`output_config.format`, or `client.messages.parse()`) first. The
older trick — a tool whose input schema is your output, forced with
`tool_choice: {"type": "tool", "name": ...}` — returns **400** on the
newest models (Fable 5.1, Opus 5.5: forced `any`/`tool` is unsupported);
there, use `tool_choice: {"type": "auto"}` + an instruction naming the tool
+ `strict: true` on the tool, or just structured outputs. Validate
regardless; on
failure, re-prompt once with the validation error appended, then fail
visibly. "Respond only with JSON" plus `json.loads` and a prayer is not a
contract.

## Batch API

Non-interactive workloads (nightly classification, eval runs, backfills):
50% of standard token price, results within 24 h (usually much faster).
Submit a JSON `requests` array via `messages.batches.create` — each item
is `{custom_id, params}` where `params` is an ordinary Messages request;
poll `processing_status` until `ended`, then stream results (served as
JSONL — one line per request, in **any order**; key by `custom_id` and
branch on `result.type`: `succeeded`/`errored`/`canceled`/`expired`). Combine with caching only deliberately — batch requests don't
share timing-dependent cache hits the way a hot interactive path does.

## Operational hygiene

- Token usage is on every response (`usage.input_tokens`,
  `output_tokens`, cache read/write fields) — record it per feature, per
  template version. Count tokens ahead with `messages.count_tokens` when
  budgeting.
- Date-stamp and centralise any hard-coded model facts; models deprecate
  on a schedule (e.g. Opus 4.1 retires Aug 2026).
