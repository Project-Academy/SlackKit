# SlackKit review log

Dated entries. Line references are only valid for the version they were written
against — check the date before trusting one.

---

## 2026-07-25 — adversarial audit → 2.2.0

Full read of both modules (2,293 lines), plus a probe harness that exercised the
models directly. The architecture held up; the failure-handling layer did not,
and the defects were systematic rather than incidental.

### Fixed in 2.2.0

**1. `ok` was decoded everywhere and read nowhere.** Twelve response structs
declared `let ok: Bool`; nothing in the package ever looked at it. Slack reports
failure as HTTP 200 with `{"ok": false, "error": …}`, so what actually caught an
error was whether a given `Decodable` happened to declare a field non-optional
that Slack omits on failure. Correctness was an accident of field optionality.
→ Every call now goes through `SlackEndpoint.read/write/readPages`, which check
`ok` **before** decoding the payload. There is no other way to fire a request.

**2. Two serialisers for one model, and they disagreed.** `Block.json` (the send
path) emitted only `type`, `text`, `fields`, `elements`, `block_id` — silently
dropping `richText` and `actions`, which `Block.encode(to:)` wrote correctly.
Relaying or editing a message containing either kind posted an empty block.
→ `Message.json` / `Block.json` / `Text.json` deleted. Outgoing bodies are typed
`Encodable` payloads (`Payloads.swift`) encoded by `JSONEncoder` over the models'
own conformances. One serialiser, no drift.

**3. `Message` was compose-model and received-model in one type** — the reason
the second serialiser existed at all (`Codable` would have written `ts`,
`bot_id`, `subtype` into a `chat.postMessage` body). → Split into `Message`
(`Encodable`, compose-only) and `ReceivedMessage` (`Decodable`), with
`recomposed(inThread:)` as the deliberate bridge between them.

**4. `ActionElement.encode` omitted the `type` discriminator.** It delegated
wholly to `Button`, which has no `type` field, so the kit emitted button
elements Slack rejects — and which the kit could not decode back
(`keyNotFound: "type"`). → `ActionElement` owns the discriminator.

**5. `Block.description` crashed on legal input.** Force-unwrapped `text!` for
section and header blocks; a section carrying only `fields` is legal Slack and
documented as such on `Block.text`. Confirmed live: `Fatal error: Unexpectedly
found nil`. Same shape in `Message+Desc` (`purpose!`, `subtype!`). → All
descriptions read optionally.

**6. Unknown shapes were silently rewritten.** An unrecognised `rich_text_*`
kind decoded to `.section([])` and re-encoded as an empty section — the content
deleted. `RichTextInline.other` re-encoded as an empty `text` node. → Both keep
their whole body via `JSONValue` and round-trip verbatim.

**7. `getReactions()` threw when a message had no reactions.** Slack omits the
key entirely in that case, which the guard read as failure. → Returns `[]`.

**8. `postProcess` never threw on non-200.** 401, 429 and 5xx all fell through
and returned the response as if it had succeeded; the error surfaced later as
whatever the payload decode happened to do. → Classifies HTTP failures as
`SlackError.transport`, with `Retry-After` parsed.

**9. No retry beyond reactions, and none for rate limits.** → `RetryPolicy`,
applied at the choke point. Writes retry only what Slack certainly never
processed (429/5xx); idempotent calls also retry transient `URLError`s. Bounded
attempts, `Retry-After` honoured and capped.

**10. No pagination anywhere.** `Channel.list`, `Member.list`, `history`,
`getReplies` all returned page one. `has_more` was decoded and ignored; no
cursor handling existed. A workspace bigger than a page reported as one page.
→ `readPages` follows `response_metadata.next_cursor` to the end. Where a
ceiling applies, hitting it is reported through `Slack.diagnostics`.

**11. `Moderation.kick` discarded its response** — a failed kick was
indistinguishable from a successful one. → Checked.

**12. `MessageResponse.init?` returned nil when Slack's echo lacked a `message`
object**, turning a successful post into a thrown error and inviting a retry
that would duplicate the message. → Non-failable; the receipt is `ts` +
`channel`, and `ok` has already been checked by then.

**13. The error type couldn't distinguish three different situations.**
`SlackError` had four cases keyed by API family, carrying a `String?` that was
sometimes the error code and sometimes the stringified whole body (19 of 20
throw sites). No caller could branch on a Slack code — the defect behind P198,
where Library's `already_in_channel` tolerance could never match and students'
questions were never posted. → `.refused(method:code:)` /
`.unreadable(method:detail:)` / `.transport(method:status:retryAfter:)`, with a
typed `Code` so `catch SlackError.refused(_, .alreadyInChannel)` is checked by
the compiler. `errorDescription` excludes the response body, which carries
`needed`/`provided` OAuth scope lists that were leaking into student-facing UI.

**14. Mutable global state.** `Slack.baseURL` was a `public static var` → now
`let`. `defaultAuthor` was injected invisibly in `preProcess`, undercutting the
explicit-principal design the module split exists to enforce → resolved at the
facade instead, where it's readable.

**15. Author threading was inconsistent.** `Member.getProfile()` and everything
in `Channels.swift` ignored the author they were given and used the global.
→ All privileged calls take `as author:`.

**16. Seven `print()` calls in library code.** → `Slack.diagnostics` hook; the
kit never prints.

**17. `Bot` and `UserAuthor` were structurally identical.** → One `Author`
struct with `.bot(token:…)` / `.user(token:)` factories.

**18. API inconsistency:** `update(in channel: String)` vs
`delete(in channel: Channel)`. → Both take `Channel`.

**19. `Array<Message>.description`** used `elem != self.last!` for separators
(wrong when an earlier element equals the last) and didn't shadow interpolation
anyway — `"\(array)"` went through the stdlib conformance regardless. → Removed.

**20. Zero tests.** → 33 tests in 7 suites, covering every defect above that can
be exercised without a network.

### Not done — deliberately

- **`Slack` is `@MainActor`**, inherited from Tapioca's protocol, so every
  request hops to the main actor. The facades are now explicitly `@MainActor`
  rather than hiding the hop. Removing it means changing Tapioca.
- **`conversations.list` `types` param** previously read
  `"public_channel, private_channel, mpim, im"` with spaces. Slack does not trim
  these, so the spaced entries were likely unmatchable — which would mean the
  call only ever returned public channels. Spaces removed, but the original
  behaviour was **not** verified against live Slack.

### Consumer impact

Breaking, by design. Affects Library (`AskForHelpVC.swift`), Dashboard
(4 files), Snippets (`SlackKitStatus.swift`).

---

## Pre-2026-07-25 (undated, written against the pre-restructure layout)

Kept for provenance. Line numbers refer to a layout that no longer exists.
Of its six listed bugs, three had been fixed before the audit (`SlackError`'s
`Any?` payload, `update` not passing an author, the orphaned `ProfileSchema` /
`ProfileResponse` / `Emoji.swift` declarations) and three survived into it
(`postProcess` inversion, `addReaction` never checking `ok`, `kick` discarding
its response) — all now closed above.

### What worked well

**Endpoint pattern.** Each API group gets its own enum, raw values map directly
to Slack method names, and `path` computes the URL. Compact and hard to get
wrong. *(Still true; `method` is now the single source of both URL and
diagnostics.)*

**Request builder chain.** The fluent modifier pattern reads naturally and maps
1:1 to what you're actually doing.

**Scoped response types.** Defining `struct Response: Decodable` locally inside
each API method keeps the namespace clean and makes each call self-documenting.

### Design issues raised then, resolved in 2.2.0

- `SlackError` used `Any?` associated values — no caller could branch safely.
- `Message` jammed compose and received concerns together.
- Manual JSON serialisation alongside `Codable` — "two parallel serialization
  paths that can drift apart." They did.
- `Bot` vs `UserAuthor` structurally identical.
- `Block+Desc` force-unwrapping `text!`.
- `Array where Element == Message` force-unwrapping `self.last!`.
- `ChannelType` emoji raw values — still emoji, still fine.
