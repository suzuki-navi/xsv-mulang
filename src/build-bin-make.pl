use strict;
use warnings;
use utf8;

my $name = $ARGV[0];

my $type;
my $jdk_version;
my $sbt_version;
open(my $fh, '<', "src/$name.mulang.conf") or die $!;
while (my $line = <$fh>) {
    if ($line =~ /^sbt\s*$/) {
        $type = "sbt";
    } elsif ($line =~ /^jdk-version\s*:\s*(.+)\s*$/) {
        $jdk_version = $1;
    } elsif ($line =~ /^sbt-version\s*:\s*(.+)\s*$/) {
        $sbt_version = $1;
    }
}
close($fh);

if (!defined($type)) {
    die "src/$name.mulang.conf: type not found";
}
if (!defined($jdk_version)) {
    die "src/$name.mulang.conf: jkd-version not found";
}
if (!defined($sbt_version)) {
    die "src/$name.mulang.conf: sbt-version not found";
}



if ($type eq "sbt") {

    my @scalaSources = ();
    opendir(my $dh, "src") or die $!;
    while (my $file = readdir($dh)) {
        next unless ($file =~ /\.scala\z/);

        open(my $fh, '<', "src/$file") or die $!;
        while (my $line = <$fh>) {
            if ($line =~ /^\/\/\s*mulang-name\s*:\s*(.+)$/) {
                my $confName = $1;
                if ($confName eq $name) {
                    push(@scalaSources, $file);
                }
                last;
            }
        }
        close($fh);
    }
    closedir($dh);

    my $scalaSources2 = "";
    foreach my $s (@scalaSources) {
        $scalaSources2 .= " var/build-$name/sbt/src/main/java/$s";
    }

    print <<EOS;
var/target/$name: var/build-$name/sbt/target/universal/$name-0.1.0-SNAPSHOT.zip
	rm -rf var/build-$name/sbt/target/universal/$name-0.1.0-SNAPSHOT 2>/dev/null
	cd var/build-$name/sbt/target/universal; unzip $name-0.1.0-SNAPSHOT.zip
	rm -rf var/target/$name-bin
	mv var/build-$name/sbt/target/universal/$name-0.1.0-SNAPSHOT var/target/.$name-bin
	echo '#!/bin/bash' > var/target/$name.tmp
	echo '\$\$MULANG_SOURCE_DIR/.anylang --sbt=$sbt_version --jdk=$jdk_version \$\$MULANG_SOURCE_DIR/.$name-bin/bin/$name "\$\$@"' >> var/target/$name.tmp
	chmod +x var/target/$name.tmp
	mv var/target/$name.tmp var/target/$name

var/build-$name/sbt/target/universal/$name-0.1.0-SNAPSHOT.zip: var/build-$name/sbt/build.sbt var/build-$name/sbt/project/plugins.sbt $scalaSources2 var/target/.anylang
	cd var/build-$name/sbt; $ENV{MULANG_SOURCE_DIR}/.anylang --sbt=$sbt_version --jdk=$jdk_version sbt compile
	cd var/build-$name/sbt; $ENV{MULANG_SOURCE_DIR}/.anylang --sbt=$sbt_version --jdk=$jdk_version sbt universal:packageBin

var/build-$name/sbt/build.sbt:
	mkdir -p var/build-$name/sbt
	perl $ENV{MULANG_SOURCE_DIR}/build-sbt-build.pl $name > var/build-$name/sbt/build.sbt

var/build-$name/sbt/project/plugins.sbt:
	mkdir -p var/build-$name/sbt/project
	perl $ENV{MULANG_SOURCE_DIR}/build-sbt-plugins.pl $name > var/build-$name/sbt/project/plugins.sbt

var/build-$name/sbt/src/main/java/.empty:
	mkdir -p var/build-$name/sbt/src/main/java
	touch var/build-$name/sbt/src/main/java/.empty

EOS

    foreach my $s (@scalaSources) {
        print <<EOS;
var/build-$name/sbt/src/main/java/$s: src/$s var/build-$name/sbt/src/main/java/.empty
	cp src/$s var/build-$name/sbt/src/main/java/$s

EOS
    }
}
