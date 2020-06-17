FROM ubuntu:18.04

# Install ubuntu dependencies
RUN apt-get update
RUN apt-get install -y less gawk unzip wget  || \
    apt-get install --fix-missing -y less gawk unzip wget
RUN export TZ=Europe/London
RUN apt-get install -y tzdata || apt-get install -y --fix-missing tzdata 
RUN apt-get install -y libssl-dev libcurl4-openssl-dev libxml2-dev || apt-get install --fix-missing -y libssl-dev libcurl4-openssl-dev libxml2-dev

# Install graphlan
RUN mkdir /app
ADD graphlan.zip /app/
RUN cd /app && \
    unzip graphlan.zip && \
    rm graphlan.zip && \
    cp -r /app/graphlan/* /usr/local/bin/ && \
    chmod +x /usr/local/bin/graphlan.py && \
    rm -rf /app/graphlan/ /app/graphlan.py

# Install plink
RUN mkdir /app/plink 
RUN cd /app/plink && \ 
    wget http://s3.amazonaws.com/plink1-assets/plink_linux_x86_64_20200428.zip &&\
    unzip plink*.zip && \ 
    cp plink /usr/local/bin && \
    chmod a+x /usr/local/bin/plink && \
    cd .. && \
    rm -rf /app/plink && \
    apt-get remove -y wget unzip

# Install additional scripts 
ADD ./bin/arrange /usr/local/bin/
RUN chmod a+x /usr/local/bin/arrange
ADD ./bin/BsTpedTmap /usr/local/bin/ 
RUN chmod a+x /usr/local/bin/BsTpedTmap
ADD ./bin/ConsensusTree /usr/local/bin/
RUN chmod a+x /usr/local/bin/ConsensusTree
ADD ./bin/FixGraphlanXml /usr/local/bin/
RUN chmod a+x /usr/local/bin/FixGraphlanXml
ADD ./bin/MakeBootstrapLists /usr/local/bin/
RUN chmod a+x /usr/local/bin/MakeBootstrapLists
ADD ./bin/MakeTree /usr/local/bin/ 
RUN chmod a+x /usr/local/bin/MakeTree

# Install python and its packages
RUN apt-get install -y python python-pip || apt-get install --fix-missing -y python python-pip
RUN pip install colorama colormap biopython lxml matplotlib easydev

# Install R and annex libraries
RUN apt-get -y --fix-missing install r-base || apt-get -y --fix-missing install r-base 
RUN apt autoclean -y
RUN apt autoremove -y
RUN Rscript -e 'install.packages("httr", repos="https://cloud.r-project.org")'
RUN Rscript -e 'install.packages("rvest", repos="https://cloud.r-project.org")'
RUN Rscript -e 'install.packages("xml2", repos="https://cloud.r-project.org")'
RUN Rscript -e 'install.packages("tidyverse", repos="https://cloud.r-project.org")'

# Add all to the path
WORKDIR /app/data/