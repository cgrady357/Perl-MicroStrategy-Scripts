package Cleanse;


#s/\p{P}/ /g; # change punct to spaces
#s/\p{Pd}/ /g; #chg dashes and hyphens to spaces

sub strip_n_ucase  { 
	my $self = shift;
	my $ref = ref($self);
	if ($ref == "HASH" ) { 	
		for(keys %$self) { 
			s/\d+//g; #remove digits
			s/[(](.*)[)]//g; #remove text in parens
			s/(\w+)/\U\1/g; #uppercase words 
			s/([.])//g; #remove periods
			s/\s+/ /g; #collapse whitespace
			s/^\s+//; #remove beginning whitespace
			s/\s+$//; #remove trailing whitespace
		}
	}
	else {
		for(@$self) { 
			s/\d+//g; #remove digits
			s/[(](.*)[)]//g; #remove text in parens
			s/(\w+)/\U\1/g; #uppercase words 
			s/([.])//g; #remove periods
			s/\s+/ /g; #collapse whitespace
			s/^\s+//; #remove beginning whitespace
			s/\s+$//; #remove trailing whitespace
		}
	}
}

sub display {
	my $self = shift;
        my @keys = @_ ? @_ : sort keys %$self;
        foreach $key (@keys) {
            print "\t$key => $self->{$key}\n";
        }
    }

sub blank_to_undef { my $ref = shift; for(@$ref) { unless (/\w/) {$_ = undef;} } }

1;
