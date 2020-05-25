(import ./grammar)
(import ./queue)
(import ./write :prefix "" :export true)

(defn- format
  [message]
  (match (peg/match grammar/message message)
    [:command "PING" :trailing trailing]
    [:ping trailing]
    [:from from :prefix prefix :command "PRIVMSG" :to to :trailing trailing]
    [:priv prefix from to trailing]
    _ [:unparsed message]))

(defn- read
  [stream callback &opt acc]
  (when-let [message (net/read stream 1024)
             message-queue (queue/new)
             chunk (queue/split-and-add message-queue message acc)]
    (queue/read-until-end
      message-queue
      (comp (partial callback stream) format))
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
    (user stream username realname)
    (nick stream nickname)
    (each channel channels (join stream channel))
    (read stream callback)))
