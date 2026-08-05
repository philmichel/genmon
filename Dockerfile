FROM python:3.14.7-slim-trixie@sha256:83c1cebb322d099ac9e3a3a532ba74b0146d702838b25e4c75c02fa81ffeb910

ARG GENMON_VERSION

RUN apt update -y
RUN apt upgrade -y

# The timezone specified here just bypasses some required configuration, it is not configuring a persistent setting
RUN DEBIAN_FRONTEND="noninteractive" TZ="America/Los_Angeles" apt install -y sudo git

# Download genmon code at specific version. Upstream dropped the V tag prefix
# with 2.0.01, so try both tag styles.
RUN mkdir -p /app && cd /app && git clone https://github.com/jgyates/genmon.git && \
    cd genmon && { git checkout "V${GENMON_VERSION}" 2>/dev/null || git checkout "${GENMON_VERSION}"; }
RUN sudo chmod 775 /app/genmon/startgenmon.sh && sudo chmod 775 /app/genmon/genmonmaint.sh

# Update the genmon.conf file to use the TCP serial for ESP32 devices
RUN sed -i 's/use_serial_tcp = False/use_serial_tcp = True/g' /app/genmon/conf/genmon.conf
RUN sed -i 's/serial_tcp_port = 8899/serial_tcp_port = 6638/g' /app/genmon/conf/genmon.conf
RUN echo "update_check = false" >> /app/genmon/conf/genmon.conf

# Update MQTT default config
RUN sed -i 's/strlist_json = False/strlist_json = True/g' /app/genmon/conf/genmqtt.conf
RUN sed -i 's/flush_interval = 0/flush_interval = 60/g' /app/genmon/conf/genmqtt.conf
RUN sed -i 's/blacklist = Monitor,Run Time,Monitor Time,Generator Time,External Data/blacklist = Run Time,Monitor Time,Generator Time,Platform Stats,Communication Stats/g' /app/genmon/conf/genmqtt.conf

# Force to use virtualenv
RUN mkdir -p /usr/lib/python3.14
RUN echo '' >> /usr/lib/python3.14/EXTERNALLY-MANAGED

# Install Genmon requirements
RUN cd /app/genmon && ./genmonmaint.sh -i -n -s
RUN /app/genmon/genenv/bin/pip install setuptools

# Allow running as non-root: genloader.py and genmon.py hard-require euid 0 via
# MySupport.PermissionsOK(), but nothing needs root in a TCP-serial deployment.
# The grep guard fails the build if upstream moves or changes the check.
RUN grep -q 'MyPlatform.IsOSLinux() and os.geteuid() == 0' /app/genmon/genmonlib/mysupport.py && \
    sed -i 's/MyPlatform.IsOSLinux() and os.geteuid() == 0/MyPlatform.IsOSLinux()/' /app/genmon/genmonlib/mysupport.py

# Create an unprivileged user and give it the paths genmon writes to
RUN useradd --uid 1000 --user-group --home-dir /app --shell /usr/sbin/nologin genmon && \
    mkdir -p /etc/genmon /var/log/genmon && \
    touch /var/log/genmon.log && \
    chown -R genmon:genmon /app/genmon /etc/genmon /var/log/genmon /var/log/genmon.log

# Configure startup script, and replace upstream startgenmon.sh with a
# container-aware version: upstream wraps every genloader.py call in sudo
# (non-functional as UID 1000 under no-new-privileges), and its in-place
# restart can't work under a container PID 1.
COPY start.sh /app/start.sh
COPY startgenmon.sh /app/genmon/startgenmon.sh
RUN chmod +x /app/start.sh /app/genmon/startgenmon.sh

# Clean up
RUN apt-get purge -y sudo git build-essential libssl-dev libffi-dev python3-dev cargo && apt autoremove && apt clean ; \
  rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

USER 1000:1000

VOLUME /etc/genmon

EXPOSE 22
EXPOSE 443
EXPOSE 8000

CMD ["/app/start.sh"]

# annotation labels according to
# https://github.com/opencontainers/image-spec/blob/v1.0.1/annotations.md#pre-defined-annotation-keys
LABEL org.opencontainers.image.title="Genmon Docker Image"
LABEL org.opencontainers.image.description="Image to run an instance of Genmon"
LABEL org.opencontainers.image.url="https://github.com/philmichel/genmon"
LABEL org.opencontainers.image.documentation="https://github.com/philmichel/genmon#readme"
LABEL org.opencontainers.image.licenses="GPL-2.0"
LABEL org.opencontainers.image.authors="Joe Ipson & Phil Michel"
LABEL org.opencontainers.image.version="${GENMON_VERSION}"
