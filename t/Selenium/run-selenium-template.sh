# TODO:
# replace '/path/to/' with the actual paths in your system

java \
  -Dwebdriver.chrome.driver="/path/to/chromedriver" \
  -Dwebdriver.gecko.driver="/path/to/geckodriver" \
  -Dwebdriver.firefox.driver="/path/to/geckodriver" \
  -Dwebdriver.firefox.marionette=true \
  -Dwebdriver.firefox.bin="/usr/bin/firefox" \
  -jar /path/to/selenium-server-standalone-3.2.0.jar
