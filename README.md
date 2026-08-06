### Installation

SlackKit is available via the [Swift Package Manager](https://developer.apple.com/documentation/swift_packages/adding_package_dependencies_to_your_app). Requires iOS 17.6+ or macOS Ventura and up.

```
https://github.com/Project-Academy/SlackKit
```

Two products, split by **principal** — who the call acts as:

| Product | Acts as | Lifetime |
|---|---|---|
| `Slack` | the signed-in user, or your bot | permanent |
| `SlackOrg` | the organisation (a bot credential) | the departure lounge — moving server-side |

An `import SlackOrg` marks a file as holding org-principal call sites. That's deliberate: it's the migration checklist for when these capabilities move behind trusted server endpoints.

### Usage

#### Authorship

`Author` is one type with two intents:

```swift
let bot  = Author.bot(token: "xoxb-…", username: "MyFaveBot", iconEmoji: ":nerd_face:")
let user = Author.user(token: "xoxp-…")
```

The token decides the principal; `username` / `iconEmoji` / `iconURL` customise how a **bot** post is presented and are ignored by Slack on a user token.

You can set a default for calls that don't name one:

```swift
Slack.defaultAuthor = bot
```

This is resolved at the call site, not injected invisibly during request building — so "which principal posted this?" is answerable by reading the code. A call that reaches Slack with no author at all gets `not_authed`; it will not quietly borrow whatever credential was set last.

#### Composing Messages

```swift
// A basic message can be constructed from just a String:
let message1 = Message("Hello, world")

// Or you can create more complex messages using Block Kit:
let blocks: [Block] = [
    .header("This is a heading"),
    .divider,
    .section("This is a section"),
    .card(.init(
        title: "*Upcoming tute*",
        body: "Chemistry, Thursday 4pm",
        slackIcon: .init("calendar"),
        actions: [.button(.init(text: .init(plain: "Book Out"), action_id: "book_out", style: .danger))]
    )),
    .dataVisualization(title: "Marks by course", chart: .pie(segments: [
        .init("Chemistry", value: 60),
        .init("Physics", value: 40),
    ])),
]
let message2 = Message("Hello, world", blocks: blocks)
```

#### Block Kit coverage

Every current Slack block type has a typed model and (where Slack allows posting it) a builder:

| Kind | Blocks |
|---|---|
| Text & layout | `header` (with `level`), `section` (with `accessory` + `expand`), `context` (mixed text/images), `divider`, `rich_text`, `markdown` |
| Media | `image`, `video`, `file` (decode-only — Slack doesn't accept direct posts) |
| Data | `data_visualization` (pie/bar/area/line), `table`, `data_table` |
| Cards | `card`, `carousel`, `callout`, `contact_card` |
| Agent tasks | `plan`, `task_card`, `context_actions` |
| Interactive | `actions`, `input`, `alert` (modals-only) |

Interactive elements (`Block.ActionElement`) cover buttons (incl. `workflow_button`), every select and multi-select variant, overflow, date/time/datetime pickers, checkboxes, radio buttons, all text/number/email/URL/file inputs, feedback and icon buttons, and the image element — usable in `actions` blocks, section accessories, `input` blocks and `context_actions`. Composition objects (`Confirm`, `Option`, `OptionGroup`, `Filter`, `DispatchActionConfig`, `SlackFile`, `Workflow`/`Trigger`, `SlackIcon`) are all modelled.

Surface availability and Slack's size limits are documented on each builder. Field-level truth lives in `docs/systems/comms/blockkit-spec-2026-08.md` (docs tree).

**Tolerance guarantee:** anything Slack ships that this kit doesn't model — a new block type, a new *field* on a type we do model, an element type, chart kind, table cell, or style string — decodes without throwing and re-encodes verbatim. Relaying never strips content the kit hasn't learned, at any level of the tree. (`callout` and `contact_card` were found this way: undocumented in Slack's reference, discovered in a live Block Kit Builder payload, and now modelled.)

Posting a block with interactive elements is one half of the story: the interaction *payload* (a button press) arrives at the Slack app's request URL, which is server-side territory — this kit composes and posts, it does not receive.

`Message` composes; `ReceivedMessage` is what Slack sends back. They're separate types because they're separate jobs — a received message carries `ts`, `user`, `bot_id`, `subtype` and so on, none of which mean anything on the way out. To repost received content, ask for it explicitly:

```swift
let reply = received.recomposed(inThread: true)
```

#### Sending Messages

```swift
let channel = "C12345678ABCD"
try await message.send(to: channel)
```

Per-message authorship:

```swift
let response = try await message.send(from: myBot, to: channel)
```

Sends return a (discardable) `MessageResponse` receipt — the `ts` + `channel` pair Slack needs to address the message again, plus its echo of what was posted.

```swift
print(response.channel)  // "C12345678ABCD"
print(response.ts)       // 1764216383.416729
print(response.message?.plainText)
```

#### Updating/Deleting Messages

Instance functions on `MessageResponse` for messages you hold a receipt for; static functions on `Message` (in `SlackOrg`) for addressing a message by `ts` + channel.

```swift
let newMessage = Message("Updated Message")
let newResponse = try await response.update(to: newMessage)
try await newResponse.delete()

try await Message.update(messageAt: response.ts, in: response.channel, with: newMessage)
try await Message.delete(messageAt: response.ts, in: response.channel)
```

If you sent the message as a non-default author, pass that same author — `chat.update` and `chat.delete` only succeed as the identity that posted.

#### Reactions

```swift
try await response.addReaction("white_check_mark")
try await response.removeReaction("white_check_mark")
let reactions = try await response.getReactions()   // [] when there are none
```

`already_reacted` and `no_reaction` are treated as success: they describe the state the caller asked for.

### Errors

Every failure is a `SlackError`, in one of three kinds — because they call for different handling:

```swift
do {
    try await message.send(to: channel)
} catch SlackError.refused(_, .missingScope) {
    // Slack answered and said no. Won't succeed on retry.
} catch let SlackError.refused(_, code) {
    // Some other Slack code — `code.rawValue` is Slack's own string.
} catch let error as SlackError where error.isRetryable {
    // Never reached a verdict (429 / 5xx). Safe to re-issue.
}
```

| Case | Meaning | Retry? |
|---|---|---|
| `.refused(method:code:)` | Slack answered and refused | only `.rateLimited` |
| `.unreadable(method:detail:)` | Slack said ok, body wasn't what we expect — **the operation probably happened** | no |
| `.transport(method:status:retryAfter:)` | no Slack verdict (HTTP failure) | yes |

`errorDescription` is safe to show a person: it names the method and the code, and deliberately excludes the response body, which carries `needed`/`provided` OAuth scope lists.

Retries are automatic and bounded, honouring Slack's `Retry-After`. Writes are re-issued only for failures Slack certainly never processed; idempotent calls also retry dropped connections.

### Diagnostics

The kit never prints. Warnings, partial invite failures, and truncated paged reads go to a hook you supply:

```swift
Slack.diagnostics = { message in Scribe.report(message) }
```

### Reading the workspace (`SlackOrg`)

```swift
let channels = try await Channel.list(as: bot)                 // all pages
let members  = try await Member.list(as: bot)                  // all pages
let history  = try await channel.history(maxMessages: 500, as: bot)
```

Listing calls follow Slack's cursor to the end. Where a ceiling applies (`maxMessages`), hitting it is reported through `Slack.diagnostics` — a bounded read never silently looks like a complete one.
