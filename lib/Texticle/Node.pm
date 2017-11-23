package Texticle::Node;
use Moose;

package Texticle::Node::Container;
use Moose;
extends 'Texticle::Node';

has 'nodes' => (
	is		=> 'rw',
	isa		=> 'ArrayRef[Texticle::Node|Str]',
	default	=> sub{ [] },
);

package Texticle::Node::Text;
use Moose;
extends 'Texticle::Node';

has 'value' => (
	is		=> 'rw',
	isa		=> 'Str|Texticle::Node::Inline|ArrayRef[Str|Texticle::Node::Inline]',
	default => sub{ [] },
);

package Texticle::Node::Paragraph;
use Moose;
extends 'Texticle::Node::Text';

package Texticle::Node::Quote;
use Moose;
extends 'Texticle::Node::Text';

package Texticle::Node::Header;
use Moose;
extends 'Texticle::Node::Text';

has 'level' => (
	is		=> 'ro',
	isa		=> 'Int',
);

package Texticle::Node::CodeBlock;
use Moose;
extends 'Texticle::Node::Text';

has 'format' => (
	is		=> 'ro',
	isa		=> 'Str',
);

# Tables

package Texticle::Node::Table;
use Moose;
extends 'Texticle::Node::Container';

has '+nodes' => (
	isa		=> 'ArrayRef[Texticle::Node::Table::Row]',
);

package Texticle::Node::Table::Row;
use Moose;
extends 'Texticle::Node::Container';

has '+nodes' => (
	isa		=> 'ArrayRef[Texticle::Node::Table::Cell]',
);

package Texticle::Node::Table::Cell;
use Moose;
extends 'Texticle::Node::Text';

has 'header' => (
	is	 	=> 'ro',
	isa		=> 'Bool',
	default	=> 0,
);

# Lists

package Texticle::Node::List;
use Moose;
extends 'Texticle::Node::Container';

has 'type' => (
	is		=> 'ro',
	isa		=> 'Str',
	default	=> 'bullet',
);

has '+nodes' => (
	isa		=> 'ArrayRef[Texticle::Node::List::Item]',
);

package Texticle::Node::List::Item;
use Moose;
extends 'Texticle::Node::Text';

has 'depth' => (
	is		=> 'ro',
	isa		=> 'Int',
);

# Inline

package Texticle::Node::Inline;
use Moose;
extends 'Texticle::Node::Text';

package Texticle::Node::Inline::Code;
use Moose;
extends 'Texticle::Node::Inline';

package Texticle::Node::Inline::Italic;
use Moose;
extends 'Texticle::Node::Inline';

package Texticle::Node::Inline::Bold;
use Moose;
extends 'Texticle::Node::Inline';

package Texticle::Node::Inline::Link;
use Moose;
extends 'Texticle::Node::Inline';

has 'target' => (
	is		=> 'ro',
	isa	 	=> 'Str',
);

package Texticle::Node::Inline::Image;
use Moose;
extends 'Texticle::Node::Inline';

has 'target' => (
	is		=> 'ro',
	isa	 	=> 'Str',
);

1;
