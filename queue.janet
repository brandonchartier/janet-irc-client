(import queue :prefix "" :export true)

(defn- split-after
  "Splits a string into a head/tail pair,
   after the specified pattern."
  [str idx pattern]
  (let [len (length pattern)
        head (take (+ idx len) str)
        tail (drop (+ idx len) str)]
    [head tail]))

(defn split-and-add
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
        (enqueue queue head)
        (split-and-add queue tail)))))

(defn read-until-end
  "Recursively reads a queue until empty,
   processing each item with a transform function."
  [queue f]
  (when-let [item (dequeue queue)]
    (f item)
    (read-until-end queue f)))
