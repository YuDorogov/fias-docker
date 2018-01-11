# get image from...
FROM centos:7
MAINTAINER Dorogov Yuriy  yudorogov@at-consulting.ru
ENV FIAS_REGION="03"
ENV CATALINA_HOME /usr/share/apache-tomcat-7.0.81
ENV PATH $CATALINA_HOME/bin:/opt/solr/bin:/opt/docker-solr/scripts:$PATH
ENV SOLR_USER="solr" \
    SOLR_UID="8983" \
    SOLR_GROUP="solr" \
    SOLR_GID="8983" \
    SOLR_VERSION="5.5.4" \
    SOLR_DOWNLOAD_SERVER="http://www-eu.apache.org/dist/lucene/solr" \
    SOLR_URL="${SOLR_DOWNLOAD_SERVER:-https://archive.apache.org/dist/lucene/solr}/5.5.5/solr-5.5.5.tgz" \
    SOLR_SHA256="2bbe3a55976f118c5d8c2382d4591257f6e2af779c08c6561e44afa3181a87c1" \
    SOLR_KEYS="5F55943E13D49059D3F342777186B06E1ED139E7"

RUN yum install -y epel-release initscripts
RUN yum -y update; yum clean all
RUN yum install -y unzip nano which wget tar 
RUN rpm -Uvh https://forensics.cert.org/cert-forensics-tools-release-el7.rpm
RUN yum --enablerepo=forensics install unrar -y
RUN rpm -Uvh https://mirror.its.sfu.ca/mirror/CentOS-Third-Party/NSG/common/x86_64/jdk-8u102-linux-x64.rpm
RUN wget --no-check-certificate https://archive.apache.org/dist/tomcat/tomcat-7/v7.0.81/bin/apache-tomcat-7.0.81.tar.gz -O /root/apache-tomcat-7.0.81.tar.gz
RUN tar -xzf /root/apache-tomcat-7.0.81.tar.gz -C /usr/share
RUN wget http://80.211.159.239/fias/tomcat -O /etc/init.d/tomcat && chmod +x /etc/init.d/tomcat
RUN rm -f /usr/share/apache-tomcat-7.0.81/conf/tomcat-users.xml
RUN wget http://80.211.159.239/fias/tomcat-users.xml -O /usr/share/apache-tomcat-7.0.81/conf/tomcat-users.xml
RUN wget http://80.211.159.239/fias/fias-address-rest.war -O /usr/share/apache-tomcat-7.0.81/webapps/fias-address-rest.war
RUN wget http://80.211.159.239/fias/fias-address-rest-config.properties -O /usr/share/apache-tomcat-7.0.81/conf/fias-address-rest-config.properties
#RUN wget --no-check-certificate https://archive.apache.org/dist/lucene/solr/5.5.4/solr-5.5.4.tgz -O /root/solr-5.5.4.tgz
#RUN adduser solr
#RUN tar -xf /root/solr-5.5.4.tgz -C /root && mv /root/solr-5.5.4/bin/install_solr_service.sh /root/install_solr_service.sh && chmod +x /root/install_solr_service.sh
#RUN /root/install_solr_service.sh /root/solr-5.5.4.tgz
#RUN yum install -y mc lsof procps gpg

RUN groupadd -r --gid $SOLR_GID $SOLR_GROUP && \
  useradd -r --uid $SOLR_UID --gid $SOLR_GID $SOLR_USER
 RUN set -e; for key in $SOLR_KEYS; do \
    found=''; \
    for server in \
      ha.pool.sks-keyservers.net \
      hkp://keyserver.ubuntu.com:80 \
      hkp://p80.pool.sks-keyservers.net:80 \
      pgp.mit.edu \
    ; do \
      echo "  trying $server for $key"; \
      gpg --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$key" && found=yes && break; \
    done; \
    test -z "$found" && echo >&2 "error: failed to fetch $key from several disparate servers -- network issues?" && exit 1; \
  done; \
  exit 0

RUN mkdir -p /opt/solr && \
  echo "downloading $SOLR_URL" && \
  wget -nv $SOLR_URL -O /opt/solr.tgz && \
  echo "downloading $SOLR_URL.asc" && \
  wget -nv $SOLR_URL.asc -O /opt/solr.tgz.asc && \
  echo "$SOLR_SHA256 */opt/solr.tgz" | sha256sum -c - && \
  (>&2 ls -l /opt/solr.tgz /opt/solr.tgz.asc) && \
  gpg --batch --verify /opt/solr.tgz.asc /opt/solr.tgz && \
  tar -C /opt/solr --extract --file /opt/solr.tgz --strip-components=1 && \
  rm /opt/solr.tgz* && \
  rm -Rf /opt/solr/docs/ && \
  mkdir -p /opt/solr/server/solr/lib /opt/solr/server/solr/mycores /opt/solr/server/logs /docker-entrypoint-initdb.d /opt/docker-solr && \
  sed -i -e 's/"\$(whoami)" == "root"/$(id -u) == 0/' /opt/solr/bin/solr && \
  sed -i -e 's/lsof -PniTCP:/lsof -t -PniTCP:/' /opt/solr/bin/solr && \
  sed -i -e 's/#SOLR_PORT=8983/SOLR_PORT=8983/' /opt/solr/bin/solr.in.sh && \
  sed -i -e '/-Dsolr.clustering.enabled=true/ a SOLR_OPTS="$SOLR_OPTS -Dsun.net.inetaddr.ttl=60 -Dsun.net.inetaddr.negative.ttl=60"' /opt/solr/bin/solr.in.sh && \
  chown -R $SOLR_USER:$SOLR_GROUP /opt/solr

COPY scripts /opt/docker-solr/scripts
RUN chown -R $SOLR_USER:$SOLR_GROUP /opt/docker-solr
COPY fias-install /opt/fias-install
#VOLUME ["/fias/fias-data/20170817-full"]
#COPY fias-data /opt/fias-data
RUN mkdir /var/solr/ && mkdir /var/solr/data/ && mkdir /var/solr/logs/
RUN cp -f /opt/fias-install/fias.address.tools-0.1.jar /opt/fias-data && cp -f /opt/fias-install/config.properties /opt/fias-data && unzip /opt/fias-install/fias-address.zip -d /opt/solr/server/solr/ && chown -R $SOLR_USER:$SOLR_GROUP /opt/solr/server/solr/fias-address
RUN wget http://dl.smartcitycloud.ru/fias/fdb/$FIAS_REGION.tar.gz -O /root/$FIAS_REGION.tar.gz && tar zxvf /root/$FIAS_REGION.tar.gz -C /

EXPOSE 8080 8983
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["solr-foreground"]
