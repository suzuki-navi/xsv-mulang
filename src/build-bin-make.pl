use strict;
use warnings;
use utf8;

my $name = $ARGV[0];

my $type;
my $sources;
my $jdk_version;
my $sbt_version;
open(my $fh, '<', "src/$name.mulang.conf") or die $!;
while (my $line = <$fh>) {
    if ($line =~ /^\s*sbt-package\s*$/) {
        $type = "sbt-package";
    } elsif ($line =~ /^\s*sbt-fatjar\s*$/) {
        $type = "sbt-fatjar";
    } elsif ($line =~ /^\s*sources\s*:\s*(.+)\s*$/) {
        $sources = $1;
    } elsif ($line =~ /^\s*jdk-version\s*:\s*(.+)\s*$/) {
        $jdk_version = $1;
    } elsif ($line =~ /^\s*sbt-version\s*:\s*(.+)\s*$/) {
        $sbt_version = $1;
    }
}
close($fh);

if (!defined($type)) {
    die "src/$name.mulang.conf: type not found";
}



if ($type eq "sbt-package" || $type eq "sbt-fatjar") {

    if (!defined($jdk_version)) {
        die "src/$name.mulang.conf: jkd-version not found";
    }
    if (!defined($sbt_version)) {
        die "src/$name.mulang.conf: sbt-version not found";
    }

    my @scalaSources = ();
    opendir(my $dh, "src") or die $!;
    while (my $file = readdir($dh)) {
        next unless ($file =~ /\.scala\z/);

        open(my $fh, '<', "src/$file") or die $!;
        while (my $line = <$fh>) {
            if ($line =~ /^\s*\/\/\s*mulang-bin-sources\s*:\s*(.+)\s*$/) {
                my $target = $1;
                if ($target eq $sources) {
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

    if ($type eq "sbt-package") {
        print <<EOS;
var/target/$name: var/build-$name/sbt/target/universal/$name-0.1.0-SNAPSHOT.zip
	rm -rf var/build-$name/sbt/target/universal/$name-0.1.0-SNAPSHOT 2>/dev/null
	cd var/build-$name/sbt/target/universal; unzip $name-0.1.0-SNAPSHOT.zip
	rm -rf var/target/$name-bin
	mv var/build-$name/sbt/target/universal/$name-0.1.0-SNAPSHOT var/target/.$name-bin
	echo '#!/bin/bash' > var/target/$name.tmp
	echo '\$\$MULANG_SOURCE_DIR/.anylang --jdk=$jdk_version \$\$MULANG_SOURCE_DIR/.$name-bin/bin/$name "\$\$@"' >> var/target/$name.tmp
	chmod +x var/target/$name.tmp
	mv var/target/$name.tmp var/target/$name

var/build-$name/sbt/target/universal/$name-0.1.0-SNAPSHOT.zip: var/build-$name/sbt/build.sbt var/build-$name/sbt/project/plugins.sbt $scalaSources2 var/target/.anylang
	#cd var/build-$name/sbt; $ENV{MULANG_SOURCE_DIR}/.anylang --sbt=$sbt_version --jdk=$jdk_version sbt compile
	cd var/build-$name/sbt; $ENV{MULANG_SOURCE_DIR}/.anylang --sbt=$sbt_version --jdk=$jdk_version sbt universal:packageBin

EOS
    } elsif ($type eq "sbt-fatjar") {
        print <<EOS;
var/target/$name: var/build-$name/sbt/build.sbt var/build-$name/sbt/project/plugins.sbt $scalaSources2 var/target/.anylang
	cd var/build-$name/sbt; $ENV{MULANG_SOURCE_DIR}/.anylang --sbt=$sbt_version --jdk=$jdk_version sbt assembly
	mkdir -p var/target/.$name-bin
	mv var/build-$name/sbt/target/scala-2.12/$name-assembly-0.1.0-SNAPSHOT.jar var/target/.$name-bin/$name.jar
	echo '#!/bin/bash' > var/target/$name.tmp
	echo '\$\$MULANG_SOURCE_DIR/.anylang --jdk=$jdk_version java -jar \$\$MULANG_SOURCE_DIR/.$name-bin/$name.jar "\$\$@"' >> var/target/$name.tmp
	chmod +x var/target/$name.tmp
	mv var/target/$name.tmp var/target/$name


EOS
    } else {
        die;
    }

    print <<EOS;
var/build-$name/sbt/build.sbt:
	mkdir -p var/build-$name/sbt
	perl $ENV{MULANG_SOURCE_DIR}/build-$type-build.pl $name > var/build-$name/sbt/build.sbt

var/build-$name/sbt/project/plugins.sbt:
	mkdir -p var/build-$name/sbt/project
	perl $ENV{MULANG_SOURCE_DIR}/build-$type-plugins.pl $name > var/build-$name/sbt/project/plugins.sbt

EOS

    print <<EOS;
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
