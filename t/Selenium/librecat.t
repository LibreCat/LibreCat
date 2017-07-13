use strict;
use warnings;
use Selenium::Remote::Driver;
use Test::More;


sub test_header {
    my $results = $main::driver->find_element('html/body/header/nav/div[1]/a', 'xpath');
    is($results->get_text(), '', 'header - Icon link text');
    is($results->get_attribute('title'), 'PUB home', ' - Icon link title');
    is($results->get_attribute('href'), 'http://demo.librecat.org/', ' - home link');

    $results = $main::driver->find_element('html/body/header/nav/div[2]/ul[1]/li/a', 'xpath');
    is($results->get_text(), 'Home', 'header - Home link text');
    is($results->get_attribute('href'), 'http://demo.librecat.org/', ' - home link');

    my @results = $main::driver->find_elements('helpme', 'class');
    my $hasSearchForm = !($main::driver->get_current_url() eq 'http://demo.librecat.org/'
    || $main::driver->get_current_url() eq 'http://demo.librecat.org/person'
    || $main::driver->get_current_url() eq 'http://demo.librecat.org/project'
    || $main::driver->get_current_url() eq 'http://demo.librecat.org/department');

    if (!$hasSearchForm) {
        is(@results, 3, 'header - helpme ' . $main::driver->get_current_url());
    }
    else {
        is(@results, 4, 'header - helpme ' . $main::driver->get_current_url());
    }

    is($results[0]->get_attribute('title'), 'PUB home', ' - header - helpme 1');
    is($results[1]->get_attribute('title'), 'Backend<br>start page', ' - header - helpme 2');
    is($results[2]->get_attribute('title'), 'Change language', ' - header - helpme 3');

    if ($hasSearchForm) {
        is($results[3]->get_tag_name(), 'form', ' - header - helpme 4');
        is($results[3]->get_attribute('data-placement'), 'left', ' - header - helpme 4');
        is($results[3]->get_attribute('title'), 'Search this publication list.', ' - header - helpme 4');
    }

    my $link = $main::driver->find_child_element($results[2], "./a", 'xpath');
    is($link->get_attribute('href'), 'http://demo.librecat.org/set_language?lang=de', ' - header - change language link');

    $results = $main::driver->find_element('glyphicon-log-out', 'class');
    $link = $main::driver->find_child_element($results, "./parent::a", 'xpath');
    is($link->get_attribute('href'), 'http://demo.librecat.org/login', ' - header - login link');
}

sub test_footer {
    my $results = $main::driver->find_element('panel-footer', 'class');
    my $footer = $main::driver->find_child_element($results, 'col-sm-5', 'class');
    is($footer->get_text(), 'Powered by LibreCat', 'footer');
}

sub test_home {
    $main::driver->get('http://demo.librecat.org/');
    is($main::driver->get_title, '', 'title is empty');

    test_header();
    test_footer();

    my $results = $main::driver->find_element('active', 'class');
    is($results->get_text(), 'Home', 'on home tab');

    $results = $main::driver->find_element('.//*[@id="home"]/div/div/div[2]/div/p[1]/span[2]', 'xpath');
    is($results->get_text(), '17', 'number of publications');
    is($results->get_attribute('class'), 'statalign', ' - check attribute');
    $results = $main::driver->find_element('.//*[@id="home"]/div/div/div[2]/div/p[1]/span[1]', 'xpath');
    is($results->get_attribute('class'), 'fa fa-check fa-1x', ' - check sign');

    $results = $main::driver->find_element('.//*[@id="home"]/div/div/div[2]/div/p[2]/span[2]', 'xpath');
    is($results->get_text(), '1', 'number of data publications');
    is($results->get_attribute('class'), 'statalign', ' - check attribute');
    $results = $main::driver->find_element('.//*[@id="home"]/div/div/div[2]/div/p[2]/span[1]', 'xpath');
    is($results->get_attribute('class'), 'fa fa-check fa-1x', ' - check sign');

    $results = $main::driver->find_element('.//*[@id="home"]/div/div/div[2]/div/p[3]/span[2]', 'xpath');
    is($results->get_text(), '0', 'number of open access publications');
    is($results->get_attribute('class'), 'statalign', ' - check attribute');
  $results = $main::driver->find_element('.//*[@id="home"]/div/div/div[2]/div/p[3]/span[1]', 'xpath');
  is($results->get_attribute('class'), 'fa fa-check fa-1x', ' - check sign');

  $results = $main::driver->find_element('.//*[@id="home"]/div/div/div[2]/div/p[4]/span[2]', 'xpath');
  is($results->get_text(), '1584', 'number of projects');
  is($results->get_attribute('class'), 'statalign', ' - check attribute');
  $results = $main::driver->find_element('.//*[@id="home"]/div/div/div[2]/div/p[4]/span[1]', 'xpath');
  is($results->get_attribute('class'), 'fa fa-check fa-1x', ' - check sign');

  $results = $main::driver->find_element('indexTab', 'id');
  is($results->get_tag_name(), 'ul', 'index tab');
  is($results->get_attribute('class'), 'nav nav-tabs', 'index tab class');

  my @tabs = $results = $main::driver->find_child_elements($results, 'li', 'xpath');
  is((scalar @{$tabs[0]}), 6, 'home - size of tabs');
  is($tabs[0][0]->get_attribute('class'), 'active', 'home - size of tabs');
  testTabItem($tabs[0][0], 'http://demo.librecat.org/', 'Home', 'active');
  testTabItem($tabs[0][1], 'http://demo.librecat.org/publication', 'Publications');
  testTabItem($tabs[0][2], 'http://demo.librecat.org/data', 'Data Publications');
  testTabItem($tabs[0][3], 'http://demo.librecat.org/person', 'Authors');
  testTabItem($tabs[0][4], 'http://demo.librecat.org/project', 'Projects');
  testTabItem($tabs[0][5], 'http://demo.librecat.org/department', 'Departments');

  $results = $main::driver->find_element('h1', 'tag_name');
  is($results->get_text(), 'Publications at LibreCat University', 'home - title');

}

sub testTabItem {
  my $tab = shift;
  my $url = shift;
  my $label = shift;
  my $class = shift;
  $class |= '';

  is($tab->get_tag_name(), 'li', 'home - tabs - tag');
  is($tab->get_attribute('class'), $class, 'home - tabs - class');
  my $link = $main::driver->find_child_element($tab, 'a');
  is($link->get_attribute('href'), $url, 'home - tabs - url');
  is($link->get_text(), $label, 'home - tabs - label');
}

sub test_search {
  my $term = shift;
  my $expected = shift;

  $main::driver->get('http://demo.librecat.org/');
  test_header();
  test_footer();

  my $query = $main::driver->find_element('q', 'name');
  $query->send_keys($term);

  my $send_search = $main::driver->find_element('btn-default', 'class');
  $send_search->click;

  $main::driver->set_implicit_wait_timeout(2000);
  my $results = $main::driver->find_element('margin-top0', 'class');
  is($results->get_text(), $expected, sprintf('searching for "%s"', $term));

  $results = $main::driver->find_element('active', 'class');
  is($results->get_text(), 'Publications', 'on publications tab');
}

sub test_publication {
  $main::driver->get('http://demo.librecat.org/publication');
  test_header();
  test_footer();
}

sub test_data_publication {
  $main::driver->get('http://demo.librecat.org/data');
  test_header();
  test_footer();
}

sub test_author {
  $main::driver->get('http://demo.librecat.org/person');
  test_header();
  test_footer();
}

sub test_project {
  $main::driver->get('http://demo.librecat.org/project');
  test_header();
  test_footer();
}

sub test_department {
  $main::driver->get('http://demo.librecat.org/department');
  test_header();
  test_footer();

  my $publ = $main::driver->find_element('publ', 'id');
  my @links = $main::driver->find_child_elements($publ, 'descendant::a');
  my @urls = ();
  is(scalar @links, 9, 'departments');
  test_link($links[0], 'http://demo.librecat.org/publication?cql=department=1', 'LibreCat University');
  push(@urls, [$links[0]->get_attribute('href'), get_count($links[0])]);
  test_link($links[1], 'http://demo.librecat.org/publication?cql=department=9999',
    'Department of Mathematics');
  push(@urls, [$links[1]->get_attribute('href'), get_count($links[1])]);
  test_link($links[2], 'http://demo.librecat.org/publication?cql=department=9998',
    'Department of Mathematics -> Analysis Group');
  push(@urls, [$links[2]->get_attribute('href'), get_count($links[2])]);
  test_link($links[3], 'http://demo.librecat.org/publication?cql=department=99991',
    'Department of Mathematics -> Applied Mathematics');
  push(@urls, [$links[3]->get_attribute('href'), get_count($links[3])]);
  test_link($links[4], 'http://demo.librecat.org/publication?cql=department=99992',
    'Department of Mathematics -> Applied Mathematics -> Game Theory');
  push(@urls, [$links[4]->get_attribute('href'), get_count($links[4])]);
  test_link($links[5], 'http://demo.librecat.org/publication?cql=department=9997',
    'Department of Physics');
  push(@urls, [$links[5]->get_attribute('href'), get_count($links[5])]);
  test_link($links[6], 'http://demo.librecat.org/publication?cql=department=9996',
    'Department of Physics -> Relativity Theory Group');
  push(@urls, [$links[6]->get_attribute('href'), get_count($links[6])]);
  # test_link($links[7], 'http://demo.librecat.org/publication?cql=department=2685177', 'Fakult�t f�r Biologie'); #'Fakultät für Biologie');
  push(@urls, [$links[7]->get_attribute('href'), get_count($links[7])]);
  test_link($links[8], 'http://demo.librecat.org/publication?cql=department=10085',
    'University Library');
  push(@urls, [$links[8]->get_attribute('href'), get_count($links[8])]);

  # foreach my $i (0..$#urls) {
  #   testDepartment($urls[$i][0], $urls[$i][1]);
  # }
}

sub test_link {
    my ($link, $url, $label) = @_;

    is ($link->get_attribute('href'), $url, 'link url');
    is ($link->get_text(), $label, 'link label');
}

sub get_count {
    my $link = shift;

    my $parent = $main::driver->find_child_element($link, 'parent::*');
    ($parent->get_text() =~ m/(\d+)$/) ? return $1 : return 0;
}

# main: call the test routines
our $driver = Selenium::Remote::Driver->new(browser_name => 'chrome');

test_home();
test_search('einstein', '2 Publications');
test_search('', '17 Publications');
test_publication();
test_data_publication();
test_author();
test_project();
test_department();

$driver->quit;

done_testing();
