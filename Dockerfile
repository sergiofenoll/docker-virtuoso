FROM ubuntu:22.04 as builder

# Set Virtuoso commit SHA to Virtuoso 7.2.9 release (2023-02-27)
ARG VIRTUOSO_COMMIT=795af34a7287f064effd91ed251e6bb711f1f5ee

RUN apt-get update
RUN apt-get install -y build-essential autotools-dev autoconf automake net-tools libtool \
                       flex bison gperf gawk m4 libssl-dev libreadline-dev openssl wget
RUN wget https://github.com/openlink/virtuoso-opensource/archive/${VIRTUOSO_COMMIT}.tar.gz
RUN tar xzf ${VIRTUOSO_COMMIT}.tar.gz
WORKDIR virtuoso-opensource-${VIRTUOSO_COMMIT}

# Build virtuoso from source
RUN ./autogen.sh
RUN export CFLAGS="-O2 -m64" \
    && ./configure \
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
        --with-readline --program-transform-name="s/isql/isql-v/" \
    && make && make install


FROM ubuntu:22.04
COPY --from=builder /usr/local/virtuoso-opensource /usr/local/virtuoso-opensource
RUN apt-get update && apt-get install -y libssl-dev crudini
# Add Virtuoso bin to the PATH
ENV PATH /usr/local/virtuoso-opensource/bin/:$PATH

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
