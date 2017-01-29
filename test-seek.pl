#!/usr/bin/perl                                                                                                                                                

use strict;
use Socket;

# open «file.zim». For more information see internet «openzim.org»                                                                                             
print "Opening ZIM file $ARGV[0]\n";
use Fcntl;
use Fcntl 'SEEK_CUR';
use Fcntl 'SEEK_SET';
# O_LARGEFILE for > 4Gb files is included with sysopen() automatically                                                                                         
sysopen (FILE, $ARGV[0], O_RDONLY) || die "File not found.\n";

for (my $i=0; $i <= 50; $i++) {
    read(FILE, $_, 4) || print "read() failed!\n";
    my $b32 = unpack("I");
    print "Value at $i * 1 GB = $b32\n";
    
    seek(FILE, 0x40000000, SEEK_CUR) || print "seek() failed!\n";
}
