process: data/politics_tidy.html.gz
	mix political "$<"

data/%_tidy.html.gz: data/%.html.gz
	gzcat "$<" \
		| tidy -asxml -utf8 -numeric -wrap 99999 2> /dev/null \
		| gzip -9 > "$@"
