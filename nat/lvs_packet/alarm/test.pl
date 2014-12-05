#!/usr/bin/perl
# $Description: A script to monitor lvs cluster. If there is something wrong with , it sends warning messages to monitors.

use File::Basename;
$MAIN_DIR=dirname($0);
require ($MAIN_DIR."/report.pl");
require($MAIN_DIR."/dl_lvsm.pl");
use LWP;
use strict;
use warnings;

##################
# basic variables
##################
## my true and false
use constant true => 1;
use constant TRUE => 1;
use constant false => 0;
use constant FALSE =>0;
get_config("./conf");
doAlarm("sms test", "sms test", 1);
doAlarm("email test", "email test", 0);
