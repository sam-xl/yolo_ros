ARG USER=ros
ARG USER_UID=1000
ARG USER_GID=1000
ARG ROS_DISTRO=jazzy 

FROM --platform=linux/arm64 docker.io/samxl/jetson_ros:r36.4-jazzy AS deps
ARG USER
ARG USER_UID
ARG USER_GID

# Delete user if it exists in container (e.g Ubuntu Noble: ubuntu)
RUN if id -u $USER_UID ; then userdel `id -un $USER_UID` ; fi

# Create the user
RUN groupadd --gid $USER_GID $USER \
    && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USER \
    && apt-get update && apt-get install -y \
    bash-completion \
    openssh-client \
    sudo \
    git \
    build-essential \
    python3-pip \
    python3-rosdep \
    python3-colcon-common-extensions \
    && rm -rf /var/lib/apt/lists/* \
    && rm /etc/apt/apt.conf.d/docker-clean \
    && echo $USER ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USER \
    && chmod 0440 /etc/sudoers.d/$USER \
    && echo "source /opt/ros/jazzy/setup.bash" >> /home/${USER}/.bashrc

# Create ros2_ws and copy files
WORKDIR /home/$USER/ros2_ws
COPY . /home/$USER/ros2_ws/src
RUN chown -R $USER:$USER /home/$USER/ros2_ws

# Install ROS dependencies
RUN rosdep init && rosdep update --include-eol-distros
RUN apt update && rosdep install --from-paths src --ignore-src -r -y && rm -rf /var/lib/apt/lists/*

# Install Python packages
RUN if [ "$(lsb_release -rs | cut -d. -f1)" -ge 24 ]; then \
    pip3 install -r src/requirements.txt --break-system-packages --no-cache-dir --index-url https://pypi.org/simple/; \
    else \
    pip3 install -r src/requirements.txt --no-cache-dir --index-url https://pypi.org/simple/; \
    fi

FROM deps AS builder

ARG ROS_DISTRO
ARG USER 
USER $USER 

SHELL ["/bin/bash", "-c"]

# ensure that ros2 python nodes can see the venv packages
ENV PYTHONPATH=/opt/venv/lib/python3.12/site-packages:$PYTHONPATH

# Build the workspace
RUN source /opt/ros/${ROS_DISTRO}/setup.bash && colcon build

# Source the ROS 2 setup file
RUN echo "source /opt/venv/bin/activate" >> ~/.bashrc
RUN echo "source /home/$USER/ros2_ws/install/setup.bash" >> ~/.bashrc

# Run a default command, e.g., starting a bash shell
CMD ["bash"]
