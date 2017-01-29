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

sub xread {
    my $result = sysread($_[0], $_[1], $_[2]);
    die "sysread() failed with mismatch result=$result and arg2=$_[2]", if ($result != $_[2]);
    return $result;
}

sub xseek {
    my $result = sysseek($_[0], $_[1], $_[2]);
    return $result;
}

# read and load HEADER into «file.zim»
my %header;
xseek(\*FILE, 0, 0); # no necesary because it must be it
xread(\*FILE, $_, 4); $header{"magicNumber"} = unpack("c*"); # ZIM\x04
xread(\*FILE, $_, 4); $header{"version"} = unpack("I");
xread(\*FILE, $_, 16); $header{"uuid"} = unpack("H*");
xread(\*FILE, $_, 4); $header{"articleCount"} = unpack("I");
xread(\*FILE, $_, 4); $header{"clusterCount"} = unpack("I");

xread(\*FILE, $_, 4); $header{"urlPtrPos"} = unpack("I");     xread(\*FILE, $_, 4); $header{"zero1"} = unpack("I");
xread(\*FILE, $_, 4); $header{"titlePtrPos"} = unpack("I");   xread(\*FILE, $_, 4); $header{"zero2"} = unpack("I");
xread(\*FILE, $_, 4); $header{"clusterPtrPos"} = unpack("I"); xread(\*FILE, $_, 4); $header{"zero3"} = unpack("I");
xread(\*FILE, $_, 4); $header{"mimeListPos"} = unpack("I");   xread(\*FILE, $_, 4); $header{"zero4"} = unpack("I");
xread(\*FILE, $_, 4); $header{"mainPage"} = unpack("I");
xread(\*FILE, $_, 4); $header{"layoutPage"} = unpack("I");
xread(\*FILE, $_, 8); $header{"checksumPos"} = unpack("H*");

# Check that none of the *PtrPos values exceed 32-bits
die "urlPtrPos exceeds 64-bit, cannot run on 32-bit machine",     if $header{"zero1"} != 0;
die "titlePtrPos exceeds 64-bit, cannot run on 32-bit machine",   if $header{"zero2"} != 0;
die "clusterPtrPos exceeds 64-bit, cannot run on 32-bit machine", if $header{"zero3"} != 0;
die "mimeListPos exceeds 64-bit, cannot run on 32-bit machine",   if $header{"zero4"} != 0;

print "ZIM header: " . join(", ", %header) . "\n";

sub get_null_string {
    my $out = "";
    while(1) {
        my $raw;
        my $result = xread(\*FILE, $raw, 1);
        my $ch = $raw;
        $out .= $ch; # Need the terminating \0 included
        if (unpack("c",$ch) == 0) {
            last;
        }
    }
    return $out;
}

# read and load MIME TYPE LIST into «file.zim»
my @mime;
xseek(\*FILE, $header{"mimeListPos"}, 0); # no necesary because it must be it
for(my $a=0; 1; $a++){
        my $b = get_null_string();
	chop($b);
	last, if($b eq "");
	$mime[$a] = $b;
}

# read ARTICLE NUMBER (sort  by url) into URL POINTER LIST into «file.zim»
# return ARTICLE NUMBER POINTER
sub url_pointer{
# URL pointer list
	my $article = shift;
	die "Number of articles $article exceed maximum ".$header{"articleCount"}."\n", if $article >= $header{"articleCount"};
	my $pos = $header{"urlPtrPos"};
	$pos += $article*8;
	xseek(\*FILE, $pos, 0);
        xread(\*FILE, $_, 4); my $ret = unpack("I");
        xread(\*FILE, $_, 4); my $ret64 = unpack("I");
	return ($ret64, $ret);
}

# no used
# read ARTICLE NUMBER (sort by title) into TITLE POINTER LIST into «file.zim»
# return ARTICLE NUMBER (not pointer)
sub title_pointer{
# title pointer list
	my $article_by_title = shift;
	die "Number of articles by title $article_by_title exceed maximum ".$header{"articleCount"}."\n", if $article_by_title >= $header{"articleCount"};
	my $pos = $header{"titlePtrPos"};
	$pos += $article_by_title*4;
	xseek(\*FILE, $pos,0);
	xread(\*FILE, $_, 4); my $ret = unpack("I");
	return $ret;
}

# read ARTICLE NUMBER into «file.zim»
# load ARTICLE ENTRY that is point by ARTICLE NUMBER POINTER
# or load REDIRECT ENTRY
my %article;
sub entry{
# directory entries
# article entry
# redirect entry
	%article = ();
	my $article = shift;
	$article{"number"} = $article;
	my ($pos64, $pos) = &url_pointer($article);
        xseek(\*FILE, 0, 0); # Reset to start of file, then break up 64-bit seeks into 31-bit blocks
        for (my $i=0; $i < ($pos64*4); $i++) {
            xseek(\*FILE, 0x40000000, 1);
        }
	xseek(\*FILE, $pos,1);
        
	xread(\*FILE, $_, 2); $article{"mimetype"} = unpack("s");
	xread(\*FILE, $_, 1); $article{"parameter_len"} = unpack("H*");
	xread(\*FILE, $_, 1); $article{"namespace"} = unpack("a");
	xread(\*FILE, $_, 4); $article{"revision"} = unpack("I");
	if($article{"mimetype"} <0){
		xread(\*FILE, $_, 4); $article{"redirect_index"} = unpack("I");
	}else{
		xread(\*FILE, $_, 4); $article{"cluster_number"} = unpack("I");
		xread(\*FILE, $_, 4); $article{"blob_number"} = unpack("I");
	}
        $article{"url"} = get_null_string();
        $article{"title"} = get_null_string();
	chop($article{"url"});
	chop($article{"title"});
	xread(\*FILE, $_, $article{"parameter_len"}); $article{"parameter"} = unpack("H*");
        print "entry == @{[%article]}\n";
}

# read CLUSTER NUMBER into CLUSTER POINTER LIST into «file.zim»
# return CLUSTER NUMBER POINTER
sub cluster_pointer{
# cluster pointer list
	my $cluster = shift;
	return $header{"checksumPos"}, if $cluster >= $header{"clusterCount"}; # die "Number of cluster exceed maximun\n"
	my $pos = $header{"clusterPtrPos"};
	$pos += $cluster*8;
	xseek(\*FILE, $pos,0);
	xread(\*FILE, $_, 4); my $ret = unpack("I");
        xread(\*FILE, $_, 4); my $ret64 = unpack("I");
	return ($ret64, $ret);
}

# read CLUSTER NUMBER into «file.zim»
# decompress CLUSTER
# read BLOB NUMBER into «CLUSTER»
# return DATA
sub cluster_blob{
	my $cluster = shift;
	my $blob = shift;
	my $ret;
        my ($pos64, $pos) = &cluster_pointer($cluster);
        my ($size64, $size) = &cluster_pointer($cluster+1);
        my $old_size = $size;
        my $old_pos = $pos;
        my $old_pos64 = $pos64;
        my $old_size64 = $size64;
        
        $size = $size - $pos - 1;
        my $adjust = 0;
        $size64 = $size64 - $pos64;
        # Adjust for 32-bit wraparound
        if ($old_size < $size) {
            $size64 = $size64 - 1;
            $adjust = 1;
        }
        print STDERR "size64=$size64, pos64=$pos64, adjust=$adjust, oldpos=($old_pos64, $old_pos), oldsize=($old_size64, $old_size), new_size=$size\n";
        # Implement 64-bit seek
        xseek(\*FILE, 0, 0); # Reset to start of file, then break up 64-bit seeks into 31-bit blocks
        for (my $i=0; $i < ($pos64*4); $i++) {
            xseek(\*FILE, 0x40000000, 1);
        }
	xseek(\*FILE, $pos, 1);

        die "Cluster size exceeds 32-bits size64=$size64 != pos64=$pos64, adjust=$adjust, oldpos=($old_pos64, $old_pos), oldsize=($old_size64, $old_size), new_size=$size, which should not happen\n", if $size64 != 0;
	my %cluster;
	xread(\*FILE, $_, 1); $cluster{"compression_type"} = unpack("C");
	# compressed
	if($cluster{"compression_type"} == 4){
		my $data_compressed;
		xread(\*FILE, $data_compressed, $size);
		my $file = "/tmp/$$-cluster-$cluster";
# The following line breaks because it includes the absolute path of arg0
#		my $file = "/tmp/$ARGV[0]_cluster$cluster-pid$$";
		open(DATA, ">$file.xz");
		print DATA $data_compressed;
		close(DATA);
		`xz -d -f $file.xz`;
		open(DATA, "$file");
#	my $blob1;
#	xread(DATA, $blob1, 4);
#	my $blob_count = int($blob1/4);
		seek(DATA, $blob*4, 0);
		read(DATA, $_, 4); my $posStart = unpack("I");
		read(DATA, $_, 4); my $posEnd = unpack("I");
		seek(DATA, $posStart, 0);
		read(DATA, $ret, $posEnd-$posStart);
		close(DATA);
		`rm $file`;
		return $ret;
        } elsif ($cluster{"compression_type"} == 1) {
		my $data;
		xread(\*FILE, $data, $size);
		$_ = substr $data, $blob*4, 4;my $posStart = unpack("I");
		$_ = substr $data, $blob*4+4, 4;my $posEnd = unpack("I");
		$ret = substr $data, $posStart, $posEnd-$posStart;
		return $ret;
	} else {
            die "Invalid compression_type $cluster{\"compression_type\"} detected!\n";
        }
}


# read ARTICLE NUMBER into «file.zim»
# return DATA
sub output_articleNumber{
	my $articleNumber = shift;
	while(1){
		&entry($articleNumber);
		if(defined $article{"redirect_index"}){
			$articleNumber = $article{"redirect_index"};
		}else{
			return 	&cluster_blob($article{"cluster_number"}, $article{"blob_number"});
			last;
		}
	}
}


# search url into «file.zim»
# return DATA
sub output_article{
	my $url = shift ;
	my $articleNumberAbove = $header{"articleCount"};
	my $articleNumberBelow = 0;
	my $articleNumber;
	while(1){
		$articleNumber = int(($articleNumberAbove+$articleNumberBelow)/2);
		&entry($articleNumber);
		if("/$article{namespace}/$article{url}" gt "$url"){
			$articleNumberAbove = $articleNumber-1;
		}elsif("/$article{namespace}/$article{url}" lt "$url"){
			$articleNumberBelow = $articleNumber+1;
		}else{
			last;
		}
		if($articleNumberAbove < $articleNumberBelow){
			%article = ();
			$article{url}="pattern=$url";
			$article{namespace}="SEARCH";
			return "", unless $url =~ /^\/A/;
#			($url) = grep {length($_)>1} split(/[\/\.\s]/, $url);
			$url =~ s#/A/##;
			# make index
			my $file = $ARGV[0];
			$file =~ s/zim$/index/;
			unless(-e $file){
				$|=1;
				open(INDEX, ">$file");
					print "Make file $file\n           /$header{articleCount}";
				for(my $number = 0; $number<$header{"articleCount"};$number++){
					&entry($number);
#	&entry(title_pointer($number));
					print INDEX "/$article{namespace}/$article{url}\n";
					print "\r$number" unless $number%10000;
				}
				print "\n";
				$|=0;
				close(INDEX);
			}
			# search index
			print "Searching for [$url] from index file $file\n";
			my $message = "<html><body>\n" ;
			open(INDEX, "$file");
			while(<INDEX>){
				if(/$url/){
					chop;
					$message .= "<a href='$_'>$_</a><br/>\n";
				}
			}
			$message .= "</body></html>\n";
                        # Find text/html in the mime array, we need to return this as the Content-Type
                        use List::Util qw(first);
                        $article{mimetype} = first { $mime[$_] eq 'text/html' } 0..$#mime;
                        # Alternative way that is experimental
                        # $article{mimetype} = grep { $mime[$_] ~~ "text/html" } 0 .. $#mime;
			return $message;
		}
	}
	return &output_articleNumber($articleNumber);
}

# only for debug; program don't need it
sub debug{
	while(@_){
		my ($k, $v) = (shift, shift);
		print STDERR "\x1b[34;1m{$k} = $v\x1b[m\n";
	}
	print STDERR "\n";
}
# end subs for read into «file.zim»

# net connection (main procedure)
my ($server_ip, $server_port) = ("127.0.0.1", 8080);
my ($d1, $d2, $prototype) = getprotobyname ("tcp");
socket(SSOCKET, PF_INET, SOCK_STREAM, $prototype) || die "socket: $!";
setsockopt(SSOCKET, SOL_SOCKET, SO_REUSEADDR, 1);
# Bind to all network addresses
bind(SSOCKET, sockaddr_in(8080, INADDR_ANY)) || die "bind: $!";
listen(SSOCKET, 5) || die "connect: $!";

print "\x1b[34m$0 $$: listen in localhost:8080 or <this_ip>:8080\c[[33m
write url «localhost:8080» in your web-browser.
to search pattern write url «localhost:8080/pattern»; the first search require some minutes to create «file.index».
if you know the url, write it («localhost:8080/url»).
	note: if url no found, then start search with pattern.
\c[[31mpress C-c for exit.\c[[m\n";

#	To create socket require to fork process.
#	Because the browser connect five socket simultaneously at "localhost:8080" each one ask a diferent url.
#
#	Note: The son process are terminated and they are found as defunct with ps program. I don't know it.
while(1){
# bucle for parent
	my $client_addr = accept(CSOCKET,SSOCKET) || die $!;
	last unless fork;
}
# only sons are connected
sysopen (FILE, $ARGV[0], O_RDONLY); # need reopen for son don't use same file handle
while(1){
	my $http_message;
#		read
	while(1){
		my $message_part;
		recv(CSOCKET, $message_part, 1000, 0);
		$http_message .= $message_part;
		last, if(length($message_part)<1000);
	}
#	print STDERR "\x1b[32m$$:\c[[m\n";
#	print STDERR "\x1b[32;1m$http_message\c[[m";

#		write
	if($http_message =~  /^GET (.+) HTTP\/1.1\r\n/){
# Request-Line Request HTTP-message
# ("OPTIONS", "GET", "HEAD", "POST", "PUT", "DELETE", "TRACE", "CONNECT", "$token+");
		my $url = $1;
		$url =~ s/%(..)/chr(hex($1))/eg;
		$url = "/A/Wikipedia.html", if $url eq "/";
		$url = "/-/favicon", if $url eq "/favicon.ico";
#		$url =~ s#(/.*?/.*?)$#$1#;
		$url = "/A$url", unless $url =~ "/.*/";  # for search
		my $message_body  = &output_article($url);
		my $message_body_length = length($message_body);
		my $message_body_type = $mime[$article{"mimetype"}];

                print STDERR "Returning $url with $mime[$article{\"mimetype\"}], namespace=$article{\"namespace\"}, cluster=$article{\"cluster_number\"}, number=$article{\"number\"}, body_length=$message_body_length\n";

#		print STDERR "\x1b[31m$$: sending ... $article{number} \c[[41;38;1m/$article{namespace}/$article{url}\c[[m\n";
		my $message = "HTTP/1.1 200 OK\r
Connection: Keep-Alive\r
Keep-Alive: timeout=30\r
Content-Type: $message_body_type\r
Content-Length: $message_body_length\r
\r
$message_body";
		send (CSOCKET, $message, 0)||last;
	}else{
		last;
	}
}

shutdown(CSOCKET, 2) ;
close(FILE);

#print STDERR "\x1b[31;42m$$: goodbye\c[[m\n";
# son defunct


__END__

=pod

=head1 NAME

=head1 SYNOPSIS

	url_pointer

	title_pointer

	entry

	cluster_pointer

	cluster_blob

	output_articleNumber

	output_article

	debug

=head1 DESCRIPTION

=over 2

=item needs

	it need «xz» program for decompress cluster.
	it use «rm» command.
	it create files in «/tmp/» directory.
	it's tested in Ubuntu and Sabayon operating systems.

=item input

	use:
zim.pl file.zim

	zim.pl can create file.index for search pattern.
	when create file.index, program work very time; be patient.

=item output

socket connect at localhost:8080
	open url "localhost:8080" with web browser

	Temporaly it make files into tmp directory for decompress clusters
/tmp/file_cluster$cluster-pid$$
	it delete these files immediately.

	To create socket require to fork process.
	Because the browser connect five socket simultaneously at "localhost:8080" each one ask a diferent url.

	Note: The son process are terminated and they are found as defunct with ps program. I don't know it.

=back

=head1 METHODS

=over 2

=item url_pointer

	L<url_pointer>

=item title_pointer

	L<title_pointer>

=item entry

	L<entry>

=item cluster_pointer

	L<cluster_pointer>

=item cluster_blob

	L<cluster_blob>

=item output_articleNumber

	L<output_articleNumber>

=item output_article

	L<output_article>

=item debug

	L<debug>

=back

=head2 header
	%header = (
		"magicNumber" => ZIM\x04,
		"version" => ,
		"uuid" => ,
		"articleCount" => ,
		"clusterCount" => ,
		"urlPtrPos" => ,
		"titlePtrPos" => ,
		"clusterPtrPos" => ,
		"mainPage" => ,
		"checksumPos" => )

=head2 mime

	@mime = (
		"txt/html; charset=utf8",
		"",
		...)

=head2 url_pointer(article_number)

	article_number is sort by url.
	return C<pointer> to article number.

=head2 title_pointer(article_number)

	article_number is sort by title.
	return C<article_number> sort by url.

=head2 entry(article_number)

	article_number is sort by url.
	load in hash %article the entry.
	%article = (
		"number" => article_number,
		"mimetype" => integer, # see L<mimetype>
		"parameter_len" => 0, # no used
		"namespace" => char,
		"revision" => number,
	if(mimetype eq 0xFF)
			"redirect_index" => article_number,
	else
			"cluster_number" => cluster_number,
			"blob_number" => blob_number,
		"url" => string,
		"title" => string)
	

=head2 cluster_pointer(cluster_number)

	return cluster_number_pointer

=head2 cluster_blob(cluster_number, blob_number)

	return data

=head2 output_articleNumber(article_number)

	return data

=head2 output_article(url)

	search the url and return data,
	or search pattern into file.index and return list of item;
	and make file.index if not exist.

	main subrutine of subrutines

	example:
output_article("/A/wikipedia.html");

	search "/A/wikipedia.html" into file.zim
	return page
	the web browser need other files as file.css file.js image.png
output_article("/I/favicon");

output_article("/A/Jordan");
	no found page named /A/Jordan.
	This url start with "/A/" and it start to search.
	It create file.index and search into .zim file,
	which pattern is "Jordan",
	and return list of url which are found with pattern.

output_article("Jordan");
	no found and return null string.

output_article("/I/Jordan");
	no found and return null string.

=head2 debug

...

=head1 LICENSE

This program is free software; you may redistribute it and/or modify it under some terms.

=head1 SEE ALSO

=head1 AUTHORS

Original code by Pedro González.
Released 4-6-2012.
yaquitobi@gmail.com
Comment by Pedro, but I'm not english speaker, excuse me my mistakes.

=cut
