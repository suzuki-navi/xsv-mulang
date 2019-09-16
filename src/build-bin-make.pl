use strict;
use warnings;
use utf8;

my $name = $ARGV[0];

my $type1;
my $type2;
my $sources;
my $jdk_version;
my $sbt_version;
my $graalvm_version;
open(my $fh, '<', "src/$name.mulang.conf") or die $!;
while (my $line = <$fh>) {
    if ($line =~ /^\s*sbt-package\s*$/) {
        $type1 = "sbt-package";
        $type2 = "sbt-package";
    } elsif ($line =~ /^\s*sbt-fatjar\s*$/) {
        $type1 = "sbt-fatjar";
        $type2 = "sbt-fatjar";
    } elsif ($line =~ /^\s*sbt-nativeimage\s*$/) {
        $type1 = "sbt-fatjar";
        $type2 = "sbt-nativeimage";
    } elsif ($line =~ /^\s*sources\s*:\s*(.+)\s*$/) {
        $sources = $1;
    } elsif ($line =~ /^\s*jdk-version\s*:\s*(.+)\s*$/) {
        $jdk_version = $1;
    } elsif ($line =~ /^\s*sbt-version\s*:\s*(.+)\s*$/) {
        $sbt_version = $1;
    } elsif ($line =~ /^\s*graalvm-version\s*:\s*(.+)\s*$/) {
        $graalvm_version = $1;
    }
}
close($fh);

if (!defined($type1)) {
    die "src/$name.mulang.conf: type not found";
}

if ($type1 eq "sbt-package" || $type1 eq "sbt-fatjar") {

    if (!defined($jdk_version)) {
        die "src/$name.mulang.conf: jkd-version not found";
    }
    if (!defined($sbt_version)) {
        die "src/$name.mulang.conf: sbt-version not found";
    }
    if ($type2 eq "sbt-nativeimage" && !defined($graalvm_version)) {
        die "src/$name.mulang.conf: graalvm-version not found";
    }

    my $type1_devel = "sbt-devel";
    my $type2_devel = "sbt-devel";

    my @scalaSources = ();
    opendir(my $dh, "src") or die $!;
    while (my $file = readdir($dh)) {
        next unless ($file =~ /\.scala\z/);
        next if ($file =~ /\A[.#]/);

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

    die "any source files not found ($name $sources)" unless @scalaSources;

    # var/target にある不要なファイルを削除
    # ソースコードが減った場合、リネームされた場合に備えた処理
    my $rm_targets = ".dir " . join(" ", @scalaSources);
    my $rm_targets_single_flag = "";
    my $rm_targets_devel_flag = "";
    if ( -d "var/build-$name-single/sbt/src/main/java" ) {
        system("cd var/build-$name-single/sbt/src/main/java; bash $ENV{MULANG_SOURCE_DIR}/rm-targets.sh $rm_targets");
        if ($? != 0) {
            $rm_targets_single_flag = "FORCE";
        }
    }
    if ( -d "var/build-$name-devel/sbt/src/main/java" ) {
        system("cd var/build-$name-devel/sbt/src/main/java; bash $ENV{MULANG_SOURCE_DIR}/rm-targets.sh $rm_targets");
        if ($? != 0) {
            $rm_targets_devel_flag = "FORCE";
        }
    }

    my $scalaSources_single = "";
    my $scalaSources_devel = "";
    foreach my $s (@scalaSources) {
        $scalaSources_single .= " var/build-$name-single/sbt/src/main/java/$s";
        $scalaSources_devel .= " var/build-$name-devel/sbt/src/main/java/$s";
    }

    if ($type1 eq "sbt-package") {
        print <<EOS;
var/target-single/$name: var/build-$name-single/sbt/target/universal/$name-0.1.0-SNAPSHOT.zip
	rm -rf var/build-$name-single/sbt/target/universal/$name-0.1.0-SNAPSHOT 2>/dev/null
	cd var/build-$name-single/sbt/target/universal; unzip $name-0.1.0-SNAPSHOT.zip
	rm -rf var/target-single/.$name-bin
	mv var/build-$name-single/sbt/target/universal/$name-0.1.0-SNAPSHOT var/target-single/.$name-bin
	echo '#!/bin/bash' > var/target-single/$name.tmp
	echo '\$\$MULANG_SOURCE_DIR/.anylang --jdk=$jdk_version \$\$MULANG_SOURCE_DIR/.$name-bin/bin/$name "\$\$@"' >> var/target-single/$name.tmp
	chmod +x var/target-single/$name.tmp
	mv var/target-single/$name.tmp var/target-single/$name

var/build-$name-single/sbt/target/universal/$name-0.1.0-SNAPSHOT.zip: var/build-$name-single/sbt/build.sbt var/build-$name-single/sbt/project/plugins.sbt $scalaSources_single var/target-single/.anylang $rm_targets_single_flag
	cd var/build-$name-single/sbt; $ENV{MULANG_SOURCE_DIR}/.anylang --sbt=$sbt_version --jdk=$jdk_version sbt universal:packageBin
	touch var/build-$name-single/sbt/target/universal/$name-0.1.0-SNAPSHOT.zip

EOS
    } elsif ($type1 eq "sbt-fatjar") {
        if ($type2 eq "sbt-nativeimage") {
            print <<EOS;
var/target-single/$name: var/build-$name-single/sbt/target/scala-2.12/$name-assembly-0.1.0-SNAPSHOT.jar
	rm -rf var/target-single/.$name-bin
	cd var/build-$name-single; $ENV{MULANG_SOURCE_DIR}/.anylang --graalvm=$graalvm_version native-image -jar sbt/target/scala-2.12/$name-assembly-0.1.0-SNAPSHOT.jar --verbose
	mv var/build-$name-single/$name-assembly-0.1.0-SNAPSHOT var/target-single/$name

EOS
        } else {
            print <<EOS;
var/target-single/$name: var/build-$name-single/sbt/target/scala-2.12/$name-assembly-0.1.0-SNAPSHOT.jar
	rm -rf var/target-single/.$name-bin
	mkdir -p var/target-single/.$name-bin
	cp var/build-$name-single/sbt/target/scala-2.12/$name-assembly-0.1.0-SNAPSHOT.jar var/target-single/.$name-bin/$name.jar
	echo '#!/bin/bash' > var/target-single/$name.tmp
	echo '\$\$MULANG_SOURCE_DIR/.anylang --jdk=$jdk_version java -jar \$\$MULANG_SOURCE_DIR/.$name-bin/$name.jar "\$\$@"' >> var/target-single/$name.tmp
	chmod +x var/target-single/$name.tmp
	mv var/target-single/$name.tmp var/target-single/$name

EOS
        }

        print <<EOS;
var/build-$name-single/sbt/target/scala-2.12/$name-assembly-0.1.0-SNAPSHOT.jar: var/build-$name-single/sbt/build.sbt var/build-$name-single/sbt/project/plugins.sbt $scalaSources_single var/target-single/.anylang $rm_targets_single_flag
	cd var/build-$name-single/sbt; $ENV{MULANG_SOURCE_DIR}/.anylang --sbt=$sbt_version --jdk=$jdk_version sbt assembly
	touch var/build-$name-single/sbt/target/scala-2.12/$name-assembly-0.1.0-SNAPSHOT.jar

EOS
    } else {
        die;
    }

    print <<EOS;
var/target-devel/$name: var/build-$name-devel/sbt/target/universal/stage/bin/$name
	rm -rf var/target-devel/.$name-bin
	ln -s ../../var/build-$name-devel/sbt/target/universal/stage var/target-devel/.$name-bin
	echo '#!/bin/bash' > var/target-devel/$name.tmp
	echo '\$\$MULANG_SOURCE_DIR/.anylang --jdk=$jdk_version \$\$MULANG_SOURCE_DIR/.$name-bin/bin/$name "\$\$@"' >> var/target-devel/$name.tmp
	chmod +x var/target-devel/$name.tmp
	mv var/target-devel/$name.tmp var/target-devel/$name

var/build-$name-devel/sbt/target/universal/stage/bin/$name: var/build-$name-devel/sbt/build.sbt var/build-$name-devel/sbt/project/plugins.sbt $scalaSources_devel var/target-devel/.anylang $rm_targets_devel_flag
	cd var/build-$name-devel/sbt; $ENV{MULANG_SOURCE_DIR}/.anylang --sbt=$sbt_version --jdk=$jdk_version sbt stage
	touch var/build-$name-devel/sbt/target/universal/stage/bin/$name

EOS


    print <<EOS;
var/build-$name-single/sbt/build.sbt:
	mkdir -p var/build-$name-single/sbt
	perl $ENV{MULANG_SOURCE_DIR}/build-$type1-build.pl $name > var/build-$name-single/sbt/build.sbt

var/build-$name-single/sbt/project/plugins.sbt:
	mkdir -p var/build-$name-single/sbt/project
	perl $ENV{MULANG_SOURCE_DIR}/build-$type1-plugins.pl $name > var/build-$name-single/sbt/project/plugins.sbt

EOS

    print <<EOS;
var/build-$name-devel/sbt/build.sbt:
	mkdir -p var/build-$name-devel/sbt
	perl $ENV{MULANG_SOURCE_DIR}/build-$type1_devel-build.pl $name > var/build-$name-devel/sbt/build.sbt

var/build-$name-devel/sbt/project/plugins.sbt:
	mkdir -p var/build-$name-devel/sbt/project
	perl $ENV{MULANG_SOURCE_DIR}/build-$type1_devel-plugins.pl $name > var/build-$name-devel/sbt/project/plugins.sbt

EOS

    print <<EOS;
var/build-$name-single/sbt/src/main/java/.dir:
	mkdir -p var/build-$name-single/sbt/src/main/java
	touch var/build-$name-single/sbt/src/main/java/.dir

EOS

    print <<EOS;
var/build-$name-devel/sbt/src/main/java/.dir:
	mkdir -p var/build-$name-devel/sbt/src/main/java
	touch var/build-$name-devel/sbt/src/main/java/.dir

EOS

    foreach my $s (@scalaSources) {
        print <<EOS;
var/build-$name-single/sbt/src/main/java/$s: src/$s var/build-$name-single/sbt/src/main/java/.dir
	cp src/$s var/build-$name-single/sbt/src/main/java/$s

EOS
    }

    foreach my $s (@scalaSources) {
        print <<EOS;
var/build-$name-devel/sbt/src/main/java/$s: src/$s var/build-$name-devel/sbt/src/main/java/.dir
	cp src/$s var/build-$name-devel/sbt/src/main/java/$s

EOS
    }
}
