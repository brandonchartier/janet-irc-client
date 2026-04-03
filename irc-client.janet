(def message-grammar
  "Grammar for parsing IRC messages.
   https://datatracker.ietf.org/doc/html/rfc2812#section-2.3.1"
  (peg/compile
    ~{:crlf (* "\r" "\n")
      :nospcrlfcl (if-not (set "\0\r\n :") 1)
      :tags (* (constant :tags)
               "@"
               (<- (some :S)))
      :source (* ":"
                 (+ (* (constant :from)
                       (<- (some (if-not (set "!@ \r\n") 1)))
                       "!"
                       (constant :user)
                       (<- (some (if-not (set "@ \r\n") 1)))
                       "@"
                       (constant :host)
                       (<- (some :S)))
                    (* (constant :prefix)
                       (<- (some :S)))))
      :command (* (constant :command)
                  (<- (some (+ :a :d))))
      :trailing (* ":" (<- (any (if-not :crlf 1))))
      :middle (<- (* :nospcrlfcl (any (+ ":" :nospcrlfcl))))
      :params (* (constant :params)
                 (group (any (* " " (+ :trailing :middle)))))
      :main (* (any (* :tags (some " ")))
               (any (* :source (some " ")))
               :command
               (? :params)
               :crlf)}))

(defn- split-after
  "Splits a string into a head/tail pair,
   after the specified pattern."
  [str idx pattern]
  (let [len (length pattern)
        head (take (+ idx len) str)
        tail (drop (+ idx len) str)]
    [head tail]))

(defn- split-and-add
  "Splits bytes on newlines and adds them to a queue,
   returning any leftover bytes."
  [queue bytes &opt acc]
  (default acc "")
  (let [pat "\r\n"
        val (string acc bytes)
        idx (string/find pat val)]
    (if (nil? idx)
      val
      (let [[head tail] (split-after val idx pat)]
        (array/insert queue 0 head)
        (split-and-add queue tail)))))

(defn- read-until-end
  "Recursively reads a queue until empty,
   processing each item with a transform function."
  [queue f]
  (when-let [item (array/pop queue)]
    (f item)
    (read-until-end queue f)))

(defn- write
  "Writes a message to a stream, with a newline suffix,
   and sleeps for :delay seconds to avoid flooding."
  [stream message]
  (let [line (string message "\r\n")]
    (net/write stream line)
    (ev/sleep 0.5)))

(defn write-priv
  "Sends a message to a channel,
   responding to the user who sent the command.
   https://en.wikipedia.org/wiki/List_of_Internet_Relay_Chat_commands#PRIVMSG"
  [stream channel nickname message]
  (write stream (string/format "PRIVMSG %s :%s: %s"
                               channel
                               nickname
                               message)))

(defn write-msg
  "Convenience function for writing a PRIVMSG directly to a channel."
  [stream channel message]
  (write stream (string/format "PRIVMSG %s :%s"
                               channel
                               message)))

(defn write-user
  "Specifies the various names of the client.
   https://en.wikipedia.org/wiki/List_of_Internet_Relay_Chat_commands#USER"
  [stream username realname]
  (write stream (string/format "USER %s 0 * :%s"
                               username
                               realname)))

(defn write-nick
  "Changes the client's nickname.
   https://en.wikipedia.org/wiki/List_of_Internet_Relay_Chat_commands#NICK"
  [stream nickname]
  (write stream (string/format "NICK %s" nickname)))

(defn write-join
  "Joins an IRC channel.
   https://en.wikipedia.org/wiki/List_of_Internet_Relay_Chat_commands#JOIN"
  [stream channel]
  (write stream (string/format "JOIN %s" channel)))

(defn write-pong
  "Sends a PONG reply to the server to avoid disconnecting.
   https://en.wikipedia.org/wiki/List_of_Internet_Relay_Chat_commands#PONG"
  [stream message]
  (write stream (string/format "PONG %s" message)))

(defn message-format
  [message]
  (match (peg/match message-grammar message)
    [:command "PING" :params [trailing]]
    [:ping trailing]
    [:from from :user user :host host :command "PRIVMSG" :params [to trailing]]
    [:priv (string user "@" host) from to trailing]
    _ [:unparsed message]))

(defn- read
  [stream callback &opt acc]
  (when-let [message (net/read stream 1024)
             message-queue @[]
             chunk (split-and-add message-queue message acc)]
    (read-until-end
      message-queue
      (comp (partial callback stream) message-format))
    (read stream callback chunk)))

(defn connect
  [{:host host
    :port port
    :channels channels
    :nickname nickname
    :username username
    :realname realname}
   callback]
  (with [stream (net/connect host port)]
    (write-user stream username realname)
    (write-nick stream nickname)
    (each channel channels (write-join stream channel))
    (read stream callback)))
