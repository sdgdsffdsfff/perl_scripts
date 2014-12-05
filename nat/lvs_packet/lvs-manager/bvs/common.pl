###############
# Const Values
###############
## true and false, success and fail
use constant true => 1;
use constant TRUE => 1;
use constant false => 0;
use constant FALSE =>0;

## Valid protocol
my @Protocol = ('TCP', 'UDP');

##################
# Basic functions
##################
# print error message and exit with exit code
# $_[0] error message
# $_[1] exit code
sub err_exit($$)
{
    print "$_[0]\n";
    exit $_[1];
}

# $return true if $_[0] is an ip address
sub is_ip($)
{
    if("$_[0]" =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/) {
        if($1 >= 0 && $1 <= 255 && $2 >= 0 && $2 <= 255 && $3 >= 0 && $3 <= 255 && $4 >= 0 && $4 <= 255) {
            return true;
        }
    }
    return false;
}

# 1-65535
sub is_port($)
{
	if("$_[0]" =~ /^(\d+)$/) {
		if($1 > 0 && $1 < 65535) {
			return true;
        	}
    	}
	return false;
}

# is $_[0] a valid protocol?
sub is_protocol($)
{
	foreach my $pro (@Protocol)
	{
		if($pro eq $_[0])
		{
			return true;
		}
	}
	return false;
}

sub oct_to_hex($$)
{
	my $hex_num = sprintf("%0$_[1]X", $_[0]);
	return $hex_num;
}

sub hex_to_ip($)
{
	my @ip_seg;
	my $ip;
	my @ip_char = split('', $_[0]);
	my $i;
	for($i = 0; $i < 8; $i += 2)
	{
		push(@ip_seg, hex("$ip_char[$i]$ip_char[$i+1]"));
	}
	$ip = $ip_seg[0].".".$ip_seg[1].".".$ip_seg[2].".".$ip_seg[3];
	return $ip;
}
# cp file to file.time, e.g. file.2012.03.22.21.11.01
# $_[0] source path of file or directory
# $_[1] dest path
sub back_up_file($$)
{
	my $date;
	my $result;
	my $file_name;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900;
	$mon ++;
	$date = sprintf("%04d.%02d.%02d.%02d.%02d.%02d", $year, $mon, $mday, $hour, $min, $sec);
	my @tmp = split('/', $_[0]);
	if (-d $_[0] or -f $_[0])
	{
		$file_name = $tmp[$#tmp];
		chomp($file_name);
	}
	else
	{
		return -1;
	}

	if (not -e $_[1])
	{
		print("mkdir -p $_[1]\n");
		`mkdir -p $_[1]`;
	}

	if( -e "$_[1]/$file_name.$date")
	{
		my $i = 2;
		while( -e "$_[1]/$file_name.$date.$i")
		{
			$i++;
		}
		$date .= ".$i";
	}

	$result = `cp -r $_[0] $_[1]/$file_name.$date`;
	if ($result ne "")
	{
		return 0;
	}
	return 1;
}

1;
