# Use the original dHCP pipeline image as the base image
FROM biomedia/dhcp-structural-pipeline:latest as dhcp_base

# # Build ANTs in a separate stage
# FROM ubuntu:bionic-20220427 as ants_builder

RUN apt-get update && \
    apt-get install -y build-essential checkinstall \
    libreadline-gplv2-dev libncursesw5-dev libssl-dev libsqlite3-dev tk-dev \
    libgdbm-dev libc6-dev libbz2-dev zlib1g-dev openssl libffi-dev python3-dev curl && \
    wget https://www.python.org/ftp/python/3.6.15/Python-3.6.15.tgz && \
    tar xzf Python-3.6.15.tgz && \
    cd Python-3.6.15 && \
    ./configure --enable-optimizations && \
    make altinstall && \
    cd .. && \
    rm -rf Python-3.6.15* && \
    curl https://bootstrap.pypa.io/pip/3.6/get-pip.py | python3.6 - && \
    apt-get remove -y checkinstall \
    libreadline-gplv2-dev libncursesw5-dev libssl-dev libsqlite3-dev tk-dev \
    libgdbm-dev libc6-dev libbz2-dev openssl libffi-dev && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV PATH="/usr/local/bin:${PATH}"

RUN echo $PATH && \
    pip3 install --upgrade setuptools pip && \
    pip3 install numpy SimpleITK

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    apt-transport-https \
    bc \
    ca-certificates \
    gnupg \
    ninja-build \
    git \
    software-properties-common \
    wget \
    unzip \
    gcc-5

ADD https://github.com/ANTsX/ANTs/releases/download/v2.4.3/ants-2.4.3-ubuntu-22.04-X64-gcc.zip /tmp/ants/source.zip
RUN unzip /tmp/ants/source.zip -d /tmp/ants \
    && mv /tmp/ants/ants-2.4.3 /opt/ants

# remov the source code
RUN rm -rf /tmp/ants

# Set environment variables for ANTs
ENV ANTSPATH="/opt/ants/bin/" \
    PATH="/opt/ants/bin:$PATH" \
    LD_LIBRARY_PATH="/opt/ants/lib:$LD_LIBRARY_PATH"

# Clone the perinatal pipeline extension repository
RUN git clone https://github.com/GerardMJuan/perinatal-pipeline-docker.git /tmp/perinatal-pipeline

# Copy the contents of the cloned repository to the existing structural-pipeline directory
RUN cp -R /tmp/perinatal-pipeline/* /usr/src/structural-pipeline/

# Remove the cloned repository
RUN rm -rf /tmp/perinatal-pipeline

# Grant executable permissions to all the scripts in the various directories
RUN chmod +x -R /usr/src/structural-pipeline/setup_perinatal.sh \
    && chmod +x -R /usr/src/structural-pipeline/perinatal-pipeline.sh \
    && chmod +x -R /usr/src/structural-pipeline/perinatal/perinatal_scripts/pipelines/ \
    && chmod +x -R /usr/src/structural-pipeline/perinatal/perinatal_scripts/basic_scripts/ \
    && chmod +x -R /usr/src/structural-pipeline/perinatal/perinatal_scripts/scripts/ \
    && chmod +x -R /etc/fsl/fsl.sh

# SETUP FSLDIR
RUN /etc/fsl/fsl.sh

# Run the setup_perinatal.sh script
RUN cd /usr/src/structural-pipeline && sh setup_perinatal.sh

# Set the entrypoint for the new image
ENTRYPOINT ["/usr/src/structural-pipeline/perinatal-pipeline.sh"]
