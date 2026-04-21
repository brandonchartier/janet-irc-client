(import ../irc-client :as irc)

(defn- parse [msg]
  (peg/match irc/message-grammar msg))

(defn- format [msg]
  (irc/message-format msg))

# ----------------------------------------------------------------
# Grammar tests — raw PEG output
# ----------------------------------------------------------------

# PING with trailing
(assert (deep= (parse "PING :server.example.com\r\n")
               @[:command "PING" :params @["server.example.com"]])
        "PING with trailing")

# PING without colon (some servers)
(assert (deep= (parse "PING server.example.com\r\n")
               @[:command "PING" :params @["server.example.com"]])
        "PING without colon")

# PRIVMSG with nick!user@host prefix
(assert (deep= (parse ":nick!user@host PRIVMSG #channel :hello world\r\n")
               @[:from "nick" :user "user" :host "host"
                 :command "PRIVMSG" :params @["#channel" "hello world"]])
        "PRIVMSG with full prefix")

# Server numeric reply (001 welcome)
(assert (deep= (parse ":server.example.com 001 mynick :Welcome to IRC\r\n")
               @[:prefix "server.example.com"
                 :command 1 :params @["mynick" "Welcome to IRC"]])
        "numeric 001 welcome")

# NAMES reply (353)
(assert (deep= (parse ":server 353 nick = #channel :user1 user2 user3\r\n")
               @[:prefix "server"
                 :command 353 :params @["nick" "=" "#channel" "user1 user2 user3"]])
        "numeric 353 NAMES reply")

# JOIN with channel
(assert (deep= (parse ":nick!user@host JOIN #channel\r\n")
               @[:from "nick" :user "user" :host "host"
                 :command "JOIN" :params @["#channel"]])
        "JOIN a channel")

# JOIN with trailing colon (some servers)
(assert (deep= (parse ":nick!user@host JOIN :#channel\r\n")
               @[:from "nick" :user "user" :host "host"
                 :command "JOIN" :params @["#channel"]])
        "JOIN with trailing colon")

# PART with reason
(assert (deep= (parse ":nick!user@host PART #channel :Goodbye\r\n")
               @[:from "nick" :user "user" :host "host"
                 :command "PART" :params @["#channel" "Goodbye"]])
        "PART with reason")

# QUIT with reason
(assert (deep= (parse ":nick!user@host QUIT :Leaving\r\n")
               @[:from "nick" :user "user" :host "host"
                 :command "QUIT" :params @["Leaving"]])
        "QUIT with reason")

# MODE with multiple params
(assert (deep= (parse ":nick!user@host MODE #channel +o othernick\r\n")
               @[:from "nick" :user "user" :host "host"
                 :command "MODE" :params @["#channel" "+o" "othernick"]])
        "MODE with multiple params")

# NICK change
(assert (deep= (parse ":oldnick!user@host NICK newnick\r\n")
               @[:from "oldnick" :user "user" :host "host"
                 :command "NICK" :params @["newnick"]])
        "NICK change")

# NOTICE
(assert (deep= (parse ":server NOTICE * :*** Looking up your hostname\r\n")
               @[:prefix "server"
                 :command "NOTICE" :params @["*" "*** Looking up your hostname"]])
        "NOTICE from server")

# KICK with reason
(assert (deep= (parse ":op!user@host KICK #channel baduser :Behave yourself\r\n")
               @[:from "op" :user "user" :host "host"
                 :command "KICK" :params @["#channel" "baduser" "Behave yourself"]])
        "KICK with reason")

# TOPIC
(assert (deep= (parse ":nick!user@host TOPIC #channel :New topic here\r\n")
               @[:from "nick" :user "user" :host "host"
                 :command "TOPIC" :params @["#channel" "New topic here"]])
        "TOPIC change")

# No params
(assert (deep= (parse ":nick!user@host AWAY\r\n")
               @[:from "nick" :user "user" :host "host"
                 :command "AWAY" :params @[]])
        "AWAY with no params")

# IRCv3 tags
(assert (deep= (parse "@time=2023-01-01T00:00:00Z :nick!user@host PRIVMSG #ch :hi\r\n")
               @[:tags "time=2023-01-01T00:00:00Z"
                 :from "nick" :user "user" :host "host"
                 :command "PRIVMSG" :params @["#ch" "hi"]])
        "IRCv3 tags")

# Trailing with colons in content
(assert (deep= (parse ":nick!user@host PRIVMSG #ch :link: https://example.com\r\n")
               @[:from "nick" :user "user" :host "host"
                 :command "PRIVMSG" :params @["#ch" "link: https://example.com"]])
        "trailing with colons in content")

# Empty trailing
(assert (deep= (parse ":nick!user@host PRIVMSG #ch :\r\n")
               @[:from "nick" :user "user" :host "host"
                 :command "PRIVMSG" :params @["#ch" ""]])
        "empty trailing")

# ----------------------------------------------------------------
# message-format tests — application-level output
# ----------------------------------------------------------------

(assert (deep= (format "PING :irc.example.com\r\n")
               [:ping "irc.example.com"])
        "format PING")

(assert (deep= (format "PING server\r\n")
               [:ping "server"])
        "format PING without colon")

(assert (deep= (format ":nick!user@host PRIVMSG #channel :hello world\r\n")
               [:priv "user@host" "nick" "#channel" "hello world"])
        "format PRIVMSG")

(assert (deep= (format (string ":nick!user@host PRIVMSG jobot :\x01VERSION\x01\r\n"))
               [:ctcp "user@host" "nick" "jobot" "\x01VERSION\x01"])
        "format CTCP VERSION")

# ----------------------------------------------------------------
# message-format tests — ERROR
# ----------------------------------------------------------------

(assert (deep= (format "ERROR :Closing Link: reason\r\n")
               [:error "Closing Link: reason"])
        "format ERROR")

# ----------------------------------------------------------------
# message-format tests — NOTICE
# ----------------------------------------------------------------

(assert (deep= (format ":nick!user@host NOTICE #channel :hello\r\n")
               [:notice "user@host" "nick" "#channel" "hello"])
        "format NOTICE from user")

(assert (deep= (format ":server.example.com NOTICE * :*** Looking up your hostname\r\n")
               [:notice "server.example.com" "server.example.com" "*" "*** Looking up your hostname"])
        "format NOTICE from server")

# ----------------------------------------------------------------
# message-format tests — JOIN / PART / QUIT
# ----------------------------------------------------------------

(assert (deep= (format ":nick!user@host JOIN #channel\r\n")
               [:join "user@host" "nick" "#channel"])
        "format JOIN")

(assert (deep= (format ":nick!user@host JOIN :#channel\r\n")
               [:join "user@host" "nick" "#channel"])
        "format JOIN with trailing colon")

(assert (deep= (format ":nick!user@host PART #channel\r\n")
               [:part "user@host" "nick" "#channel" nil])
        "format PART without reason")

(assert (deep= (format ":nick!user@host PART #channel :Goodbye\r\n")
               [:part "user@host" "nick" "#channel" "Goodbye"])
        "format PART with reason")

(assert (deep= (format ":nick!user@host QUIT :Leaving\r\n")
               [:quit "user@host" "nick" "Leaving"])
        "format QUIT with reason")

(assert (deep= (format ":nick!user@host QUIT\r\n")
               [:quit "user@host" "nick" nil])
        "format QUIT without reason")

# ----------------------------------------------------------------
# message-format tests — KICK
# ----------------------------------------------------------------

(assert (deep= (format ":op!user@host KICK #channel baduser :Behave\r\n")
               [:kick "user@host" "op" "#channel" "baduser" "Behave"])
        "format KICK with reason")

(assert (deep= (format ":op!user@host KICK #channel baduser\r\n")
               [:kick "user@host" "op" "#channel" "baduser" nil])
        "format KICK without reason")

# ----------------------------------------------------------------
# message-format tests — NICK / MODE
# ----------------------------------------------------------------

(assert (deep= (format ":oldnick!user@host NICK newnick\r\n")
               [:nick "user@host" "oldnick" "newnick"])
        "format NICK change")

(assert (deep= (format ":nick!user@host MODE #channel +o othernick\r\n")
               [:mode "user@host" "nick" "#channel" "+o" "othernick"])
        "format MODE from user")

(assert (deep= (format ":server MODE #channel +nt\r\n")
               [:mode "server" "server" "#channel" "+nt"])
        "format MODE from server")

# ----------------------------------------------------------------
# message-format tests — TOPIC / INVITE
# ----------------------------------------------------------------

(assert (deep= (format ":nick!user@host TOPIC #channel :New topic\r\n")
               [:topic "user@host" "nick" "#channel" "New topic"])
        "format TOPIC")

(assert (deep= (format ":nick!user@host INVITE target #channel\r\n")
               [:invite "user@host" "nick" "target" "#channel"])
        "format INVITE")

# ----------------------------------------------------------------
# message-format tests — server numerics
# ----------------------------------------------------------------

(assert (deep= (format ":server 001 nick :Welcome to IRC\r\n")
               [:numeric "server" 1 "nick" "Welcome to IRC"])
        "format numeric 001")

(assert (deep= (format ":server 353 nick = #channel :user1 user2\r\n")
               [:numeric "server" 353 "nick" "=" "#channel" "user1 user2"])
        "format numeric 353 NAMES")

(assert (deep= (format ":server 366 nick #channel :End of /NAMES list\r\n")
               [:numeric "server" 366 "nick" "#channel" "End of /NAMES list"])
        "format numeric 366")

(print "All tests passed.")
