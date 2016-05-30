package Catmandu::Fix::start_end_year_from_date;

use Catmandu::Sane;
use Moo;

sub fix {
    my ( $self, $pub ) = @_;
    
    if ($pub->{startYear} and $pub->{startYear} =~ /(\d{4})-\d{2}-\d{2}/){
        $pub->{startDate} = $pub->{startYear};
        $pub->{startYear} = $1;
    }
    elsif ($pub->{startYear} and $pub->{startYear} =~ /\d{2}.\d{2}.(\d{4})/){
        $pub->{startDate} = $pub->{startYear};
        $pub->{startYear} = $1;
    }
    elsif ($pub->{startYear} and $pub->{startYear} =~ /^(\d{4})$/){
        $pub->{startDate} = $pub->{startYear};
        $pub->{startYear} = $1;
    }
    
    if ($pub->{endYear} and $pub->{endYear} =~ /(\d{4})-\d{2}-\d{2}/){
        $pub->{endDate} = $pub->{endYear};
        $pub->{endYear} = $1;
    }
    elsif ($pub->{endYear} and $pub->{endYear} =~ /\d{2}.\d{2}.(\d{4})/){
        $pub->{endDate} = $pub->{endYear};
        $pub->{endYear} = $1;
    }
    elsif ($pub->{endYear} and $pub->{endYear} =~ /^(\d{4})$/){
        $pub->{endDate} = $pub->{endYear};
        $pub->{endYear} = $1;
    }
    
    $pub;
}

1;