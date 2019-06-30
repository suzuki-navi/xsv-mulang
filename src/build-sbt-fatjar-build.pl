use strict;
use warnings;
use utf8;

my $name = $ARGV[0];

my $scalaVersion;
open(my $fh, '<', "src/$name.mulang.conf") or die $!;
while (my $line = <$fh>) {
    if ($line =~ /^\s*scala-version\s*:\s*(.+)\s*$/) {
        $scalaVersion = $1;
    }
}
close($fh);

if (!defined($scalaVersion)) {
    die "scala-version not found";
}

print <<EOS;
name := "$name"

scalaVersion := "$scalaVersion"

resolvers += "Restlet Repository" at "http://maven.restlet.org"

libraryDependencies ++= Seq(
)

scalacOptions += "-deprecation"

EOS

