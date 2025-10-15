use warnings;
use strict;
use utf8;
use XML::LibXML;
use Getopt::Long;
use File::Basename;

$\ = "\n"; $, = "\t";

my ($debug, $verbose, $filename, $outfile);
my ($stand_off_type, $stand_off_pref, $stand_off_val_patch, $stand_off_remove);

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

# Rename named entities attributes and remove CNEC prefixes
foreach my $node ( $xml->findnodes("//text//*[\@ana][contains(' name date time email ref num unit ',concat(' ',local-name(),' ' ))]") ) {
	my $val = $node->getAttribute('ana');
	if ( $val =~ s/^.*ne:([^ "]+).*?$/$1/ ) {
		$node->setAttribute('cnec', $val);
	}
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


# Standoff annotations
my %standoff = (
	ATTRIBUTION => {
		type_prefix => 'a',
		ana_prefix => 'attrib',
	}
);

for my $standoff_type (keys %standoff) {
  my $standoffSpanGrp = $xml->findnodes(sprintf('/TEI/standOff[@type="%s"]',$standoff_type))->[0];
  my $resultSpanGrp = $xml->findnodes("/TEI/text")->[0]->addNewChild('','spanGrp');
  $resultSpanGrp->setAttribute("type",$standoff_type);
  # loop over links
	my $linkGrp = $standoffSpanGrp->findnodes(sprintf('./linkGrp[@type="%s"]', $standoff_type))->[0];
	my @names = split / /, $linkGrp->getAttribute('targFunc');
	my %links;
	for my $link ($linkGrp->findnodes('./link')){
		my @values = map {s/#//;$_} split / /, $link->getAttribute('target');
		print STDERR "WARN: invalid link\n" if @names != @values;
		for my $ni (0..$#names){
			my $id = $values[$ni];
      for my $vi (0..$#values){
				next if $ni == $vi;
        $links{$values[$vi]} //= {};
				$links{$values[$vi]}->{$names[$ni]} //= [];
				push @{$links{$values[$vi]}->{$names[$ni]}}, $id;
  		}
		}
  }
  for my $span ($standoffSpanGrp->findnodes(sprintf('./spanGrp[@type="%s"]/span', $standoff_type))){
		$span->unbindNode;
		$resultSpanGrp->addChild($span);
    for my $link_name (keys %{$links{$span->getAttribute('id')}//{}}){
		  $span->setAttribute($standoff{$standoff_type}->{type_prefix}.$link_name,join(' ',@{$links{$span->getAttribute('id')}->{$link_name}}));
		}
		my $ana = $span->getAttribute('ana');
    $ana =~ s/.*\Q$standoff{$standoff_type}->{ana_prefix}\E:([^ ]*).*/$1/;
		$span->setAttribute($standoff{$standoff_type}->{type_prefix}."type",$ana);
		$span->setAttribute("corresp",$span->getAttribute('target'));
	}
	$standoffSpanGrp->unbindNode;
}


my $outdir = dirname $outfile;
mkdir($outdir) unless -d $outdir;

open OUT,">:raw", "$outfile";
print OUT $xml->toString;
close OUT;
print "Saved to $outfile";