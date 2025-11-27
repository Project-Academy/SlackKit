### Installation

SlackKit is available via the [Swift Package Manager](https://developer.apple.com/documentation/swift_packages/adding_package_dependencies_to_your_app). Requires iOS 17.6+ or macOS Ventura and up.

```
https://github.com/Project-Academy/SlackKit
```

### Usage

#### Authorship
You can choose to set a 'global' default author of messages.
```swift
Slack.defaultAuthor = Bot(
    username: "MyFaveBot",
    icon_emoji: ":nerd_face:",
    token: "xoxb-my-bot-token"
)
```
This allows you 'set and forget' if all your app's messages will have the same author.
You can alternatively customise the author of any message when sending (see Sending Messages below).

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

#### Sending Messages
A message can be sent with a Channel ID string:
```swift
let channel = "C12345678ABCD"
try await message.send(to: channel)
```
You can customise authorship on a per-message basis:
```swift
let myBot = Bot(
    username: "MyCustomBot",
    icon_emoji: ":unicorn_face:",
    token: "xoxb-my-bot-token"
)
let response = try await message.send(from: myBot, to: channel)
let response2: MessageResponse = try await message.send(to: channel)
```

As seen above, sent messages return a (discardable) `MessageResponse` object, 
containing the message, timestamp, and channel. 
This is helpful for updating, deleting, or replying to messages.
```swift
print(response.channel) // "C12345678ABCD"
print(response.ts) // 1764216383.416729
```

#### Updating/Deleting Messages
There are static functions on `Message`, as well as instance functions on `MessageResponse` for update and delete operations. 
```swift
try await Message.update(messageAt: response.ts, in: response.channel, with: newMessage)
try await Message.delete(messageAt: response.ts, in: response.channel)

let newMessage = Message("Updated Message")
let newResponse = try await response.update(to: newMessage)
try await newResponse.delete()
```
Please note, that if you used a non-default author to send the message, you need to make sure your author has the authorisation to update/delete that message. 
