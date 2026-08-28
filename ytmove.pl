#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use File::Basename;
use File::Spec;
use File::Copy qw(move);
use POSIX qw(strftime);
use Pod::Usage;

# -----------------------------------------------------------------------------
# YouTube ID Extraction Subroutine
# -----------------------------------------------------------------------------
# Extracts 11-char YouTube ID (ytid) from a filename, stem, or input line.
# Returns: ($detected_id, $id_source)
# $id_source can be 'bracket', 'dash', 'url', 'raw', or 'none'
sub extract_youtube_id {
    my ($input) = @_;
    return (undef, 'none') unless defined $input;

    # Trim leading/trailing whitespace
    $input =~ s/^\s+|\s+$//g;
    return (undef, 'none') unless length($input);

    # Get basename and strip final extension to obtain stem
    my $base = basename($input);
    my $stem = $base;
    $stem =~ s/\.[^.]+$//;

    # 1. Bracketed ID: LAST bracketed 11-char token (titles may contain other brackets)
    # Python ref: _BRACKET_RE = re.compile(r"\[([A-Za-z0-9_-]{11})\](?=[^\[]*$)")
    if ($stem =~ /\[([A-Za-z0-9_-]{11})\][^\[]*$/) {
        return ($1, 'bracket');
    }

    # 2. Dash-suffix ID: exactly 11 valid chars at the END of the stem, preceded by '-'
    # Python ref: _DASH_RE = re.compile(r"-([A-Za-z0-9_-]{11})$")
    if ($stem =~ /-([A-Za-z0-9_-]{11})$/) {
        return ($1, 'dash');
    }

    # 3. Fallback: Check for URL query parameter v=11chars
    if ($input =~ /[?&]v=([A-Za-z0-9_-]{11})/) {
        return ($1, 'url');
    }

    # 4. Fallback: Raw 11-char ID string
    if ($stem =~ /^([A-Za-z0-9_-]{11})$/) {
        return ($1, 'raw');
    }

    return (undef, 'none');
}

# -----------------------------------------------------------------------------
# Main Execution Entry Point
# -----------------------------------------------------------------------------
sub run {
    my (@args) = @_;
    local @ARGV = @args if @args;

    # Command-Line Options
    my $source_dir;
    my $dest_dir;
    my $dry_run = 0;
    my $verbose = 0;
    my $help    = 0;

    GetOptions(
        'source|s=s'      => \$source_dir,
        'destination|d=s' => \$dest_dir,
        'dry-run|n'       => \$dry_run,
        'verbose|v'       => \$verbose,
        'help|h'          => \$help,
    ) or pod2usage(2);

    pod2usage(1) if $help;

    if (!$source_dir || !$dest_dir) {
        warn "Error: Both -s (--source) and -d (--destination) options are required.\n\n";
        pod2usage(2);
    }

    # Resolve canonical paths and verify existence
    $source_dir = File::Spec->rel2abs($source_dir);
    $dest_dir   = File::Spec->rel2abs($dest_dir);

    if (! -d $source_dir) {
        die "Error: Source directory '$source_dir' does not exist or is not a directory.\n";
    }

    if (! -d $dest_dir) {
        die "Error: Destination directory '$dest_dir' does not exist or is not a directory.\n";
    }

    # Log File Setup
    my $timestamp = strftime("%Y%m%d_%H%M%S", localtime);
    my $log_filename = "ytmove_log_$timestamp.txt";
    my $log_path = File::Spec->catfile($source_dir, $log_filename);

    open(my $log_fh, '>>', $log_path) or die "Cannot open log file '$log_path' for writing: $!\n";
    select((select($log_fh), $| = 1)[0]); # Autoflush log handle

    my $log_msg = sub {
        my ($msg) = @_;
        my $time_str = strftime("%Y-%m-%d %H:%M:%S", localtime);
        print $log_fh "[$time_str] $msg\n";
        print "[$time_str] $msg\n" if $verbose || $dry_run;
    };

    # Log script header
    $log_msg->("=== Starting ytmove.pl ===");
    $log_msg->("Source Dir      : $source_dir");
    $log_msg->("Destination Dir : $dest_dir");
    $log_msg->("Dry Run Mode    : " . ($dry_run ? "YES" : "NO"));

    # Pre-Scan & Hash Index Source Directory
    my %source_index; # ytid => [ full_path1, full_path2, ... ]
    my $files_indexed_count = 0;

    opendir(my $dh, $source_dir) or die "Cannot open source directory '$source_dir': $!\n";
    my @dir_entries = readdir($dh);
    closedir($dh);

    foreach my $file (sort @dir_entries) {
        next if $file eq '.' || $file eq '..';
        next if $file =~ /^ytmove_log_.*\.txt$/; # Skip log files created by ytmove

        my $full_path = File::Spec->catfile($source_dir, $file);
        next unless -f $full_path; # Top-level files only

        my ($ytid, $id_src) = extract_youtube_id($file);
        if ($ytid) {
            push @{ $source_index{$ytid} }, $full_path;
            $files_indexed_count++;
        }
    }

    $log_msg->("Indexed $files_indexed_count candidate file(s) across " . scalar(keys %source_index) . " unique YouTube ID(s) in source directory.");

    # Process STDIN Line by Line
    my $processed_lines   = 0;
    my $moved_files_count = 0;
    my $unmatched_count   = 0;

    while (my $line = <STDIN>) {
        chomp $line;
        $line =~ s/\r$//; # Remove carriage return if Windows line endings present

        # Ignore blank lines and lines starting with '#'
        next if $line =~ /^\s*$/;
        next if $line =~ /^\s*#/;

        $processed_lines++;
        my ($ytid, $id_src) = extract_youtube_id($line);

        if (!$ytid) {
            $log_msg->("WARN: Could not parse YouTube ID from line: '$line'");
            $unmatched_count++;
            next;
        }

        if (exists $source_index{$ytid} && @{ $source_index{$ytid} }) {
            my @matching_files = @{ $source_index{$ytid} };
            foreach my $src_path (@matching_files) {
                my $filename  = basename($src_path);
                my $dest_path = File::Spec->catfile($dest_dir, $filename);

                if ($dry_run) {
                    $log_msg->("DRY-RUN: Would move '$src_path' -> '$dest_path'");
                    $moved_files_count++;
                } else {
                    if (move($src_path, $dest_path)) {
                        $log_msg->("MOVED: '$src_path' -> '$dest_path'");
                        $moved_files_count++;
                    } else {
                        $log_msg->("ERROR: Failed to move '$src_path' -> '$dest_path': $!");
                    }
                }
            }
        } else {
            $log_msg->("NOT FOUND: No file matching YTID '$ytid' (parsed from '$line') in source folder.");
            $unmatched_count++;
        }
    }

    $log_msg->("=== Summary: Lines processed: $processed_lines | Files moved: $moved_files_count | Unmatched/Errors: $unmatched_count ===");
    close($log_fh);

    print "ytmove.pl completed. Processed $processed_lines line(s), moved $moved_files_count file(s). Log saved to $log_path\n" if ! $verbose;
}

run() unless caller;
1;

__END__

=head1 NAME

ytmove.pl - Locate and move YouTube videos from a source directory based on input lines.

=head1 SYNOPSIS

ytmove.pl -s /path/to/source -d /path/to/destination < list.txt

Options:

    -s, --source       Source directory containing files to scan and move (Required)
    -d, --destination  Destination directory to move matched files into (Required)
    -n, --dry-run      Simulate file moves without actually relocating files
    -v, --verbose      Print log messages to STDOUT as well as the log file
    -h, --help         Display this help documentation

=head1 DESCRIPTION

ytmove.pl reads lines from STDIN (skipping blank lines and comments starting with '#').
Each valid line is parsed for an 11-character YouTube ID using bracketed or dash-suffix
naming conventions created by YouTube downloaders.

The source directory is pre-indexed for fast lookups. All matching files in the source
directory for each parsed YouTube ID are moved to the destination directory.
A timestamped log file (ytmove_log_$TIMESTAMP.txt) is written inside the source directory.

=cut
