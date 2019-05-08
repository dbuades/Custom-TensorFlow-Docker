##################################################################################
## Build a personalized Docker Image around Google's official tensorflow image  ##
## Advantages:                                                                  ##
##   - Run it as your desired user (instead of root)                            ##
##   - JupterLab and Tensorboard                                                ##
##   - SSH support                                                              ##
##################################################################################

ARG VERSION
FROM tensorflow/tensorflow:$VERSION

# Building arguments
ARG UNAME
ARG UID
ARG GID
ARG UPWD
ARG JUPYTER_PWD
ARG SSH_PUB_KEY
ARG SSH_PORT
ARG GIT_UNAME
ARG GIT_MAIL
ARG GIT_KEY

#### Install NodeJS for Jupyterlab extensions ####
RUN apt-get update \
 && apt-get install -y --no-install-recommends wget \
 && wget https://deb.nodesource.com/setup_11.x -O /tmp/node_install.sh \
 && chmod +x /tmp/node_install.sh \
 && bash /tmp/node_install.sh \
 && apt-get update \
 && apt-get install -y --no-install-recommends nodejs

# Fix pip after NodeJS installation
RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py \
 && python3 get-pip.py --force-reinstall \
 && pip3 --no-cache-dir install --upgrade pip setuptools
####

### Install requirements ####
# System packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    libhdf5-serial-dev \
    git \
    htop \
    nano \
    curl \
    graphviz \
    tzdata \
    sudo \
    openssh-server \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Python libraries
RUN pip3 --no-cache-dir install --upgrade \
    feather-format \
    matplotlib \
    pydot \
    h5py \
    numba \
    tables \
    joblib \
    jupyter \
    ipywidgets \
    scikit-learn \
    swifter \
    ipython_memory_usage \
    plotly \
    pandas \
    pyspark \
    line_profiler \
    memory_profiler \
    cufflinks \
    jupyterlab
####
  
    
#### Configure user ####
RUN groupadd -o -g $GID $UNAME \
  && useradd -m -o -u $UID -g $GID $UNAME \
  && echo "$UNAME:$UPWD" | chpasswd \
  && usermod -aG sudo $UNAME
####


####  Configure SSH to connect remotely using VS Code ####
# Change SSH port in order not to collide with sshd on the host
RUN sed -i "s/Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config

# Required or the sessions ends
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

# Copy the public key and the Github key
RUN mkdir -p /home/$UNAME/.ssh \
  $$ echo "$SSH_PUB_KEY" > /home/$UNAME/.ssh/authorized_keys \
  $$ echo "$GIT_KEY" > /home/$UNAME/.ssh/id_github \
  $$ chmod 0600 /home/$UNAME/.ssh/* \
  $$ chmod 0700 /home/$UNAME/.ssh \
  $$ chown -R $UID:$GID /home/$UNAME/.ssh

# Own /etc/ssh or else, we can't initiate ssh as non-root
RUN mkdir /var/run/sshd && chown -R $UID:$GID /etc/ssh
#####


#### Configure GitHub #####
RUN git config --global user.name "$GIT_UNAME" \
  && git config --global user.email "$GIT_MAIL" \
  && echo " \
       Host github.com \n \
              Hostname github.com \n \
              User git \n \
              IdentityFile ~/.ssh/id_github \
       " > /home/$UNAME/.ssh/config
####


#### Configure JupyterLab ####
# Create folders for the files and set the entry password (so we don't need to enter a token the first time)
RUN mkdir /shared \ 
  && chown $UNAME /shared && chmod a+rwx /shared \
  && mkdir /home/$UNAME/.jupyter \
  && echo "c.NotebookApp.password = u'$JUPYTER_PWD'" >> /home/$UNAME/.jupyter/jupyter_notebook_config.py \
  && chown $UNAME -R /home/$UNAME/.jupyter && chmod a+rwx -R /home/$UNAME/.jupyter

# Install extensions
RUN export NODE_OPTIONS=--max-old-space-size=4096 \
 && jupyter labextension install @jupyter-widgets/jupyterlab-manager --no-build \
 && jupyter labextension install plotlywidget --no-build \
 && jupyter labextension install @jupyterlab/plotly-extension --no-build \
 && jupyter labextension install jupyterlab-chart-editor --no-build \
 && jupyter lab build \
 && unset NODE_OPTIONS
####

# Expose ports
EXPOSE $SSH_PORT
EXPOSE 8888
EXPOSE 6006

# Change user for execution
USER $UNAME
WORKDIR /shared

# We have to intialize Tensorboard on the background but jupyter on the foreground (because it's the second process and Docker expects a 0 as the return value)
CMD ["bash", "-c", "/usr/sbin/sshd -D & tensorboard --logdir /shared/logs & jupyter lab --notebook-dir=/shared --ip 0.0.0.0 --no-browser"]