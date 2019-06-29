
build: mulang

test: FORCE mulang
	cd test/1; rm -rf var/build-* var/target var/out.sh
	cd test/1; ../../mulang
	./test/1/var/out.sh > test/1/var/result.txt
	diff -u test/1/etc/expected.txt test/1/var/result.txt
	echo OK

mulang: var/out.3.sh
	cp var/out.3.sh mulang

var/out.1.sh: FORCE
	./etc/mulang-last
	mv var/out.sh var/out.1.sh

var/out.2.sh: var/out.1.sh
	./var/out.1.sh
	mv var/out.sh var/out.2.sh

var/out.3.sh: var/out.2.sh
	./var/out.2.sh
	mv var/out.sh var/out.3.sh

FORCE:

