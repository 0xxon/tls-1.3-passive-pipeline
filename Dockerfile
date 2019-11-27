From debian:buster

RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y cmake make gcc g++ flex bison libpcap-dev libssl-dev zlib1g-dev git python3 ninja-build wget ca-certificates postgresql-11 postgresql-client-11 python3-pip libgmp-dev libpq-dev
WORKDIR /root/build
RUN git clone --branch v3.0.0 https://github.com/zeek/zeek
RUN cd zeek && git submodule update --recursive --init
RUN cd zeek && ./configure --prefix=/opt/zeek --generator=Ninja --enable-static-broker --enable-static-binpac --disable-zeekctl --disable-python --disable-broker-tests --binary-package && cd build && ninja install && cd .. && rm -rf build 
RUN wget https://www.cpan.org/src/5.0/perl-5.30.1.tar.gz && tar xvf perl-5.30.1.tar.gz && cd perl-5.30.1 && ./Configure -des -Dprefix=/opt/perl && make -j8 && make -j8 install && cd .. && rm -rf perl-5.30.1
RUN pip3 install zkg
RUN PATH=/opt/zeek/bin:$PATH zkg autoconfig && PATH=/opt/zeek/bin:$PATH zkg install --force zeek/0xxon/zeek-tls-log-alternative
RUN echo "PATH=/opt/zeek/bin:/opt/perl/bin:/usr/lib/postgresql/11/bin:$PATH" >> /etc/profile && echo "export PATH" >> /etc/profile
RUN useradd -m -s /bin/bash tls && usermod -a -G postgres tls
WORKDIR /home/tls
USER tls
RUN git clone https://github.com/0xxon/postgres-to-latex
RUN git clone https://github.com/0xxon/zeek-tls-log-alternative-parser
USER root
WORKDIR /root
RUN PATH=/opt/perl/bin:$PATH /home/tls/zeek-tls-log-alternative-parser/install-prereqs.sh && rm -rf .cpan
RUN chmod og+rx /root
