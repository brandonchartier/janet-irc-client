(import queue)

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
                  (+ (/ (<- (between 3 3 :d)) ,scan-number)
                     (<- (some :a))))
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
  [q bytes &opt acc]
  (default acc "")
  (let [pat "\r\n"
        val (string acc bytes)
        idx (string/find pat val)]
    (if (nil? idx)
      val
      (let [[head tail] (split-after val idx pat)]
        (queue/enqueue q head)
        (split-and-add q tail)))))

(defn- read-until-end
  "Recursively reads a queue until empty,
   processing each item with a transform function."
  [q f]
  (when (not (queue/empty? q))
    (f (queue/dequeue q))
    (read-until-end q f)))

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
  (if-let [r (peg/match message-grammar message)]
    (let [info (table ;r)
          nick (or (info :from) (info :prefix))
          prefix (if (info :user)
                   (string (info :user) "@" (info :host))
                   nick)
          params (or (info :params) @[])
          cmd (info :command)]
      (match [cmd ;params]
        ["PING" trailing] [:ping trailing]
        ["ERROR" trailing] [:error trailing]
        ["PRIVMSG" to trailing] [:priv prefix nick to trailing]
        ["NOTICE" to trailing] [:notice prefix nick to trailing]
        ["JOIN" channel] [:join prefix nick channel]
        ["PART" channel reason] [:part prefix nick channel reason]
        ["PART" channel] [:part prefix nick channel nil]
        ["QUIT" reason] [:quit prefix nick reason]
        ["QUIT"] [:quit prefix nick nil]
        ["KICK" ch target reason] [:kick prefix nick ch target reason]
        ["KICK" ch target] [:kick prefix nick ch target nil]
        ["NICK" newnick] [:nick prefix nick newnick]
        ["MODE" & rest] [:mode prefix nick ;rest]
        ["TOPIC" channel topic] [:topic prefix nick channel topic]
        ["INVITE" target channel] [:invite prefix nick target channel]
        [(num (number? num)) & rest] [:numeric nick num ;rest]
        _ [:unparsed message]))
    [:unparsed message]))

(defn- read
  [stream callback &opt acc]
  (when-let [message (net/read stream 1024)
             message-queue (queue/new)
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
