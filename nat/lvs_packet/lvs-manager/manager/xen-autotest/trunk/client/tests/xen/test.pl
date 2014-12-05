#!/usr/bin/perl

my $a = "/a/b/c";
my $lib_path=`echo $a | sed "s/c//g"`;

$lib_path =~ s/\/$//;


print "value: $lib_path\n";
