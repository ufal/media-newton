use warnings;
use strict;
use utf8;
use XML::LibXML;
use Getopt::Long;
use File::Basename;

$\ = "\n"; $, = "\t";

my ($debug, $verbose, $filename, $outfile);

GetOptions (
            'debug' => \$debug,
            'verbose' => \$verbose,
            'in=s' => \$filename,
            'out=s' => \$outfile,
        );

if ( !$filename ) { $filename = shift; };
if ( !$outfile ) { $outfile = $filename; };


open FILE, "<:encoding(UTF-8)", $filename;
$/ = undef;
my $raw = <FILE>;
close FILE;

$raw =~ s/xmlns/xmlnsoff/g;
$raw =~ s/xml://g;
$raw =~ s/<text>/<text xml:space="remove">/g;

my $parser = XML::LibXML->new(); 
my $xml;
eval {
	$xml = $parser->load_xml(string => $raw, load_ext_dtd => 0);
};

my %id2node;

# Rename <w> to <tok>
my $rename_attr = {msd => 'feats', pos => 'upos'};
foreach my $node ( $xml->findnodes("//w | //pc") ) {
	my $nodetype = $node->getName();
	$node->setName("tok");
	my $id = $node->getAttribute("id")."";
	while ( my ( $old, $new ) = each %$rename_attr ) { 
		my $attrnode = $node->getAttributeNode( $old );
		if($attrnode) {
			$attrnode->unbindNode();
			$node->setAttribute($new, $attrnode->getValue())
		}
	}
	if($node->hasAttribute('ana')) {
		my ($val) = $node->getAttribute('ana') =~ m/^.*pdt:([^ "]+)/;
		$node->setAttribute('xpos', $val) if $val;
	}

	$id2node{$id} = $node;
	$node->setAttribute("type", $nodetype);
};


# Set UD back to @head and such
foreach my $node ( $xml->findnodes("//linkGrp[\@type=\"UD-SYN\"]/link") ) {
	my ($a1, $a2) = split(" ", $node->getAttribute('target'));
	my ($l1, $l2) = split(":", $node->getAttribute('ana'));
	$l2 =~ s/_/:/g;
	my $base = substr($a2, 1);
  my $head = substr($a1, 1);
	if ( $id2node{$base} && $id2node{$head} ) {
		$id2node{$base}->setAttribute("head", $id2node{$head}->getAttribute("id"));
	};
	if ( $id2node{$base} ) {
		$id2node{$base}->setAttribute("deprel", $l2);
	};
};
foreach my $node ($xml->findnodes("//linkGrp[\@type=\"UD-SYN\"]")) {
  $node->unbindNode;
}


# Copy head attributes to child
for my $base ( keys %id2node ) {
	my $head = $id2node{$base}->getAttribute("head");
	if ( $id2node{$base} && $head && $id2node{$head} ) {
		for my $att (qw/lemma upos xpos feats type deprel/) {
      $id2node{$base}->setAttribute("head_$att", $id2node{$head}->getAttribute($att)) if $id2node{$head}->hasAttribute($att)
		}
	};
};


my $outdir = dirname $outfile;
mkdir($outdir) unless -d $outdir;

open OUT,">:raw", "$outfile";
print OUT $xml->toString;
close OUT;
print "Saved to $outfile";