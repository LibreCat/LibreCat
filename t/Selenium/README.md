# Selenium Tests

In order to run selenium you have to

1. download [selenium-server-standalone-3.2.0.jar](http://www.seleniumhq.org/download/), and put a place which is accessible from your `$PATH`
2. download [Chrome driver](https://sites.google.com/a/chromium.org/chromedriver/) for Selenium
3. download [Firefox ("gecko") driver](https://github.com/mozilla/geckodriver/releases) for Selenium
4. run selenium standalone server

you can issue this command:

```
java \
  -Dwebdriver.chrome.driver="/path/to/chromedriver" \
  -Dwebdriver.gecko.driver="/path/to/geckodriver" \
  -Dwebdriver.firefox.driver="/path/to/geckodriver" \
  -Dwebdriver.firefox.marionette=true \
  -Dwebdriver.firefox.bin="/usr/bin/firefox" \
  -jar /path/to/selenium-server-standalone-3.2.0.jar

```

or you can use a script:

a. `mv run-selenium-template.sh run-selenium.sh`
b. replace the paths in the file
c. `./run-selenium.sh`


If Selenium is running, on a different window you can run the tests:

1. install `Selenium::Remote::Driver` Perl module

```
cpanm Selenium::Remote::Driver
```

2. run the tests

```
perl -wT librecat.t
```

