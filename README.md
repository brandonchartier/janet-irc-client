# Janet IRC Client

`jpm install https://github.com/brandonchartier/janet-irc-client`

---

```
(import irc-client :as irc)

(defn read-message [stream message]
  (match message
    [:ping pong]
    (irc/write-pong stream pong)))

(irc/connect
  {:host "irc.example.com"
   :port "6667"
   :channels ["#some-channel"]
   :nickname "my_nickname"
   :username "my_username"
   :realname "my_realname"}
  read-message)
```
