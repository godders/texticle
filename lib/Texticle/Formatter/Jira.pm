package Texticle::Formatter::Jira;
use Moose;
use Ref::Util qw(is_arrayref);
use Scalar::Util qw(blessed);

sub format{
	my ($self, $stream) = @_;

	my @out;
	foreach my $node (@{$stream}){
		if (blessed $node){
			my $type = ref $node;
			$type =~ s/^Texticle::Node:://;
			my $method = '_format_' . lc($type);
			push @out, $self->$method($node);
		}
		else{
			push @out, $node;
		}
	}
	return join '', @out;
}

sub format_inline{
	my ($self, $inline) = @_;
	$inline = [ $inline ] unless is_arrayref $inline;

	my @out;
	foreach my $node (@{$inline}){
		if (blessed $node){
			my $type = ref $node;
			$type =~ s/^Texticle::Node::Inline:://;
			my $method = '_format_inline_' . lc($type);
			push @out, $self->$method($node);
		}
		else{
			push @out, $node;
		}
	}
	return join '', @out;
}

sub _format_header{
	my ($self, $node) = @_;
	return sprintf "h%s. %s\n\n", $node->level, $self->format_inline($node->value);
}

sub _format_codeblock{
	my ($self, $node) = @_;
	my $format = $node->format ? ':' . $node->format : '';
	return sprintf "{code%s}\n%s\n{code}\n\n", $format, $self->format_inline($node->value);
}

sub _format_quote{
	my ($self, $node) = @_;
	return sprintf "{quote}\n%s\n{quote}\n\n", $self->format_inline($node->value);
}

sub _format_list{
	my ($self, $node) = @_;
	my @out;
	foreach my $item (@{$node->nodes}){
		push @out, sprintf(
			"%s %s\n",
			'*' x $item->depth,
			$self->format_inline($item->value),
		);
	}
	return join('', @out) . "\n";
}

sub _format_table{
	my ($self, $node) = @_;
	my @out;
	foreach my $row (@{$node->nodes}){

		my @line;
		foreach my $cell (@{$row->nodes}){
			my $value = $self->format_inline($cell->value);
			if ($cell->header){
				$value = '|' . $value . '|';
			}
			push @line, $value;
		}
		push @out, '|' . join('|', @line) . "|\n";
	}
	return join('', @out) . "\n";
}

sub _format_paragraph{
	my ($self, $node) = @_;
	return $self->format_inline($node->value) . "\n\n";
}

sub _format_inline_code{
	my ($self, $node) = @_;
	return '{{' . $node->value . '}}';
}

sub _format_inline_italic{
	my ($self, $node) = @_;
	return '_' . $self->format_inline($node->value) . '_';
}

sub _format_inline_bold{
	my ($self, $node) = @_;
	return '*' . $self->format_inline($node->value) . '*';
}

sub _format_inline_link{
	my ($self, $node) = @_;
	return sprintf('[%s|%s]', $self->format_inline($node->value), $node->target || '');
}

sub _format_inline_image{
	my ($self, $node) = @_;
	return sprintf('!%s!', $node->target || '');
}

1;
