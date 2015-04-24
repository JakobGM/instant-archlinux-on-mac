############################################################
# Copyright (c) 2015 Jonathan Yantis
# Released under the MIT license
############################################################

# ├─yantis/archlinux-tiny
#    ├─yantis/archlinux-small
#       ├─yantis/archlinux-mac-installer

# Dockerhub can not handle uploading layers above 500MB
# The layers time out on upload. Also, if a single RUN command
# takes to long to run Dockerhub will fail to build it so
# breaking them down into smaller chunks even if more redundant.

FROM yantis/archlinux-small
MAINTAINER Jonathan Yantis <yantis@yantis.net>


###############################################################################
# Install permanent additions to the container.
###############################################################################
    # Force a refresh of all the packages even if already up to date.
RUN pacman --noconfirm -Syyu && \

    # create run remote script and make it exectutable
    bash -c "echo 'curl -L \$1 | sh' > /bin/run-remote-script" && \
    chmod +x /bin/run-remote-script && \

    # Remove the texinfo-fake package since we are installing perl for rsync.
    pacman --noconfirm -Rdd texinfo-fake && \

    # Install stuff we will need later
    pacman --noconfirm --needed -S \
            perl \
            texinfo \
            rsync \
            squashfs-tools && \

    # Clean up to make this as small as possible
    localepurge && \

    # Remove info, man and docs (only in this container.. not on our new install)
    rm -r /usr/share/info/* && \
    rm -r /usr/share/man/* && \

    # Delete any backup files like /etc/pacman.d/gnupg/pubring.gpg~
    find /. -name "*~" -type f -delete && \

    # Clean up pacman
    bash -c "echo 'y' | pacman -Scc >/dev/null 2>&1" && \
    paccache -rk0 >/dev/null 2>&1 &&  \
    pacman-optimize && \
    rm -r /var/lib/pacman/sync/*


###############################################################################
# Build and Cache NVIDA Drivers
# 349xx series drivers are problematic on the Macbooks so using 346xx
###############################################################################
RUN pacman --noconfirm -Sy binutils gcc make autoconf fakeroot && \

    # create custom cache locations
    mkdir -p /var/cache/pacman/custom && \

    # build and cache nvidia-346xx-dkms package
    wget -P /tmp https://aur.archlinux.org/packages/nv/nvidia-346xx-dkms/nvidia-346xx-dkms.tar.gz && \
    tar -xvf /tmp/nvidia-346xx-dkms.tar.gz -C /tmp && \
    chown -R docker:docker /tmp/nvidia-346xx-dkms && \
    runuser -l docker -c "(cd /tmp/nvidia-346xx-dkms && makepkg -scd --noconfirm)" && \
    mv /tmp/nvidia-346xx-dkms/*.xz /var/cache/pacman/custom/ && \
    rm -r /tmp/* && \

    # build and cache nvidia-346xx-utils package
    wget -P /tmp https://aur.archlinux.org/packages/nv/nvidia-346xx-utils/nvidia-346xx-utils.tar.gz && \
    tar -xvf /tmp/nvidia-346xx-utils.tar.gz -C /tmp && \
    chown -R docker:docker /tmp/nvidia-346xx-utils && \
    runuser -l docker -c "(cd /tmp/nvidia-346xx-utils && makepkg -scd --noconfirm)" && \
    mv /tmp/nvidia-346xx-utils/*.xz /var/cache/pacman/custom/ && \
    rm -r /tmp/* && \

    # build and cache nvidia-hook package
    wget -P /tmp https://aur.archlinux.org/packages/nv/nvidia-hook/nvidia-hook.tar.gz && \
    tar -xvf /tmp/nvidia-hook.tar.gz -C /tmp && \
    chown -R docker:docker /tmp/nvidia-hook && \
    runuser -l docker -c "(cd /tmp/nvidia-hook && makepkg -scd --noconfirm)" && \
    mv /tmp/nvidia-hook/*.xz /var/cache/pacman/custom/ && \
    rm -r /tmp/* && \

    # Remove anything we added that we do not need
    pacman --noconfirm -Rs  binutils gcc make autoconf fakeroot && \

    # Remove info & man
    rm -r /usr/share/info/* && \
    rm -r /usr/share/man/* && \

    # Clean up pacman
    bash -c "echo 'y' | pacman -Scc >/dev/null 2>&1" && \
    paccache -rk0 >/dev/null 2>&1 &&  \
    pacman-optimize && \
    rm -r /var/lib/pacman/sync/*


###############################################################################
# Build any packages we may need to install.
###############################################################################
RUN pacman --noconfirm --needed -Sy base-devel && \

    # Build & cache xf86-input-mtrack-git package
    wget -P /tmp https://aur.archlinux.org/packages/xf/xf86-input-mtrack-git/xf86-input-mtrack-git.tar.gz && \
    tar -xvf /tmp/xf86-input-mtrack-git.tar.gz -C /tmp && \
    chown -R docker:docker /tmp/xf86-input-mtrack-git && \
    runuser -l docker -c "(cd /tmp/xf86-input-mtrack-git && makepkg -sc --noconfirm)" && \
    mv /tmp/xf86-input-mtrack-git/*.xz /var/cache/pacman/custom/ && \

    # Build & cache nvidia-bl-dkms package
    wget -P /tmp https://aur.archlinux.org/packages/nv/nvidia-bl-dkms/nvidia-bl-dkms.tar.gz && \
    tar -xvf /tmp/nvidia-bl-dkms.tar.gz -C /tmp && \
    chown -R docker:docker /tmp/nvidia-bl-dkms && \
    runuser -l docker -c "(cd /tmp/nvidia-bl-dkms && makepkg -sc --noconfirm)" && \
    mv /tmp/nvidia-bl-dkms/*.xz /var/cache/pacman/custom/ && \

    # extract the firmware for the b43 (even if the user doesn't need it. It doesn't hurt)
    # https://wiki.archlinux.org/index.php/Broadcom_wireless
    pacman --noconfirm -S b43-fwcutter && \
    curl -LO http://downloads.openwrt.org/sources/broadcom-wl-4.178.10.4.tar.bz2 && \
    tar xjf broadcom-wl-4.178.10.4.tar.bz2 && \
    mkdir /firmware && \
    b43-fwcutter -w /firmware broadcom-wl-4.178.10.4/linux/wl_apsta.o && \
    rm -r broadcom-wl* && \
    pacman --noconfirm -Rs b43-fwcutter && \

    # create general cache location
    mkdir -p /var/cache/pacman/general && \

    # Build & cache thermald package
    wget -P /tmp https://aur.archlinux.org/packages/th/thermald/thermald.tar.gz && \
    tar -xvf /tmp/thermald.tar.gz -C /tmp && \
    chown -R docker:docker /tmp/thermald && \
    runuser -l docker -c "(cd /tmp/thermald && makepkg -sc --noconfirm)" && \
    mv /tmp/thermald/*.xz /var/cache/pacman/general/ && \

    # build and cache mbpfan-git package
    wget -P /tmp https://aur.archlinux.org/packages/mb/mbpfan-git/mbpfan-git.tar.gz && \
    tar -xvf /tmp/mbpfan-git.tar.gz -C /tmp && \
    chown -R docker:docker /tmp/mbpfan-git && \
    runuser -l docker -c "(cd /tmp/mbpfan-git && makepkg -sc --noconfirm)" && \
    mv /tmp/mbpfan-git/*.xz /var/cache/pacman/custom/ && \
    rm -r /tmp/*  && \

    # Download broadcom and intel drivers.
    pacman --noconfirm -Sw --cachedir /var/cache/pacman/custom \
            broadcom-wl-dkms \
            xf86-video-intel && \

    # Download and cache Liberation TTF Mono Powerline Fonts
    wget -P /tmp https://aur.archlinux.org/packages/tt/ttf-liberation-mono-powerline-git/ttf-liberation-mono-powerline-git.tar.gz && \
    tar -xvf /tmp/ttf-liberation-mono-powerline-git.tar.gz -C /tmp && \
    chown -R docker:docker /tmp/ttf-liberation-mono-powerline-git && \
    runuser -l docker -c "(cd /tmp/ttf-liberation-mono-powerline-git && makepkg -sc --noconfirm)" && \
    mv /tmp/ttf-liberation-mono-powerline-git/*.xz /var/cache/pacman/general/ && \
    rm -r /tmp/* && \

    # Download and cache oh-my-zsh
    wget -P /tmp https://aur.archlinux.org/packages/oh/oh-my-zsh-git/oh-my-zsh-git.tar.gz && \
    tar -xvf /tmp/oh-my-zsh-git.tar.gz -C /tmp && \
    chown -R docker:docker /tmp/oh-my-zsh-git && \
    runuser -l docker -c "(cd /tmp/oh-my-zsh-git && makepkg -sc --noconfirm)" && \
    mv /tmp/oh-my-zsh-git/*.xz /var/cache/pacman/general/ && \
    rm -r /tmp/* && \

    # Download and cache bullet-train-oh-my-zsh-theme-git
    wget -P /tmp https://aur.archlinux.org/packages/bu/bullet-train-oh-my-zsh-theme-git/bullet-train-oh-my-zsh-theme-git.tar.gz && \
    tar -xvf /tmp/bullet-train-oh-my-zsh-theme-git.tar.gz -C /tmp && \
    chown -R docker:docker /tmp/bullet-train-oh-my-zsh-theme-git && \
    runuser -l docker -c "(cd /tmp/bullet-train-oh-my-zsh-theme-git && makepkg -sc --noconfirm)" && \
    mv /tmp/bullet-train-oh-my-zsh-theme-git/*.xz /var/cache/pacman/general/ && \
    rm -r /tmp/* && \

    # Download and cache fasd
    wget -P /tmp https://aur.archlinux.org/packages/fa/fasd-git/fasd-git.tar.gz && \
    tar -xvf /tmp/fasd-git.tar.gz -C /tmp && \
    chown -R docker:docker /tmp/fasd-git && \
    runuser -l docker -c "(cd /tmp/fasd-git && makepkg -sc --noconfirm)" && \
    mv /tmp/fasd-git/*.xz /var/cache/pacman/general/ && \
    rm -r /tmp/* && \

    # Download and cache zsh-dwim-git
    wget -P /tmp https://aur.archlinux.org/packages/zs/zsh-dwim-git/zsh-dwim-git.tar.gz && \
    tar -xvf /tmp/zsh-dwim-git.tar.gz -C /tmp && \
    chown -R docker:docker /tmp/zsh-dwim-git && \
    runuser -l docker -c "(cd /tmp/zsh-dwim-git && makepkg -sc --noconfirm)" && \
    mv /tmp/zsh-dwim-git/*.xz /var/cache/pacman/general/ && \
    rm -r /tmp/* && \

    # Download and cache zaw
    wget -P /tmp https://aur.archlinux.org/packages/za/zaw-git/zaw-git.tar.gz && \
    tar -xvf /tmp/zaw-git.tar.gz -C /tmp && \
    chown -R docker:docker /tmp/zaw-git && \
    runuser -l docker -c "(cd /tmp/zaw-git && makepkg -sc --noconfirm)" && \
    mv /tmp/zaw-git/*.xz /var/cache/pacman/general/ && \
    rm -r /tmp/* && \

    # Remove anything we added that we do not need
    pacman --noconfirm -Rs dbus-glib dri2proto dri3proto fontsproto glproto \
    libxml2 libxss mesa pixman presentproto randrproto renderproto flex \
    resourceproto videoproto xf86driproto xineramaproto xorg-util-macros \
    linux dkms gcc linux-headers binutils guile make libxfont xorg-bdftopcf \
    xorg-font-utils fontconfig xorg-fonts-encodings libtool m4 git inputproto \
    dbus systemd package-query automake libx32-flex bison autoconf \
    automake1.11 freetype2 harfbuzz graphite libpng xorg-server-devel \
    libunistring gettext && \

    # Clean up to make this as small as possible
    localepurge && \

    # Remove info, man and docs (only in this container.. not on our new install)
    rm -r /usr/share/info/* && \
    rm -r /usr/share/man/* && \
    rm -r /usr/share/doc/* && \

    # Delete any backup files like /etc/pacman.d/gnupg/pubring.gpg~
    find /. -name "*~" -type f -delete && \

    # Clean up pacman
    bash -c "echo 'y' | pacman -Scc >/dev/null 2>&1" && \
    paccache -rk0 >/dev/null 2>&1 &&  \
    pacman-optimize && \
    rm -r /var/lib/pacman/sync/*

###############################################################################
# Cache packages that have happened since the last airootfs image
# Purposely add another layer here to break up the size.
# Since we kept the one above clean it should add minimal overhead.
###############################################################################
RUN pacman --noconfirm -Syw --cachedir /var/cache/pacman/general \
            btrfs-progs \
            ca-certificates-utils \
            ca-certificates \
            dnsmasq \
            glib2 \
            glibc \
            gnupg \
            gnutls \
            grml-zsh-config \
            gssproxy \
            lftp \
            libinput \
            libssh2 \
            libsystemd \
            libtasn1 \
            lz4 \
            man-pages \
            nano \
            nettle \
            ntp \
            partclone \
            openconnect \
            systemd-sysvcompat \
            tcpdump \
            testdisk && \
    rm -r /var/lib/pacman/sync/*

###############################################################################
# Just download these since we don't actually need them for the docker container.
# Make sure none of these are in the list above.
# This is broken into several layers because dockerhub can not handle it
###############################################################################
RUN pacman --noconfirm -Syw --cachedir /var/cache/pacman/general \
            base-devel \
            acpi \
            alsa-utils \
            arch-install-scripts \
            aria2 \
            c-ares \
            cpupower \
            ctags \
            dkms \
            feh \
            git \
            haveged \
            htop \
            gnome-keyring \
            gnome-terminal \
            google-chrome  && \

            # Clean up pacman
            bash -c "echo 'y' | pacman -Scc >/dev/null 2>&1" && \
            paccache -rk0 >/dev/null 2>&1 &&  \
            pacman-optimize && \
            rm -r /var/lib/pacman/sync/*

RUN pacman --noconfirm -Syw --cachedir /var/cache/pacman/general \
            linux \
            linux-headers && \

            # Clean up pacman
            bash -c "echo 'y' | pacman -Scc >/dev/null 2>&1" && \
            paccache -rk0 >/dev/null 2>&1 &&  \
            pacman-optimize && \
            rm -r /var/lib/pacman/sync/*

RUN pacman --noconfirm -Syw --cachedir /var/cache/pacman/general \
            hfsprogs \
            intel-ucode \
            imagemagick \
            lm_sensors \
            mlocate \
            networkmanager \
            network-manager-applet \
            pavucontrol \
            package-query \
            pciutils \
            powertop \
            pulseaudio-alsa \
            pulseaudio && \

            # Clean up pacman
            bash -c "echo 'y' | pacman -Scc >/dev/null 2>&1" && \
            paccache -rk0 >/dev/null 2>&1 &&  \
            pacman-optimize && \
            rm -r /var/lib/pacman/sync/*

RUN pacman --noconfirm -Syw --cachedir /var/cache/pacman/general \
            plasma \
            konsole && \

            # Clean up pacman
            bash -c "echo 'y' | pacman -Scc >/dev/null 2>&1" && \
            paccache -rk0 >/dev/null 2>&1 &&  \
            pacman-optimize && \
            rm -r /var/lib/pacman/sync/*

RUN pacman --noconfirm -Syw --cachedir /var/cache/pacman/general \
            python-dateutil \
            python-docutils \
            python-pyasn1\
            python-rsa \
            python-setuptools \
            python-six \
            reflector \
            rsync \
            sqlite \
            sddm && \

            # Clean up pacman
            bash -c "echo 'y' | pacman -Scc >/dev/null 2>&1" && \
            paccache -rk0 >/dev/null 2>&1 &&  \
            pacman-optimize && \
            rm -r /var/lib/pacman/sync/*

RUN pacman --noconfirm -Syw --cachedir /var/cache/pacman/general \
            systemd \
            terminus-font \
            tree \
            tmux \
            vim  && \

            # Clean up pacman
            bash -c "echo 'y' | pacman -Scc >/dev/null 2>&1" && \
            paccache -rk0 >/dev/null 2>&1 &&  \
            pacman-optimize && \
            rm -r /var/lib/pacman/sync/*

RUN pacman --noconfirm -Syw --cachedir /var/cache/pacman/general \
            xfce4 && \

            # Clean up pacman
            bash -c "echo 'y' | pacman -Scc >/dev/null 2>&1" && \
            paccache -rk0 >/dev/null 2>&1 &&  \
            pacman-optimize && \
            rm -r /var/lib/pacman/sync/*

RUN pacman --noconfirm -Syw --cachedir /var/cache/pacman/general \
            xfce4-whiskermenu-plugin \
            xorg-server \
            xorg-server-utils \
            xorg-xinit \
            xorg-xev \
            yajl \
            yaourt \
            zsh-syntax-highlighting && \

            # Clean up pacman
            bash -c "echo 'y' | pacman -Scc >/dev/null 2>&1" && \
            paccache -rk0 >/dev/null 2>&1 &&  \
            pacman-optimize && \
            rm -r /var/lib/pacman/sync/*

CMD /bin/zsh
