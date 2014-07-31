#
# Dockerfile to run the awesome Institutional Repository PUB
# docker build -t pub/repo .
# docker run -d -p 5000:80 -t pub/repo
# 

FROM vpeil/debian-elastic-mongo
MAINTAINER Vitali Peil

# system prereqs
RUN apt-get update
RUN apt-get install -y build-essential
RUN apt-get install -y libexpat1-dev 
RUN apt-get install -y libssl-dev
RUN apt-get install -y libxml2-dev
RUN apt-get install -y git
RUN apt-get install -y cpanminus

# install perl prereqs
cpanm cpanfile

# expose port
EXPOSE 5000

# start webapp
CMD starman --listen :5000 --preload-app --app bin/app.pl
