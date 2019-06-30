use strict;
use warnings;
use utf8;

my $name = $ARGV[0];

print <<EOS;
addSbtPlugin("com.eed3si9n" % "sbt-assembly" % "0.14.9")
EOS

