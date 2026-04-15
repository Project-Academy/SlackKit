## What works well

**Endpoint pattern.** The `private enum Chat: String, Endpoints` pattern is clean — each API group gets its own enum, raw values map directly to Slack method names, and `path` computes the URL from `"chat.\(rawValue)"`. It's compact and hard to get wrong.

**Request builder chain.** The fluent `.message(self).from(author).to(channel).response()` reads naturally and maps 1:1 to what you're actually doing. The modifier pattern on `Request` is consistent.

**Authorship fallback in `preProcess`.** Checking `Authorization` header before applying `defaultAuthor` is a sensible default-with-override pattern.

**Block builders.** `.divider`, `.header("...")`, `.section("...")` as static constructors are a nice API for the consumer — they hide the raw type strings.

**Scoped response types.** Defining `struct Response: Decodable` locally inside each API method keeps the namespace clean and makes each call self-documenting.

---

## Bugs

**1. `postProcess` guard logic is inverted** (`Slack.swift:43`)
```swift
guard statusCode != 200
else { return response }
```
This reads: "if the status code IS 200, return early." That means for every non-200 response, you fall through, print the code, and return the response anyway without throwing. The error handling block below it is effectively a logging pass — it never rejects anything. If a request returns 401 or 500, the caller gets a response back as if it succeeded and the error only surfaces when the caller tries to decode it. Either you want to throw on non-200, or you want the `ok` field checks in each call site to be the sole error path. Right now it's an awkward middle ground.

**2. `Message.delete` takes a `Channel` but `Message.update` takes a `String`** (`Chat.swift:43 vs :56`)
```swift
static func update(messageAt ts: String, in channel: String, ...) // String
static func delete(messageAt ts: String, in channel: Channel, ...) // Channel
```
The README shows `Message.delete(messageAt: response.ts, in: response.channel)` — `response.channel` is a `Channel`, so that works. But `update` takes a raw string, so you can't do `Message.update(messageAt: ts, in: response.channel, ...)` without `.id`. Inconsistent API surface.

**3. `Message.update` doesn't pass an author** (`Chat.swift:43-54`)
The static `update` function never calls `.from(author)`. If your default author is nil and no auth header is set, the request goes out unauthenticated. The instance method `MessageResponse.update` has the same gap — it accepts an `author` parameter but never uses it.

**4. `MessageResponse.delete` returns `self` even though the message is gone** (`Chat.swift:121-134`)
It creates a new `MessageResponse` from the delete response, wrapping the original message. The return type and `@discardableResult` suggest the caller might chain off this, but the message no longer exists. Confusing contract.

**5. `addReaction` error logic is inverted** (`Reactions.swift:37-40`)
```swift
guard let error = response.error,
      error != "already_reacted"
else { return }
throw SlackError.Reactions(resp.JSON)
```
The `guard let error` means a missing `error` field returns successfully even if `ok` is `false` — `ok` is never checked. Same issue in `removeReaction`.

**6. `kick` silently discards the response** (`Conversations.swift:175-185`)
No error checking at all. If the kick fails (user not in channel, insufficient permissions), the caller gets no indication.

---

## Design issues

**`SlackError` uses `Any?` associated values.**
This throws away type safety. The caller has to `as?` cast to figure out what went wrong. Every call site passes either `resp.JSON` (a dictionary) or `resp.JSON["error"] as? String` — inconsistently. A `String` error code (or a decoded error struct) would be far more useful.

**`Message` has two concerns jammed together.** The struct serves as both a compose model (text, blocks, thread) and a received model (ts, user, bot_id, subtype, edited, permalink...). The public init forces you to nil out 12 fields that only exist on received messages. The internal init is a 17-parameter monster. This is why you need the `json` computed property for sending — `Codable` would encode all the receive-only fields too. Splitting into a "compose" type and a "received" type (or using `Codable` properly with encoding strategies) would clean this up.

**Manual JSON serialization alongside `Codable`.** `Message`, `Block`, and `Text` all conform to `Codable` but also have hand-written `var json` properties that produce `[String: Sendable]` dictionaries. Two parallel serialization paths that can drift apart.

**`Bot` vs `UserAuthor` are structurally identical.** Both have the exact same stored properties. A single `Author` struct with a `kind` enum, or just removing `UserAuthor` entirely, would be simpler.

**`ProfileSchema` is orphaned in `Reactions.swift`.** It has nothing to do with reactions — looks like it was dropped there during development and never moved or wired up.

**`ProfileResponse` is orphaned in `Field.swift`.** Declared but never used.

**`Array where Element == Message` description** (`Conversations.swift:194-204`) — force-unwraps `self.last!` and shadows the stdlib `description` on `Array` in a way that only applies when the element is `Message`. Fragile.

---

## Minor nits

- `ChannelType` uses emoji raw values (`"🔒"`, `"💬"`) — works, but could garble in systems that don't handle Unicode well.
- `Block+Desc.swift:17-18` force-unwraps `text!` for header/section blocks. If a block is decoded from JSON with a missing `text` field, this crashes.
- The `Reactions` enum has `public` access on its `path` and `base` despite being `private` — no harm, just inconsistent with `Chat` and `Users`.
- `Emoji.swift` declares the endpoint enum but has no actual API methods.
