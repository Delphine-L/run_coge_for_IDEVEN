# NOTE: Derived from blib/lib/Data/Validate/URI.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Data::Validate::URI;

#line 344 "blib/lib/Data/Validate/URI.pm (autosplit into blib/lib/auto/Data/Validate/URI/is_https_uri.al)"
# -------------------------------------------------------------------------------


sub is_https_uri{
	my $self = shift if ref($_[0]); 
	my $value = shift;
	
	return is_http_uri($value, 1);
}

# end of Data::Validate::URI::is_https_uri
1;
