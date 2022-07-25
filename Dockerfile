FROM alpine:latest as build

WORKDIR /build

RUN apk add python3 py3-pip
COPY . /build
RUN pip3 wheel -r requirements.txt --wheel-dir=/build/wheels

FROM alpine:latest as run
COPY --from=build /build/wheels .
RUN apk add python3 py3-pip
RUN pip3 install --no-index *.whl
COPY . .
CMD gunicorn --bind=0.0.0.0 -w 4 wsgi:app