# Janet IRC Client

An IRC client library for Janet.

`jpm install https://github.com/brandonchartier/janet-irc-client`

---

```janet
(import irc-client :as irc)

(defn on-message [writer message]
  (match message
    [:priv _ from to msg]
    (irc/write-msg writer to (string from ": " msg))
    [:join _ nick channel]
    (print nick " joined " channel)
    [:quit _ nick reason]
    (print nick " quit: " reason)))

(irc/connect
  {:host "irc.example.com"
   :port "6667"
   :channels ["#some-channel"]
   :nickname "my_bot"
   :username "my_bot"
   :realname "my_bot"}
  on-message)
```

## API

### `(connect config callback)`

Connects to an IRC server and blocks until the connection closes. `callback` is
called for every message as `(fn [writer message] ...)`. PING/PONG and initial
channel joins are handled internally; the callback still receives those events
if needed.

`config` keys:

| Key | Required | Description |
|-----|----------|-------------|
| `:host` | yes | IRC server hostname |
| `:port` | yes | IRC server port |
| `:channels` | yes | Array of channels to join on connect |
| `:nickname` | yes | Bot nickname |
| `:username` | yes | IRC username |
| `:realname` | yes | IRC realname |

### Write functions

All write functions take a `writer` (received as the first argument in the
callback) and enqueue the message for sending. A 0.5s delay between writes is
enforced globally to avoid flooding.

### `(write-msg writer channel message)`

Sends a PRIVMSG to a channel.

### `(write-priv writer channel nickname message)`

Sends a PRIVMSG to a channel, prefixed with `nickname:`.

### `(write-nick writer nickname)`

Changes the bot's nickname.

### `(write-join writer channel)`

Joins a channel.

### `(write-pong writer message)`

Sends a PONG. Handled internally; only needed if you want to send a manual
PONG for some reason.

## Message events

The `message` argument in the callback is a tagged tuple. Common events:

| Pattern | Description |
|---------|-------------|
| `[:priv prefix nick to trailing]` | PRIVMSG; `to` is the channel or bot nick |
| `[:action prefix nick to text]` | CTCP ACTION (`/me`) |
| `[:notice prefix nick to trailing]` | NOTICE |
| `[:join prefix nick channel]` | User joined a channel |
| `[:part prefix nick channel reason]` | User left a channel |
| `[:quit prefix nick reason]` | User quit |
| `[:kick prefix nick channel target reason]` | User was kicked |
| `[:nick prefix nick newnick]` | User changed nickname |
| `[:topic prefix nick channel topic]` | Channel topic changed |
| `[:numeric nick code & rest]` | Numeric reply from server |
| `[:ping trailing]` | PING from server (handled internally) |
| `[:error trailing]` | ERROR from server |
| `[:unparsed message]` | Raw message that did not match the grammar |

`prefix` is `user@host` when available, otherwise the same as `nick`.

## Notes

The callback runs on the read loop fiber. Avoid blocking operations; use
`ev/go` for anything that might suspend, such as HTTP requests or database
writes, to keep the read loop live.

## License

GPL-3.0
