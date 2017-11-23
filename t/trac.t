#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Texticle::Parser::Trac;
use Texticle::Formatter::Jira;
use FindBin qw($Bin);

# Slurp file
my $text = do{ local $/; open my $file, '<', "$Bin/samples/simple.trac" or die $!; <$file> };

# Build parser
my $parser = Texticle::Parser::Trac->new;

# Parse document
my $doc = $parser->parse($text);

use Data::Dumper;
print Dumper $doc;

my $formatter = Texticle::Formatter::Jira->new;
print $formatter->format($doc);
