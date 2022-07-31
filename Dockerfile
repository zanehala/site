FROM alpine:latest as build

WORKDIR /build

RUN apk add python3 py3-pip hugo
COPY . /build
RUN pip3 wheel -r requirements.txt --wheel-dir=/build/wheels
RUN hugo

FROM alpine:latest as run
COPY --from=build /build/wheels .
RUN apk add python3 py3-pip && \
    pip3 install --no-index *.whl && \
    mkdir /public
COPY main.py wsgi.py ./
COPY --from=build /build/public /public

CMD gunicorn --bind=0.0.0.0 -w 4 wsgi:app