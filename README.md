# Koha plugin - Incremental Pattern Barcode generator

This plugin makes cataloguing an item painless. It will make Koha request a
'fresh' barcode on saving the item.

It will only work if the field is not populated already.

It allows you to define incremental barcodes with a prefix and a suffix.

Originally developed by Theke Solutions, forked and extended by Hypernova Oy.

## Install

Download the latest _.kpz_ file from the _Project / Releases_ page

## Configuration

System preference "autoBarcode" must be "not generated automatically." (FIXME)

1. Go to staff client /cgi-bin/koha/plugins/plugins-home.pl
2. Click Actions -> Configure
3. Set pattern, e.g. PRE000000000SUF where
"PRE" is desired prefix, "SUF" is desired SUF, and 000000000000 represents
the amount of numbers your barcode has (length of barcode excluding prefix
and suffix).
