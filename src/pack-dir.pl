use strict;
use warnings;
use utf8;

sub escape_bash {
    my ($str) = @_;
    $str =~ s/'/'\\''/g;
    "'" . $str . "'";
}

sub is_binary {
    my ($src) = @_;

    my $is_binary = '';

    my $buf;
    my $buf2;

    open(my $fh, '<', $src) or die $!;
    while () {
        my $l = read($fh, $buf, 1024);
        if (!defined($l)) {
            die $!;
        }

        if ($l == 0) {
            if (defined($buf2) && $buf2 !~ /\n\z/) {
                $is_binary = 1;
            }
            last;
        }

        if ($buf =~ /[^\t\r\n\x20-\x7E\x80-\xFF]/) {
            $is_binary = 1;
            last;
        }

        $buf2 = $buf;
    }

    close($fh);

    $is_binary;
}

sub pack_file_zero {
    my ($file) = @_;

    print "touch " . escape_bash($file) . "\n";
}

sub pack_file_text {
    my ($file) = @_;

    print "cat << \\EOF | sed 's/^ //' > " . escape_bash($file) . "\n";
    open(my $fh, '<', $file) or die $!;
    while (my $line = <$fh>) {
        print " " . $line;
    }
    close($fh);
    print "EOF\n";
}

sub pack_file_binary {
    my ($file) = @_;

    print "cat << \\EOF | sed 's/^ //' | base64 -d > " . escape_bash($file) . "\n";

    my $PROCESS2_WRITER;
    my $PROCESS1_READER;
    pipe($PROCESS1_READER, $PROCESS2_WRITER);

    my $pid2 = fork;
    if (!defined($pid2)) {
        die $!;
    } elsif ($pid2 == 0) {
        close($PROCESS1_READER);

        open(my $fh, '<', $file) or die $!;
        open(STDIN, '<&=', fileno($fh)) or die $!;
        open(STDOUT, '>&=', fileno($PROCESS2_WRITER));
        exec("base64");
    }

    close($PROCESS2_WRITER);

    while (my $line = <$PROCESS1_READER>) {
        print " " . $line;
    }
    close($PROCESS1_READER);
    print "EOF\n";
}

sub pack_directory {
    my ($dir) = @_;

    if ($dir ne ".") {
        print "################################################################################\n";
        print "# $dir\n";
        print "################################################################################\n";
    }

    if (-f $dir) {
        if (-z $dir) {
            pack_file_zero($dir);
        } elsif (is_binary($dir)) {
            pack_file_binary($dir);
        } else {
            pack_file_text($dir);
        }
        if (-x $dir) {
            print "chmod +x " . escape_bash($dir) . "\n";
        }
        print "\n";
    } elsif (-d $dir) {
        if ($dir ne ".") {
            print "mkdir " . escape_bash($dir) . "\n";
        }

        my @files = ();
        opendir(my $dh, $dir) or die $!;
        while (my $file = readdir($dh)) {
            next if ($file eq "." || $file eq "..");
            push(@files, $file);
        }
        closedir($dh);

        @files = sort(@files);
        foreach my $f (@files) {
            pack_directory("$dir/$f");
        }
    } else {
        print "# unknown file type: $dir\n";
        print "\n";
    }
}

pack_directory(".");

