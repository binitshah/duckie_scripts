#!/bin/bash

set -e

echo "check given the right arguments"
if [ -z "$DID" ]; then
    echo "please supply duckie identifier. pattern: export DID=duckie###"
    exit 1
fi
if [[ ! "$DID" =~ ^duckie[0-9]{3}$ ]]; then
    echo "duckie identifier does not match pattern: duckie[0-9]{3}. 'duckie' followed by three digits"
    exit 1
fi
echo "yes"
echo ""

echo "checking running on an ubuntu 20.04 machine"
source /etc/os-release
if [[ ! $VERSION_ID = "20.04" ]]; then
    echo "not running on an ubuntu 20.04 machine. exiting."
    exit 1
fi
echo "yes"
echo ""

echo "checking running script from correct folder"
if [[ ! "$PWD" =~ duckie_scripts ]]; then
    echo "run this script from the duckie_scripts folder. exiting."
    exit 1
fi
echo "yes"
echo ""

echo "waiting to get online"
while ! timeout 0.2 ping -c 1 -n google.com &> /dev/null
do
    sleep 1
    printf "%c" "."
done
echo "online!"
echo ""

echo "checking install repo is up-to-date"
git remote update
UPSTREAM=${1:-'@{u}'}
LOCAL=$(git rev-parse @)
REMOTE=$(git rev-parse "$UPSTREAM")
if [ ! $LOCAL = $REMOTE ]; then
    echo "repo not up-to-date. perform a 'git pull'. exiting."
    exit 1
fi
echo ""

echo "waiting for apt lock"
while sudo fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do
    sleep 1
    printf "%c" "."
done
echo "got apt lock!"
echo ""

echo "running an apt update & upgrade"
sudo apt remove --yes unattended-upgrades
sudo apt-get update
sudo apt-get upgrade --yes
echo ""

echo "Setting locale info"
sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export LANG=en_US.UTF-8
echo ""

echo "installing ROS2 prereqs"
sudo apt-get install --yes curl gnupg2 lsb-release
echo ""

echo "adding ROS apt key"
curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | sudo apt-key add -
echo ""

echo "adding ROS2 repos to sources list"
sudo sh -c 'echo "deb [arch=$(dpkg --print-architecture)] http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" > /etc/apt/sources.list.d/ros2-latest.list'
echo ""

echo "installing ROS2"
sudo apt-get update
sudo apt-get install --yes ros-foxy-ros-base ros-foxy-demo-nodes-cpp ros-foxy-demo-nodes-py ros-foxy-teleop-twist-keyboard
echo ""

echo "installing argcomplete"
sudo apt-get install --yes python3-pip
pip3 install -U argcomplete
echo ""

echo "installing colcon"
sudo apt-get install --yes python3-colcon-common-extensions
echo ""

echo "adding setup.bash to bashrc"
echo "" >> ~/.bashrc
echo "source /opt/ros/foxy/setup.bash" >> ~/.bashrc
echo ""

echo "installing zip & i2c-tools"
sudo apt-get install --yes zip i2c-tools
echo ""

echo "installing pip package: smbus, RPi.GPIO, & picamera"
sudo python3 -m pip install smbus
sudo python3 -m pip install RPi.GPIO
sudo python3 -m pip install picamera
pip3 list
echo ""

echo "adding start_x and gpu_mem to boot config.txt"
sudo sh -c "echo '\nstart_x=1\ngpu_mem=128' >> /boot/firmware/config.txt"
cat /boot/firmware/config.txt
echo ""

echo "setup i2c & video unix groups"
sudo groupadd -f i2c
sudo groupadd -f video
sudo groupadd -f gpio
sudo usermod -a -G tty $USER
sudo usermod -a -G i2c $USER
sudo usermod -a -G video $USER
sudo usermod -a -G gpio $USER
sudo chown :i2c /dev/i2c-1
sudo chown :video /dev/vchiq
sudo chown :gpio /dev/mem
sudo chown :gpio /dev/gpiomem
sudo chmod g+rw /dev/i2c-1
sudo chmod g+rw /dev/vchiq
sudo chmod g+rw /dev/mem
sudo chmod g+rw /dev/gpiomem
sudo cp ./10-local_i2c_group.rules /etc/udev/rules.d/
sudo cp ./11-local_video_group.rules /etc/udev/rules.d/
sudo cp ./12-local_gpio_group.rules /etc/udev/rules.d/
sudo cp ./13-local_gpio_group.rules /etc/udev/rules.d/
echo ""

echo "compile and install raspberrypi/userland"
git clone https://github.com/binitshah/userland.git ~/userland
mkdir ~/userland/build && cd ~/userland/build
export LDFLAGS="-Wl,--no-as-needed"
cmake -DCMAKE_BUILD_TYPE=Release -DARM64=ON ../
make -j4 && sudo make install
cd -
sudo rm -rf ~/userland
sudo cp ./.bash_aliases ~/
source ~/.bashrc
sudo ldconfig
echo ""

echo "libmmal.so should look like this:"
cat ./expected_libmmal.txt
echo "here is what libmmal.so actually is:"
ldd /opt/vc/lib/libmmal.so
echo ""

echo "setting vim settings in vimrc"
cp ./.vimrc ~/
echo ""

echo "disable cloud-init to reduce boot time"
sudo touch /etc/cloud/cloud-init.disabled
echo ""

echo "disable snapd to reduce boot time"
sudo apt purge --yes snapd
rm -rf ~/snap
sudo rm -rf /snap
sudo rm -rf /var/snap
sudo rm -rf /var/lib/snapd
echo ""

echo "disable MOTD news"
sudo cp ./motd-news /etc/default/motd-news
echo ""

echo "install avr toolset and copy conf for avrdude"
sudo apt-get install --yes gcc-avr binutils-avr avr-libc avrdude
sudo cp ./avrdude.conf /etc/avrdude.conf
echo ""

echo "setup hotspot"
sudo apt-get install --yes network-manager avahi-daemon
sudo nmcli dev wifi hotspot ifname wlan0 ssid $DID password "$DID"
sudo nmcli con mod Hotspot connection.autoconnect yes
sudo sed -i '15,21d' /etc/NetworkManager/system-connections/Hotspot.nmconnection
sudo cat /etc/NetworkManager/system-connections/Hotspot.nmconnection
sudo sh -c "echo '\n127.0.1.1 duckiebot' >> /etc/hosts"
sudo rm /etc/hostname
sudo sh -c "echo 'duckiebot' >> /etc/hostname"
echo ""

echo "change user password"
echo -e "ubuntu123\n$DID\n$DID" | passwd
echo ""

echo "TODO: clone duckie_msgs and colcon build, then add source overlay to .bashrc"
mkdir -p ~/duckie_ws/src
git clone https://github.com/binitshah/duckie_msgs.git ~/duckie_ws/src/duckie_msgs
cd ~/duckie_ws
source /opt/ros/foxy/setup.bash
colcon build
cd -
echo "source ~/duckie_ws/install/setup.bash" >> ~/.bashrc
echo "export PYTHONOPTIMIZE=1" >> ~/.bashrc
echo ""

echo "running final apt update & upgrade"
sudo apt-get update
sudo apt-get upgrade --yes
sudo apt autoremove --yes
echo ""

echo "Perform a reboot by running 'sudo reboot'"
