(declare-project
  :name "irc-client"
  :description "An IRC client library"
  :author "Brandon Chartier"
  :license "MIT"
  :url "https://github.com/brandonchartier/janet-irc-client"
  :repo "git+https://github.com/brandonchartier/janet-irc-client.git"
  :dependencies ["https://github.com/brandonchartier/janet-queue"])

(declare-source
  :source ["irc-client.janet"])
