# Janet IRC Client

An IRC client library for Janet.

`jpm install https://github.com/brandonchartier/janet-irc-client`

---

```janet
(import irc-client :as irc)

(defn read-message [stream message]
  (match message
    [:ping pong]           (irc/write-pong stream pong)
    [:priv _ from to msg]  (print from " in " to ": " msg)
    [:join _ nick channel] (print nick " joined " channel)
    [:quit _ nick reason]  (print nick " quit: " reason)
    [:notice _ _ _ msg]    (print "notice: " msg)
    [:numeric _ code & rest] (printf "numeric %d: %s" code (string/join rest " "))))

(irc/connect
  {:host "irc.example.com"
   :port "6667"
   :channels ["#some-channel"]
   :nickname "my_nickname"
   :username "my_username"
   :realname "my_realname"}
  read-message)
```

## License

GPL-3.0
