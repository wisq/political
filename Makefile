default:
	$(MAKE) -j4 all

all: weekly monthly

weekly: data/politics_tidy.html.gz compile tmp
	mix political "$<" weekly | tee tmp/weekly.csv

monthly: data/politics_tidy.html.gz compile tmp
	mix political "$<" monthly | tee tmp/monthly.csv

compile:
	mix compile

tmp:
	mkdir -vp tmp

data/%_tidy.html.gz: data/%.html.gz
	gzcat "$<" \
		| tidy -asxml -utf8 -numeric -wrap 99999 2> /dev/null \
		| gzip -9 > "$@"
