#
# Dockerfile to run the awesome Institutional Repository PUB
# docker build -t pub/repo .
# docker run -d -p 5000:80 -t pub/repo
#

FROM vpeil/debian
MAINTAINER Vitali Peil

COPY . /code
WORKDIR /code

# perl prereqs
RUN cpanm --installdeps .

# expose port
EXPOSE 5000
