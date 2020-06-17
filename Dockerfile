FROM continuumio/miniconda

# Install scripts 
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

# Install ubuntu dependencies
RUN apt-get update
RUN apt-get install -y less gawk unzip wget
RUN export TZ=Europe/London
RUN apt-get install -y tzdata || apt-get install -y --fix-missing tzdata 
RUN apt-get install -y libssl-dev libcurl4-openssl-dev libxml2-dev

# Install graphlan
RUN conda install -c bioconda -y -c conda-forge colorama colormap biopython lxml matplotlib easydev graphlan

# Install plink
RUN mkdir /app/
RUN mkdir /app/plink 
RUN cd /app/plink && \ 
    wget http://s3.amazonaws.com/plink1-assets/plink_linux_x86_64_20200428.zip &&\
    unzip plink*.zip && \ 
    cp plink /usr/local/bin && \
    chmod a+x /usr/local/bin/plink && \
    cd .. && \
    rm -rf /app/plink 


# Install R and annex libraries
RUN apt-get -y install r-base || apt-get -y --fix-missing install r-base 
RUN Rscript -e 'install.packages("httr", repos="https://cloud.r-project.org")'
RUN Rscript -e 'install.packages("rvest", repos="https://cloud.r-project.org")'
RUN Rscript -e 'install.packages("xml2", repos="https://cloud.r-project.org")'
RUN Rscript -e 'install.packages("tidyverse", repos="https://cloud.r-project.org")'

# Clean up
RUN apt-get remove -y unzip wget 
RUN apt autoclean -y
RUN apt autoremove -y

# Add all to the path
WORKDIR /app/data/