#!/usr/bin/perl

use strict;
use Socket;

print "Opening ZIM file $ARGV[0]\n";
use Fcntl;
use Fcntl 'SEEK_CUR';
use Fcntl 'SEEK_SET';

sub xsysread {
    my $result = sysread($_[0], $_[1], $_[2]);
    die "sysread() failed with mismatch result=$result and arg2=$_[2]", if ($result != $_[2]);
    return $result;
}

sub xsysseek {
    my $result = sysseek($_[0], $_[1], $_[2]);
    return $result;
}


# O_LARGEFILE for > 4Gb files is included with sysopen() automatically
sysopen (FILE, $ARGV[0], O_RDONLY) || die "File not found.\n";

for (my $i=0; $i <= 50; $i++) {
    xsysread(\*FILE, $_, 4096*128) || print "read() failed!\n";
    my $b32 = unpack("I");
    print "Value at $i * 1 GB = $b32\n";
    
    xsysseek(\*FILE, 0x40000000, SEEK_CUR) || print "seek() failed!\n";
}
