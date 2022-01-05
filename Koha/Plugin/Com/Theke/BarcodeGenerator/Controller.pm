package Koha::Plugin::Com::Theke::BarcodeGenerator::Controller;

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

use Mojo::Base 'Mojolicious::Controller';

use C4::Barcodes::ValueBuilder;

use Koha::DateUtils;
use Koha::Libraries;

=head1 Koha::Plugin::Com::Theke::BarcodeGenerator::Controller

A class implementing the controller methods for the barcode generating endpoints

=head2 Class methods

=head3 get_barcode

Method that returns the next barcode based on the configuration

=cut

sub get_barcode {
    my $c = shift->openapi->valid_input or return;

    my $library_id = $c->validation->param('library_id');

    my $autoBarcodeType = C4::Context->preference("autoBarcode");

    my $barcodegenerator = Koha::Plugin::Com::Theke::BarcodeGenerator->new;

    my $barcode;

    my $dt     = Koha::DateUtils::dt_from_string;
    my $params = {
        year => $dt->year,
        mon  => $dt->month,
        day  => $dt->day
    };

    if ( $autoBarcodeType eq 'annual' ) {
        ($barcode) = C4::Barcodes::ValueBuilder::annual::get_barcode($params);
    }
    elsif ( $autoBarcodeType eq 'EAN13' ) {
        ($barcode) = C4::Barcodes::ValueBuilder::EAN13::get_barcode($params);
    }
    elsif ( $autoBarcodeType eq 'incremental' ) {
        ($barcode) = C4::Barcodes::ValueBuilder::incremental::get_barcode($params);
    }
    elsif ( $autoBarcodeType eq 'hbyymmincr' ) {
        ($barcode) = C4::Barcodes::ValueBuilder::hbyymmincr::get_barcode($params);
        #my $library_id = $body->{library_id};

        unless ( $library_id ) {
            return $c->render(
                status  => 400,
                openapi => { error => "library_id mandatory for hbyymmincr algorithm" }
            );
        }
    }
    elsif ( $autoBarcodeType eq 'OFF' ) {
        $barcode = $barcodegenerator->generate_incremental_pattern_barcode();

        if ( $barcode eq 'ERR_CANNOT_PARSE_PATTERN' ) {
            return $c->render(
                status  => 400,
                openapi => { error => "Cannot parse the plugin barcode battern" }
            );
        }
    }
    else {
        return $c->render( status => 400, openapi => { error => "Unsupported barcode algorithm" } );
    }

    if ($barcode) {
        return $c->render( status => 200, openapi => { barcode => $barcode } );
    }
    else {
        return $c->render( status => 500, openapi => { error => "Unhandled exception" } );
    }
}

1;
