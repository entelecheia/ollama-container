# Sets the base image for subsequent instructions
FROM nvcr.io/nvidia/cuda:12.4.1-devel-ubuntu22.04 AS builder

# Sets labels for the image
LABEL org.opencontainers.image.source="https://github.com/entelecheia/ollama-container"
LABEL org.opencontainers.image.description="Container images for running Ollama models on the container platforms."
LABEL org.opencontainers.image.licenses="MIT"

ARG TARGETARCH
ARG GOFLAGS="'-ldflags=-w -s'"
# Sets the time zone within the container
ENV TZ="Asia/Seoul"

RUN apt-get update && apt-get install -y git build-essential cmake ccache
RUN /usr/sbin/update-ccache-symlinks
RUN export PATH="/usr/lib/ccache:$PATH"

ADD https://dl.google.com/go/go1.21.3.linux-$TARGETARCH.tar.gz /tmp/go1.21.3.tar.gz
RUN mkdir -p /usr/local && tar xz -C /usr/local </tmp/go1.21.3.tar.gz

ARG ARG_IMAGE_VERSION="0.1.14"
ENV IMAGE_VERSION=$ARG_IMAGE_VERSION

# Clones the repository into the container
RUN git clone https://github.com/jmorganca/ollama.git /go/src/github.com/jmorganca/ollama
# Sets the working directory
WORKDIR /go/src/github.com/jmorganca/ollama
# Ckecks out the specified tag
RUN git checkout tags/v$IMAGE_VERSION
# Sets the environment variables for building the binary
ENV GOARCH=$TARGETARCH
ENV GOFLAGS=$GOFLAGS
RUN /usr/local/go/bin/go generate ./... \
    && /usr/local/go/bin/go build .

FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04 as app

# Setting this argument prevents interactive prompts during the build process
ARG DEBIAN_FRONTEND=noninteractive
# Updates the image and installs necessary packages
RUN apt-get update --fix-missing \
    && apt-get install -y curl wget jq sudo gosu ca-certificates \
    # Cleans up unnecessary packages to reduce image size
    && apt-get autoremove -y \
    && apt-get clean -y
# Copies the binary from the base image into the app image
COPY --from=base /go/src/github.com/jmorganca/ollama/ollama /bin/ollama

# Setting ARGs and ENVs for user creation and workspace setup
ARG ARG_USERNAME="app"
ARG ARG_USER_UID=9001
ARG ARG_USER_GID=$ARG_USER_UID
ENV USERNAME $ARG_USERNAME
ENV USER_UID $ARG_USER_UID
ENV USER_GID $ARG_USER_GID

# Creates a non-root user with sudo privileges
# check if user exists and if not, create user
RUN if id -u $USERNAME >/dev/null 2>&1; then \
        # if the current user's user id is different from the specified user id, change the user id of the current user to the specified user id
        if [ "$USER_UID" -ne "$(id -u $USERNAME)" ]; then \
            usermod --uid $USER_UID $USERNAME; \
            chown --recursive $USER_UID:$USER_UID $WORKSPACE_ROOT; \
        fi; \
    else \
        groupadd --gid $USER_GID $USERNAME && \
        adduser --uid $USER_UID --gid $USER_GID --force-badname --disabled-password --gecos "" $USERNAME && \
        echo "$USERNAME:$USERNAME" | chpasswd && \
        adduser $USERNAME sudo && \
        echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
        echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME && \
        chmod 0440 /etc/sudoers.d/$USERNAME; \
    fi


# Copies entrypoint script from host into the image
COPY ./.docker/scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
# Changes the entrypoint script permissions to make it executable
RUN chmod +x /usr/local/bin/entrypoint.sh
# Sets the entrypoint script as the default command that will be executed when the container is run
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
