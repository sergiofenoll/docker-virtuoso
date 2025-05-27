FROM ubuntu:22.04 AS builder

ARG TARGETPLATFORM

# Set Virtuoso commit SHA to Virtuoso 7.2.15 release (2025-05-21)
ARG VIRTUOSO_COMMIT=bae7c13af8f4cb5ca0ecbaa9c4cda7f1b5f47f07

RUN apt-get update
RUN apt-get install -y build-essential autotools-dev autoconf automake net-tools libtool \
                       flex bison gperf gawk m4 libssl-dev libreadline-dev openssl wget \
                       python-is-python3 bzip2

# Build libraries for GeoSPARQL support according to https://github.com/openlink/virtuoso-opensource/blob/10b2678ca4a801e75bc654a656017c3cfc0d8760/README.GeoSPARQL.md
# proj4
WORKDIR /
RUN case "$TARGETPLATFORM" in \
      "linux/arm64") echo "not building proj4 on ARM platform" ;; \
      *) \
        wget https://download.osgeo.org/proj/proj-4.9.3.tar.gz \
        tar xzf proj-4.9.3.tar.gz \
        cd proj-4.9.3 \
        ./configure \
        make \
        make install ;; \
    esac

# geos
WORKDIR /
RUN case "$TARGETPLATFORM" in \
      "linux/arm64") echo "not building geos on ARM platform" ;; \
      *) \
        wget http://download.osgeo.org/geos/geos-3.5.1.tar.bz2 \
        bzip2 -d geos-3.5.1.tar.bz2 \
        tar xf geos-3.5.1.tar \
        cd geos-3.5.1 \
        ./configure \
        make \
        make check \
        make install \
        ldconfig ;; \
    esac

WORKDIR /
RUN wget https://github.com/openlink/virtuoso-opensource/archive/${VIRTUOSO_COMMIT}.tar.gz
RUN tar xzf ${VIRTUOSO_COMMIT}.tar.gz
WORKDIR virtuoso-opensource-${VIRTUOSO_COMMIT}
# Build virtuoso from source
RUN ./autogen.sh
RUN case "$TARGETPLATFORM" in \
      "linux/amd64") \
        export CFLAGS="-O2 -m64" &&\
       ./configure \
          --enable-proj4=/usr/local/lib \
          --enable-geos=/usr/local/lib \
          --enable-shapefileio \
          --disable-graphql \
          --disable-bpel-vad \
          --enable-conductor-vad \
          --enable-fct-vad \
          --disable-dbpedia-vad \
          --disable-demo-vad \
          --disable-isparql-vad \
          --disable-ods-vad \
          --disable-sparqldemo-vad \
          --disable-syncml-vad \
          --disable-tutorial-vad \
          --with-readline --program-transform-name="s/isql/isql-v/" ;; \
      "linux/arm64") \
        export CFLAGS="-O2" &&\
       ./configure \
          --disable-proj4 \
          --disable-geos \
          --disable-shapefileio \
          --disable-graphql \
          --disable-bpel-vad \
          --enable-conductor-vad \
          --enable-fct-vad \
          --disable-dbpedia-vad \
          --disable-demo-vad \
          --disable-isparql-vad \
          --disable-ods-vad \
          --disable-sparqldemo-vad \
          --disable-syncml-vad \
          --disable-tutorial-vad \
          --with-readline --program-transform-name="s/isql/isql-v/" ;; \
      *) \
        export CFLAGS="-O" &&\
       ./configure \
          --enable-proj4=/usr/local/lib \
          --enable-geos=/usr/local/lib \
          --enable-shapefileio \
          --disable-graphql \
          --disable-bpel-vad \
          --enable-conductor-vad \
          --enable-fct-vad \
          --disable-dbpedia-vad \
          --disable-demo-vad \
          --disable-isparql-vad \
          --disable-ods-vad \
          --disable-sparqldemo-vad \
          --disable-syncml-vad \
          --disable-tutorial-vad \
          --with-readline --program-transform-name="s/isql/isql-v/" ;; \
    esac
RUN make && make install


FROM ubuntu:22.04
COPY --from=builder /usr/local/virtuoso-opensource /usr/local/virtuoso-opensource
COPY --from=builder /usr/local/lib/ /usr/local/lib
RUN apt-get update && apt-get install -y libssl-dev crudini
# Add Virtuoso bin to the PATH
ENV PATH=/usr/local/virtuoso-opensource/bin/:$PATH

# Add Virtuoso config
COPY virtuoso.ini /virtuoso.ini

# Add sql scripts
COPY dump_nquads_procedure.sql /docker-virtuoso/dump_nquads_procedure.sql
COPY add_cors.sql /docker-virtuoso/add_cors.sql

# Add Virtuoso log cleaning script
COPY clean-logs.sh /clean-logs.sh

# Add startup script
COPY virtuoso.sh /virtuoso.sh

RUN ln -s /usr/local/virtuoso-opensource/var/lib/virtuoso/ /var/lib/virtuoso \
    && ln -s /var/lib/virtuoso/db /data

# Add mu scripts
COPY ./scripts/ /app/scripts/

WORKDIR /data
EXPOSE 8890
EXPOSE 1111

CMD ["/bin/bash", "/virtuoso.sh"]
