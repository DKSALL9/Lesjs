#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use LWP::UserAgent;
use HTTP::Request;
use HTML::TreeBuilder;
use URI;
use IO::File;
use Pod::Usage;
use Log::Log4perl qw(get_logger :levels);

# Initialize logging
Log::Log4perl->easy_init($ERROR);  # Set default log level to ERROR
my $logger = get_logger();

# Print header
print_header();

# Define default values for options
my $url;
my $method = 'GET';
my $output_file;
my $input_file;
my @headers;
my $insecure = 0;
my $timeout = 10;
my $help = 0;
my $user_agent = "Lesjs/1.0";  # Default User-Agent
my $log_level = $ERROR;

# Parse command-line arguments
GetOptions(
    'url=s'      => \$url,
    'method=s'   => \$method,
    'output=s'   => \$output_file,
    'input=s'    => \$input_file,
    'header=s'   => \@headers,
    'insecure'   => \$insecure,
    'timeout=i'  => \$timeout,
    'user-agent=s' => \$user_agent,
    'log-level=s' => \$log_level,
    'help|h'     => \$help,
) or pod2usage(2);

# Set logging level
$logger->level($log_level);

# Display help message if needed
pod2usage(1) if $help;

# Read URLs from standard input if available
my @urls = read_urls_from_input($input_file, $url);

# Exit if no URLs are provided
if (!@urls) {
    $logger->error("No URLs supplied");
    exit 1;
}

# Main processing loop for each URL
my @all_sources;
foreach my $url (@urls) {
    my @sources = get_script_src($url, $method, \@headers, $insecure, $timeout, $user_agent);
    foreach my $src (@sources) {
        print $src, "\n";
    }
    push @all_sources, @sources if $output_file;
}

# Save to output file if specified
save_to_file($output_file, \@all_sources) if $output_file;

# Functions

# Print the header banner
sub print_header {
    print <<'HEADER';
                                                         
     / /                                                  
    / /         ___        ___           ( )      ___    
   / /        //___) )   ((   ) )       / /     ((   ) ) 
  / /        //           \ \          / /       \ \     
 / /____/ / ((____     //   ) )   ((  / /     //   ) )   
                                                         
HEADER
}

# Read URLs from input file or command-line args or stdin
sub read_urls_from_input {
    my ($input_file, $url) = @_;
    my @urls;

    # Read URLs from input file if specified
    if ($input_file) {
        open my $fh, '<', $input_file or die "Could not open input file: $!";
        while (<$fh>) {
            chomp;
            push @urls, $_;
        }
        close $fh;
    }

    # Read URLs from stdin if available
    if (! -t STDIN) {
        while (<STDIN>) {
            chomp;
            push @urls, $_;
        }
    }

    # Add URL from command-line argument if specified
    push @urls, $url if $url;

    return @urls;
}

# Get JavaScript sources from a URL
sub get_script_src {
    my ($url, $method, $headers, $insecure, $timeout, $user_agent) = @_;
    
    $logger->info("Fetching JavaScript sources from $url");

    my $ua = LWP::UserAgent->new;
    $ua->timeout($timeout);
    $ua->ssl_opts(verify_hostname => !$insecure);
    $ua->agent($user_agent);  # Set custom User-Agent

    my $req = HTTP::Request->new($method => $url);
    foreach my $header (@$headers) {
        my ($key, $value) = split /:/, $header, 2;
        $req->header($key => $value);
    }

    my $res = $ua->request($req);
    if (!$res->is_success) {
        $logger->error("$url returned " . $res->status_line);
        return ();
    }

    my $tree = HTML::TreeBuilder->new;
    $tree->parse($res->decoded_content);
    $tree->eof;

    my @sources;
    foreach my $script ($tree->find_by_tag_name('script')) {
        my $src = $script->attr('src') || $script->attr('data-src');
        push @sources, $src if $src;
    }

    $tree = $tree->delete;
    return @sources;
}

# Save JavaScript sources to output file
sub save_to_file {
    my ($output_file, $sources) = @_;
    open my $out_fh, '>', $output_file or die "Could not open output file: $!";
    foreach my $src (@$sources) {
        print $out_fh $src, "\n";
    }
    close $out_fh;
}

__END__

=head1 NAME

Lesjs - Fetch JavaScript sources from web pages

=head1 SYNOPSIS

Lesjs [options]

 Options:
   --url URL            The URL to get the JavaScript sources from
   --method METHOD      The request method (GET or POST) (default: GET)
   --output FILE        Output file to save the results to
   --input FILE         Input file with URLs
   --header HEADER      Any HTTP headers (-H "Authorization:Bearer token")
   --insecure           Skip SSL security checks
   --timeout SECONDS    Max timeout for the requests (default: 10 seconds)
   --user-agent AGENT   Custom User-Agent string
   --log-level LEVEL    Set log level (DEBUG, INFO, WARN, ERROR, FATAL)
   --help, -h           Show this help message

=head1 DESCRIPTION

This script fetches JavaScript sources from the specified URLs and prints or saves the results to a file.
It supports logging and more robust error handling.

=cut
