FROM tensorflow/tensorflow:2.2.0-gpu

ARG DEBIAN_FRONTEND=noninteractive

# Install apt dependencies
RUN apt-get update && apt-get install -y \
    git \
    gpg-agent \
    python3-cairocffi \
    protobuf-compiler \
    python3-pil \
    python3-lxml \
    python3-tk \
    vim \
    wget

# Install gcloud and gsutil commands
# https://cloud.google.com/sdk/docs/quickstart-debian-ubuntu
RUN export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" && \
    echo "deb http://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    apt-get update -y && apt-get install google-cloud-sdk -y

# Add new user to avoid running as root
RUN useradd -ms /bin/bash tensorflow
USER tensorflow
WORKDIR /home/tensorflow

# Copy this version of of the model garden into the image
COPY --chown=tensorflow . /home/tensorflow/models

# Compile protobuf configs
RUN (cd /home/tensorflow/models/research/ && protoc object_detection/protos/*.proto --python_out=.)
WORKDIR /home/tensorflow/models/research/

RUN cp object_detection/packages/tf2/setup.py ./
ENV PATH="/home/tensorflow/.local/bin:${PATH}"

# Set git SSH method
FROM golang:alpine

# Copy SSH key for git private repos
RUN mkdir -p /root/.ssh/
#ADD .ssh/id_rsa /root/.ssh/id_rsa
ADD .ssh/id_ed25519 /root/.ssh/id_rsa
RUN chmod 600 /root/.ssh/id_rsa
# Use git with SSH instead of https
RUN echo “[url \”git@github.com:\”]\n\tinsteadOf = https://github.com/" >> /root/.gitconfig
# Skip Host verification for git
RUN echo “StrictHostKeyChecking no “ > /root/.ssh/config

# Install and set up Jupyter notebook

RUN python3 -m pip install --upgrade pip
RUN pip install jupyter
RUN pip install matplotlib

RUN jupyter notebook --generate-config --allow-root
#RUN echo "c.NotebookApp.password = u'sha1:6a3f528eec40:6e896b6e4828f525a6e20e5411cd1c8075d68619'" >> /root/.jupyter/jupyter_notebook_config.py
RUN echo "c.NotebookApp.password = u'sha1:6a3f528eec40:6e896b6e4828f525a6e20e5411cd1c8075d68619'" >> /home/tensorflow/.jupyter/jupyter_notebook_config.py
EXPOSE 8888
#CMD ["jupyter", "notebook", "--allow-root", "--notebook-dir=/tensorflow/models/research/object_detection", "--ip=0.0.0.0", "--port=8888", "--no-browser"]
#CMD ["jupyter-notebook", "--allow-root", "--notebook-dir=/home/tensorflow/models/research/object_detection", "--ip=0.0.0.0", "--port=8888", "--no-browser"]

RUN python -m pip install -U pip
RUN python -m pip install .

ENV TF_CPP_MIN_LOG_LEVEL 3