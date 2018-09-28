# Political

Just a quick project I threw together to analyse some Discord logs.

* Splits the data into buckets by date
* Categorises messages and embedded links into "topics" based on content
  * Messages may belong to more than one topic
  * Messages with no known topics are given the "other" topic
* Generates CSV with the total counts

Logs were extracted using [DiscordChatExporter](https://github.com/Tyrrrz/DiscordChatExporter).
