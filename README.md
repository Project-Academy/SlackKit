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

// Or you can create more complex messages using BlockKit:
let blocks: [Block] = [
    .header("This is a heading"),
    .divider,
    .section("This is a section")
]
let message2 = Message("Hello, world", blocks: blocks)
```

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
