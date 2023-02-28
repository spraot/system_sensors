FROM python:3.11-slim-bullseye

ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

RUN apt-get update \
    & apt-get -y upgrade

RUN mkdir -p /app/config
RUN mkdir -p /app/host

ENV YES_YOU_ARE_IN_A_CONTAINER=True

WORKDIR /app

COPY requirements.txt ./
RUN pip install -r requirements.txt

COPY src/* ./
RUN chmod a+x /app/bin/system_sensors.sh

CMD /app/bin/system_sensors.sh
