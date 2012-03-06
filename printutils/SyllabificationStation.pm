package SyllabificationStation;

=cut

=head1 SyllabificationStation v0.2

=head1 Synopsis

=head1 Description

This is a generalized class for syllabifying transcribed words encoded
as UTF-8.  It is especially suited to working with transcriptions
using numbers (either prefixed or postfixed) to mark tones.

=head1 Version History

0.1 by David Mortensen

0.2 by Dominic Yu
- fixed bug with by-delimiter syllabification (' ' - '=', including parentheses, no longer considered delimiters)
- fixed a bug with tone prefixes
- now handles hyphen at beginning of form
- added preliminary support for the overriding delimiter

=cut

use strict;
use utf8;
use Encode qw/ decode encode from_to /;

# character classes for regular expressions
my $tonchar = "⁰¹²³⁴⁵⁶⁷⁸0-9ˊˋ˥-˩";
my $delim = "-=≡≣+.,;/~◦⪤↮ ()"; # '-' hyphen must be at beginning or end
	# or else it screws up the regex set

=head2 new()

Constructor class for SyllabificationStation objects.

=cut

sub new {
    # create object and populate it with useful members
    my $self = {
	'regexes' => {
	    'bytonepostfix' =>
		qr<([^$delim$tonchar]+[$tonchar]+(?:\|$)?)([$delim]*)>,
	    'bytoneprefix' =>
	        qr<([$tonchar]{1,2}[^$delim$tonchar]+)([$delim]*)>,
	        	# remember delim comes first because it starts with hyphen!
	    'bydelimiters' =>
	        qr<([^$delim]+)([$delim]*)>,
	    },
	'debug' => 0,
	'syls'     => [ ],
	'num_syls' => 0,
	'delims'   => [ ],
	'prefix'   => '',
	'residue'  => [ ],
	'tags'     => [ ],
	'grammar_used' => '',
	're_order' => [ 'bytonepostfix', 'bytoneprefix', 'bydelimiters' ]};

    return bless $self;
}

=cut

=head2 syllabify_per_regex($self, $regex, $word)

Divide $word into syllables and delimiters, which it stores as members
of the class. Returns 1 if the parse is exhaustive and 0 if it fails
(is not exhaustive).

=cut

sub syllabify_per_regex {
    my ($self, $re, $word) = @_;
    $self->{syls} = [ ];
    $self->{delims} = [ ];
    $self->{prefix} = '';
    if ($word =~ s/^([$delim]+)//o) {
    	$self->{prefix} = $1; # save beginning delim chars for later
    }
    $word =~ s/\(([^$delim$tonchar]+)\)/（$1）/og; # pretend that parens surrounding non-delims are not delimiters
    while ($word =~ s/\A$re//) {
    	my ($ssyl, $sdelim) = ($1, $2);
    	$ssyl =~ tr/（）/()/; # change the fake parens back
    	if ($ssyl =~ s/\|// && @{$self->{syls}}) {	# make an exception for the overriding delimiter, but ONLY if there's something in the array already
    	    my $olddelim = pop @{$self->{delims}};
    	    $self->{syls}[-1] .= $olddelim;
    	    $self->{syls}[-1] .= $ssyl;
    	} else {
	    push(@{$self->{syls}}, $ssyl);
	}
	push(@{$self->{delims}}, $sdelim);
	print "Match: $ssyl\tResidue: $word\n" 
	    if ($self->{debug});
    }
    # $self->{syls}[0] = $self->{prefix} . $self->{syls}[0] if $self->{prefix}; # special case for beginning hyphen
    $self->{residue} = $word;
    $self->{num_syls} = scalar(@{$self->{syls}});
    if ($word) {
	return 0;
    } else {
	return 1;
    }
}

=cut

=head2 fit_word_to_analysis($self, $analysis, $word)

Find a grammar that will divide $word into the same number of
constitutents present in $analysis and save the resulting segmentation
in class members 'syls' and 'tags'.

=cut

sub fit_word_to_analysis {
    my ($self, $analysis, $word) = @_;
    print "Word: $word\n"
	if ($self->{debug});
    @{$self->{tags}} = split(',', $analysis, -1);
    my $num_tags = scalar(@{$self->{tags}});
    my $satisfied = 0;
    for my $re_name (@{$self->{re_order}}) {
	$self->{grammar_used} = $re_name;
	my $re = $self->{regexes}{$re_name};
		print "RE Name: $re_name\n" #"RE: $re\n\n" 
	    if ($self->{debug});
	if ($self->syllabify_per_regex($re, $word) 
	    and $self->{num_syls} == $num_tags) {
	    $satisfied = 1;
	    last;
	}
    }
    return $satisfied;
}


=head2 split_form($self, $word)


=cut

sub split_form {
    my ($self, $word) = @_;
    print "Word: $word\n"
        if ($self->{debug});
    my $num_tags = scalar(@{$self->{tags}});
    for my $re_name (@{$self->{re_order}}) {
        $self->{grammar_used} = $re_name;
        my $re = $self->{regexes}{$re_name};
        print "RE Name: $re_name\n" #"RE: $re\n\n" 
            if ($self->{debug});
        $self->syllabify_per_regex($re, $word);
        last if ($self->{num_syls} > 1);
    }
}


=cut

=head2 get_xml_format($self, $element, $attribute)

Returns an XML string based upon the current contents of the members
'tags', 'syls', and 'delims'. The syllables are enclosed in elements
with the name $element and with an attribute named $attribute set to
the value of the corresponding $tag. The XML string is a "mixed" text
element--delimiters are intersperced with elements.

=cut

sub get_xml_format {
    my ($self, $element, $attribute) = @_;
    my ($xml, $syl, $delim, $tag) = ('', '', '', '');
    my @syls = @{$self->{syls}};
    my @delims = @{$self->{delims}};
    my @tags = @{$self->{tags}};
    $xml = $self->{prefix};
    for $syl (@syls) {
	$delim = shift(@delims) || '';
	$tag   = shift(@tags)   || '';
	$xml .= "<$element $attribute='$tag'>$syl</$element>$delim";
    }
    return $xml;
}

sub get_xml_mark_cog {
    my ($self, $stedtno) = @_;
    my ($xml, $syl, $delim, $tag) = ('', '', '', '');
    my @syls = @{$self->{syls}};
    my @delims = @{$self->{delims}};
    my @tags = @{$self->{tags}};
    $xml = $self->{prefix};
    for $syl (@syls) {
	$delim = shift(@delims) || '';
	$tag   = shift(@tags)   || '';
	if ($tag eq $stedtno) {
	    $xml .= "<cognate>$syl</cognate>$delim";
	} else {
	    $xml .= "$syl$delim";
	}
    }
    return $xml;
}

sub get_brace_mark_cog {
    my ($self, $stedtno) = @_;
    my ($xml, $syl, $delim, $tag) = ('', '', '', '');
    my @syls = @{$self->{syls}};
    my @delims = @{$self->{delims}};
    my @tags = @{$self->{tags}};
    $xml = $self->{prefix};
    for $syl (@syls) {
	$delim = shift(@delims) || '';
	$tag   = shift(@tags)   || '';
	if ($tag eq $stedtno) {
	    $xml .= "{$syl}$delim";
	} else {
	    $xml .= "$syl$delim";
	}
    }
    return $xml;
}


1;
