use strict;
use warnings;
use utf8;

my $name = $ARGV[0];

print <<EOS;
addSbtPlugin("com.typesafe.sbt" % "sbt-native-packager" % "1.3.10")
EOS

