FROM ubuntu:22.04 as builder

# Set Virtuoso commit SHA to Virtuoso 7.2.8 release (2022-10-19)
ARG VIRTUOSO_COMMIT=64e6ecd39b03383875b7f2f15ed8070e2ebcd1f0

RUN apt-get update
RUN apt-get install -y build-essential autotools-dev autoconf automake net-tools libtool \
                       flex bison gperf gawk m4 libssl-dev libreadline-dev openssl wget
RUN wget https://github.com/openlink/virtuoso-opensource/archive/${VIRTUOSO_COMMIT}.tar.gz
RUN tar xzf ${VIRTUOSO_COMMIT}.tar.gz
WORKDIR virtuoso-opensource-${VIRTUOSO_COMMIT}

# See https://github.com/openlink/virtuoso-opensource/blob/9cececaca5df32c82576e5390062475bbf5e1cc1/libsrc/Wi/mkgit_head.sh
# mkgit_head.sh doesn't do what it is expected to do since our downloaded tar doesn't have git history
# Provide libsrc/Wi/git_head.c manually
RUN export VALUE=$(echo $VIRTUOSO_COMMIT | head -c 7); echo "#define GIT_HEAD_STR \"$VALUE\"" > libsrc/Wi/git_head.c
RUN export VALUE=$(echo $VIRTUOSO_COMMIT | head -c 7); echo "char * git_head = \"$VALUE\";" >> libsrc/Wi/git_head.c

# Build virtuoso from source
RUN ./autogen.sh
RUN export CFLAGS="-O2 -m64" \
    && ./configure \
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
