#!/usr/bin/perl

use strict;
use warnings;

=pod

=head1 NAME

check_cas_nagios_mechanized.pl - CAS nagios check.  Uses WWW:Mechanize::FormFiller to check CAS authentication.

=head1 SYNOPSIS

    check_cas_nagios_mechanized.pl
        [ --url https://localhost:8443/cas/login ] \
        [ --regex 'Log In Successful' ] \ # A regex to look for when login is successful
        # Credentials must come from 1 of 3 places:
        [ --user username --password password ] | # the command line
        [ --credentials-file /path/to/file/with/credentials ] | # a file with the username and password on separate lines
        [ --interactive-credentials ] # prompt for credentials

=head1 DESCRIPTION

This script will make 2 calls to CAS.  1 to recieve the initial form, one to submit it.

The URL defaults to https://localhost:8443/cas/login
The regex defaults to 'Log In Successful'.  This text string is present in the notification for a successful login.

=head1 AUTHOR

  Martin VanWinkle (mvanwinkle@ias.edu)

=head1 LICENSE

  License

  copyright (C) 2017 Martin VanWinkle III, Institute for Advanced Study

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  See 

  http://www.gnu.org/licenses/

=cut

# Requires lots of things
# perl-TermReadKey.x86_64
# Nagios::Plugin::WWW::Mechanize


use Nagios::Plugin::WWW::Mechanize;

use Pod::Usage;

use Getopt::Long;

my $np = Nagios::Plugin::WWW::Mechanize->new( 
	usage => "Attempts to log into CAS."
);

my (
	$user,
	$password,
	$url,
	$regex,
	$critical,
	$credentials_file,
	$interactive_credentials,
	$debug,
);

GetOptions(
	'user=s' => \$user,
	'password=s' => \$password,
	'url=s' => \$url,
	'regex=s' => \$regex,
	'critical' => \$critical,
	'credentials-file=s' => \$credentials_file,
	'interactive-credentials' => \$interactive_credentials,
	'debug' => \$debug,
) or pod2usage(-message => "Invalid options specified." , -exitval => 1);

if ($credentials_file)
{
	load_credentials($credentials_file);
}
if ($interactive_credentials)
{
	interactive_credentials();
}


if (!$user || !$password)
{
	$np->nagios_exit(
		UNKNOWN,
		"You need to provide a user and password.",
	);
}

$url ||= 'https://localhost:8443/cas/login';
$regex ||= 'Log In Successful';



$np->getopts();

$np->get($url);

$np->submit_form(
	form_id => 'fm1',
	fields => {
		'username' => $user,
		'password' => $password,
	},
);

my $decoded_submit_response = $np->content();

# print $decoded_submit_response;

debug($decoded_submit_response);

if ($decoded_submit_response =~ m/$regex/)
{
	$np->nagios_exit(
		OK,
		$regex,
	);
}
else
{
	$np->nagios_exit(
		($critical?'CRITICAL':'WARNING'),
		'Authentication failed.'
	);
}

sub load_credentials
{
	my ($file_name) = @_;
	use IO::File;

	my $fh = new IO::File "<$file_name"
		or 	$np->nagios_exit(
			UNKNOWN,
			"Can't open credentials file $file_name : $!",
		);
	
	my $line;
	my @parts;
	while (defined( $line = <$fh>))
	{
		$line =~ s/^\s+//g;
		$line =~ s/\s+$//g;
		
		push @parts, $line;
	}
	
	$user = $parts[0];
	$password = $parts[1];
	
	$fh->close();
}

sub interactive_credentials
{
	use Term::ReadKey;
	print "Username: ";
	chomp($user = <STDIN>);
	print "Password: ";
	ReadMode('noecho');
	chomp($password = <STDIN>);
	ReadMode(0);
	print $/;
}

sub debug
{
	print STDERR @_ if $debug;
}
