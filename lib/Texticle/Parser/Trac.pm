package Texticle::Parser::Trac;
use Moose;
extends 'Texticle::Parser';

use Texticle::Node;
use Scalar::Util qw(blessed);
use Ref::Util qw(is_arrayref is_coderef);
use Readonly;

use Data::Dumper;

my $END_RE = qr{
	\n\s*\n+
	|
	[\s\n]*\z
}msx;

Readonly my %RE => (
	code_block => qr{
		^\{\{\{\s*\n
		(
			(?:
				\#\![^\n]+\n
			)?
		)
		(.*?)\n
		^\}\}\}\s*$
		[\s\n]*
	}msx,

	header => qr{
		^\s*
		(=+)
		\s*
		([^\n]*?)
		\s*
		=*
		\s*$
	}mx, # no /s

	table => qr{
		\s*
		^
		(
			\|\| .*?
		)
		$END_RE
	}msx,

	list => qr{
		\s*
		^
		(
			\s* \* .*?
		)
		$END_RE
	}msx,

	quote => qr{
		\s*
		^
		(
			\s*	\> .*?
		)
		$END_RE
	}msx,

	paragraph => qr{
		^\s*(.+?)
		$END_RE
	}msx,

	# Inline
	
	code_backticks => qr{ \` (.*?) \` }msx,
	code_braces => qr{ \{\{\{ (.*?) \}\}\} }msx,
	bolditalic => qr{ \'\'\'\'\' (.*?) \'\'\'\'\' }msx,
	italic => qr{ \'\' (.*?) \'\' }msx,
	bold => qr{ \'\'\' (.*?) \'\'\' }msx,
	link => qr{ \[ ([^\]\s]+) \s+ ([^\]]+) \] }msx,
	image => qr{ \[\[ Image \( ([^,)]+) [^)]* \) \]\] }msx,
);

sub parse{
	my ($self, @stream) = @_;
	my $stream = \@stream;

	foreach my $type (qw(code_block header list quote table paragraph)){
		$stream = $self->match_re($stream, $type);
	}

	return $stream;
}

sub parse_inline{
	my ($self, @stream) = @_;
	my $stream = \@stream;
	
	$stream = $self->match_re($stream, 'code_backticks');
	$stream = $self->match_re($stream, 'code_braces');
	$stream = $self->match_re($stream, 'bolditalic');
	$stream = $self->match_re($stream, 'bold'); # This has to be above italic
	$stream = $self->match_re($stream, 'italic');
	$stream = $self->match_re($stream, 'image'); # Must be above link
	$stream = $self->match_re($stream, 'link');

	return $stream;
}

sub match_re{
	my ($self, $stream, $type) = @_;

	my $method = '_generate_' . $type;
	my $re = $RE{$type};

	my @out;
	foreach my $text (@{$stream}){

		# Skip objects (they've already been parsed)
		# TODO: maybe recurse into them
		if (blessed $text){
			push @out, $text;
			next;
		}

		# Match against text
		while (my @matches = $text =~ m/$re/msxp){
			push @out, ${^PREMATCH} if length ${^PREMATCH};
			$text = ${^POSTMATCH} || ''; # Do this here as ${^POSTMATCH} might get emptied by $method()
			push @out, $self->$method(\@matches);
		}

		# Put any leftovers onto stack
		push @out, $text if length $text;
	}
	return \@out;
}

sub _generate_code_block{
	my ($self, $matches) = @_;
	my $format;
	if ($format = $matches->[0]){
		$format =~ s/^\#\!|[\s\n]*$//g;
	}
	return Texticle::Node::CodeBlock->new(
		format => $format,
		value => $matches->[1],
	);
}

sub _generate_header{
	my ($self, $matches) = @_;
	return Texticle::Node::Header->new(
		level => length $matches->[0],
		value => $matches->[1],
	);
}

sub _generate_table{
	my ($self, $matches) = @_;

	my $table = Texticle::Node::Table->new;

	foreach my $line (split /\s*\n\s*/, $matches->[0]){
		my $row = Texticle::Node::Table::Row->new;

		# Trim start and end
		$line =~ s/^ \|\| | \|\| $//msxg;

		# Extract fields
		foreach my $field (split /\|\|/, $line){
			my ($match) = $field =~ s/^(=+)\s* | \s*=+\s*$//msxg;

			push @{$row->nodes}, Texticle::Node::Table::Cell->new(
				header => !!$match,
				value => $field,
			);
		}

		push @{$table->nodes}, $row;
	}

	return $table;
}

sub _generate_quote{
	my ($self, $matches) = @_;
	$matches->[0] =~ s/^\s*\>\s*//msxg;
	return Texticle::Node::Quote->new(
		value => $matches->[0],
	);
}

sub _generate_blockquote{
	my ($self, $matches) = @_;
	$matches->[0] =~ s/^\s+//msxg;
	return Texticle::Node::Quote->new(
		value => $matches->[0],
	);
}

sub _generate_list{
	my ($self, $matches) = @_;
	my @items;

	my $previous_depth = 0;
	my %depth_lookup;

	while ($matches->[0] =~ m/^(\s*) \* \s* (.*?)\s*$/msxg){

		# Calculate depth. First see if we've seen this number of spaces before,
		# and use that. Otherwise check to see if it's deeper than the last depth,
		# if so indent by one.
		my $depth;
		my $space_count = length $1;

		if ($depth_lookup{$space_count}){
			$depth = $depth_lookup{$space_count};
		}
		elsif ($space_count > $previous_depth){
			$depth = $previous_depth + 1;
			$depth_lookup{$space_count} = $depth;
		}
		else{
			# Should only happen if depth goes down to a level we haven't
			# seen before (ie someone's doing mixed tabs+spaces indenting or
			# something else daft). In which case we assume it's down a level,
			# but don't go below 1.
			$depth = $previous_depth <= 1 ? 1 : $previous_depth - 1;
		}
		$previous_depth = $depth;

		my $text = $2;
		push @items, Texticle::Node::List::Item->new(
			depth => $depth,
			value => $text,
		);
	}

	return Texticle::Node::List->new(
		type => 'bullet',
		nodes => \@items,
	);
}

sub _generate_paragraph{
	my ($self, $matches) = @_;
	return Texticle::Node::Paragraph->new(
		value => $self->parse_inline($matches->[0]),
	);
}

sub _generate_bolditalic{
	my ($self, $matches) = @_;
	return Texticle::Node::Inline::Bold->new(
		value => Texticle::Node::Inline::Italic->new(
			value => $matches->[0],
		)
	);
}

sub _generate_image{
	my ($self, $matches) = @_;
	return Texticle::Node::Inline::Image->new(
		target => $matches->[0],
	);
}

sub _generate_link{
	my ($self, $matches) = @_;
	return Texticle::Node::Inline::Link->new(
		target => $matches->[0],
		value => $matches->[1],
	);
}

sub _generate_bold{
	return shift->_generate_inline(shift, 'Bold');
}

sub _generate_italic{
	return shift->_generate_inline(shift, 'Italic');
}

sub _generate_code_backticks{
	return shift->_generate_inline(shift, 'Code');
}

sub _generate_code_braces{
	return shift->_generate_inline(shift, 'Code');
}

sub _generate_inline{
	my ($self, $matches, $class) = @_;
	$class = "Texticle::Node::Inline::$class";
	return $class->new(
		value => $matches->[0],
	);
}

1;
