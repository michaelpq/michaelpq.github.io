# scripts/generate_tags.pl
#
# Script to generate markdown tag files from all blog posts in this
# repository.  All the blog posts have a verty determined structure,
# making it easy to scan its tags and generate a set of markdown file
# automatically out of them.  Here is the header structure of a post:
# ---
# author: John Doe
# [...]
# tags:
# - tag 1
# - tag 2
# ---
#
# So the goal of this script is to simply check the headers of each
# file, extract the tags one by one, and then generate the wanted
# markdown files.
#
# This script should be run from the root tree of this repository with
# the following command:
# ./scripts/generate_tags.pl

use strict;
use warnings;

# Simple wrapper aimed at creating a fresh file with given contents.
sub create_file
{
	my ($filename, $str) = @_;
	open my $fh, '>', $filename
	    or die "could not write \"$filename\": $!";
	print $fh $str;
	close $fh;
}

# Taking a tag from a blog post, generate its equivalent markdown file.
# Any existing file is overwritten.
sub generate_tag_file
{
	my $tag = shift;
	my $tagfile = "tag/$tag.markdown";

	create_file($tagfile,
	qq(---
layout: tag
title: "Tag: $tag"
type: tag
tag: $tag
---
));
}

# First scan the posts available.
opendir my $dir, "_posts" or die "Cannot open directory: $!";
while (my $file = readdir($dir))
{
	open my $info, "_posts/$file" or die "Could not open $file: $!";
	my $header_count = 0;
	my $tag_section = 0;

	while (my $line = <$info>)
	{
		$header_count++ if ($line =~ /^---/);
		$tag_section = 1 if ($line =~ /^tags:/);

		chomp($line);

		# Skip the tag header
		next if ($line =~ /^tags:/);
		# Skip empty lines
		next if ($line eq '');
		# Nothing to read out of tag section.
		next if not $tag_section;
		# Header is completed, so ignore the rest.
		last if $header_count >= 2;

		# Cut the first two characters from the string "- ".
		$line = substr($line, 2);
		generate_tag_file($line);
	}
	close $info;
}
closedir $dir;
