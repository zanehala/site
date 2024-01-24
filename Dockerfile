FROM alpine:latest as build

WORKDIR /build

RUN apk add python3 py3-pip hugo
COPY . /build
RUN pip3 wheel -r requirements.txt --wheel-dir=/build/wheels
RUN hugo

FROM alpine:latest as run

COPY --from=build /build/wheels .
RUN apk add --no-cache python3 py3-pip && \
    python3 -m venv .run && \
    source .run/bin/activate && \
    pip3 install --no-index *.whl && \
    mkdir /public
COPY main.py wsgi.py config.py ./
COPY --from=build /build/public /public
RUN chmod 777 -R /public

ENV PROMETHEUS_MULTIPROC_DIR /tmp
ENV prometheus_multiproc_dir /tmp

CMD gunicorn -c config.py --bind=0.0.0.0:80 --log-level debug -w 4 wsgi:app
