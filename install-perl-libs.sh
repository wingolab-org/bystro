cpan install Mouse
cpan install Path::Tiny
cpan install namespace::autoclean
cpan install DDP
cpan install YAML::XS
cpan install Getopt::Long::Descriptive
cpan install Types::Path::Tiny
cpan install MCE::Shared
cpan install List::MoreUtils
cpan install Log::Fast
cpan install Parallel::ForkManager
cpan install Cpanel::JSON::XS
cpan install Mouse::Meta::Attribute::Custom::Trait::Array
cpan install Net::HTTP
cpan install Search::Elasticsearch
cpan install Math::SigFigs
# cpan install Data::MessagePack
cpan install LMDB_File
cpan install Sort::XS
cpan install Hash::Merge::Simple
cpan install PerlIO::utf8_strict
cpan install PerlIO::gzip
cpan install MouseX::SimpleConfig
cpan install MouseX::ConfigFromFile
cpan install MouseX::Getopt
cpan install Archive::Extract
cpan install DBI
# Needed for fetching SQL (Utils::SqlWriter::Connection)
cpan install DBD::mysql
cpan install IO/FDPass.pm
cpan install Beanstalk::Client

# Custom branch of msgpack-perl that uses latest msgpack-c and
# allows prefer_float32 flag for 5-byte float storage
git clone --recursive https://github.com/akotlar/msgpack-perl.git && cd msgpack-perl
perl Makefile.PL
make test
sudo make install
cd ../ && rm -rf msgpack-perl