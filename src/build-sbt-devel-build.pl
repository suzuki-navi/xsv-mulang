use strict;
use warnings;
use utf8;

my $name = $ARGV[0];

my $scalaVersion;
my $libraryDependencies = [];
open(my $fh, '<', "src/$name.mulang.conf") or die $!;
while (my $line = <$fh>) {
    if ($line =~ /^\s*scala-version\s*:\s*(.+)\s*$/) {
        $scalaVersion = $1;
    } elsif ($line =~ /^\s*library-dependencies\s*:\s*(.+)\s*$/) {
        push(@$libraryDependencies, $1);
    }
}
close($fh);

if (!defined($scalaVersion)) {
    die "scala-version not found";
}

print <<EOS;
name := "$name"

version := "0.1.0-SNAPSHOT"

scalaVersion := "$scalaVersion"
enablePlugins(JavaAppPackaging)

resolvers += "Restlet Repository" at "http://maven.restlet.org"

EOS

for my $lib (@$libraryDependencies) {
    print "libraryDependencies += $lib\n";
}
print "\n";

print <<EOS;
scalacOptions += "-deprecation"

retrieveManaged := true

EOS

