package MicroStrategy::Cleanse;

use warnings;
use strict;

=head1 NAME

MicroStrategy::Cleanse - The great new MicroStrategy::Cleanse!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

    use MicroStrategy::Cleanse;
    
    my $ref = [ $first_name, $mi, $last_name ];
    MicroStrategy::Cleanse->strip_n_ucase($ref);
    MicroStrategy::Cleanse->blank_to_undef($ref);
    ($first_name, $mi, $last_name) = @$ref;

    ...

=head1 EXPORT

Nothing exported by default.

=head1 FUNCTIONS

=head2 strip_n_ucase

Removes digits, text in parens, periods, beginning whitespace, and ending whitespace.  
Uppercases string.  Collapses whitespace.


=cut

#s/\p{P}/ /g; # change punct to spaces
#s/\p{Pd}/ /g; #chg dashes and hyphens to spaces
sub strip_n_ucase  { 
	my $self = shift;
	for(@$self) {
	        next unless defined($_);	
		s/\d+//g; #remove digits
		s/[(](.*)[)]//g; #remove text in parens
		s/(\w+)/\U$1/g; #uppercase words 
		s/([.])//g; #remove periods
		s/\s+/ /g; #collapse whitespace
		s/^\s+//; #remove beginning whitespace
		s/\s+$//; #remove trailing whitespace
	}
}





=head3 blank_to_undef

Returns undef for non-words.

=cut

sub blank_to_undef { 
	my $self = shift;
	my $ref = shift; 
	for(@$ref) { 
		next unless defined($_); 
		unless (/\w/) { $_ = undef; } 
	} 
}

=head1 AUTHOR

Craig Grady, C<< <cgrady357 at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-microstrategy-cleanse at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=MicroStrategy-Cleanse>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc MicroStrategy::Cleanse


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=MicroStrategy-Cleanse>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/MicroStrategy-Cleanse>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/MicroStrategy-Cleanse>

=item * Search CPAN

L<http://search.cpan.org/dist/MicroStrategy-Cleanse>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2008 Craig Grady, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of MicroStrategy::Cleanse
