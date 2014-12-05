#!/usr/bin/perl
use warnings;
use diagnostics;

print "please input r"."\n";
chomp($r = <STDIN>);

if ( $r > 0 ){
	print "周长为".3.14*$r*$r."\n";
}else{
	print "周长应该大于0"."\n";
}