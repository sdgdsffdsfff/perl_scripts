#!/usr/bin/perl
use warnings;
#use diagnotics;


print "请先输入字符串"."\n";
chomp( $string = <STDIN> );
print "请输入重复的次数"."\n";
chomp( $times = <STDIN> );
print "result is ".$string x $times."\n"