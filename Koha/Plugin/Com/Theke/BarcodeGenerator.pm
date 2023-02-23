package Koha::Plugin::Com::Theke::BarcodeGenerator;

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# This program comes with ABSOLUTELY NO WARRANTY;

use Modern::Perl;

use base qw(Koha::Plugins::Base);

use Mojo::JSON qw(decode_json);
use YAML;
use Try::Tiny;

our $VERSION = "22.11.01.2";

our $metadata = {
    name            => 'Barcode generator',
    author          => 'Tomás Cohen Arazi / Lari Taskula',
    date_authored   => '2019-08-14',
    date_updated    => "2023-02-23",
    minimum_version => '18.11.00.000',
    maximum_version => undef,
    version         => $VERSION,
    description     => 'This plugin adds a route to get fresh barcodes',
};

sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}

sub generate_incremental_pattern_barcode {
    my ( $self, $params ) = @_;

    my $yaml;
    try {
        $yaml = YAML::XS::Load($self->retrieve_data('pattern'));
    } catch {
        return "ERR_YAML_PARSE.$@";
    };
    my $pattern = $yaml->{$params->{'library_id'}} ? $yaml->{$params->{'library_id'}} : $yaml->{'Default'};
    my $barcode = $pattern;

    return 'ERR_CANNOT_PARSE_PATTERN' unless ($pattern =~ /^([^0]*)(0+)([^0]*)/);

    $pattern = {
        prefix => $1 // '',
        numberLength => length($2) // 0,
        suffix => $3 // '',
    };

    my $id = 0;
    my $dbh = C4::Context->dbh;

    my $prefix = $pattern->{prefix};
    my $suffix = $pattern->{suffix};
    my $prefixLength = length($prefix);
    my $suffixLength = length($suffix);
    my $substrLength = (length($barcode)-$prefixLength-$suffixLength);
    my $sth = $dbh->prepare("SELECT MAX(CAST(SUBSTRING(barcode,($prefixLength+1),$substrLength) AS signed)) AS number FROM items WHERE barcode REGEXP ?");
    $sth->execute("^".$prefix."(\\d{".$pattern->{numberLength}."})".$suffix.'$');
    while (my ($count)= $sth->fetchrow_array) {
        $id = $count if $count;
    }

    $id++;
    my $zeroesNeeded = $pattern->{numberLength} - length($id);
    $barcode = $prefix . substr('00000000000000000000', 0, $zeroesNeeded) . $id . $suffix;

    return $barcode;
}

sub intranet_js {
     my ( $self ) = @_;

     return q%
         <script>
            $(document).ready(function(){
                $('#cataloguing_additem_newitem input[type="submit"]').click(function() {
                    var submit = this;
                    var barcode = $("div#subfield952p input[name=items\\\\.barcode]");
                    var library_id = $("div#subfield952a select[name=items\\\\.homebranch]");

                    // Koha 21.05 and below support BEGIN
                    $('*[name="field_value"]').each(function() {
                        if(/tag_952_subfield_p/.test(this.id)) {
                            barcode = this;
                        }
                        if(/tag_952_subfield_a/.test(this.id)) {
                            library_id = this;
                        }
                    });
                    // Koha 21.05 and below support END

                    if(!barcode.length || $(barcode).val()) return true;
                    $.ajax('/api/v1/contrib/barcode-generator/barcode?library_id='+$(library_id).val())
                    .then(function(res) {
                        $(barcode).val(res.barcode);
                        submit.click();
                    })
                    .fail(function(err) {
                        console.log(err);
                    })

                    return false;
                })
            })
         </script>
     %;
}

sub api_routes {
    my ( $self, $args ) = @_;

    my $spec_str = $self->mbf_read('openapi.json');
    my $spec     = decode_json($spec_str);

    return $spec;
}

sub api_namespace {
    my ( $self ) = @_;
    
    return 'barcode-generator';
}

sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('save') ) {
        my $template = $self->get_template( { file => 'configure.tt' } );

        ## Grab the values we already have for our settings, if any exist
        $template->param(
            pattern => $self->retrieve_data('pattern'),
        );

        $self->output_html( $template->output() );
    }
    else {
        $self->store_data(
            {
                pattern => $cgi->param('pattern'),
            }
        );
        $self->go_home();
    }
}

sub uninstall {}

1;
