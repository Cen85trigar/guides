#!/bin/bash

function colors {
  GREEN="\e[32m"
  RED="\e[39m"
  NORMAL="\e[0m"
}

function logo {
  curl -s https://raw.githubusercontent.com/DOUBLE-TOP/tools/main/doubletop.sh | bash
}

function line {
  echo -e "\e[39m##############################################################################\e[0m"
}

function install_tools {
  sudo apt update && sudo apt install mc wget htop jq git ocl-icd-opencl-dev libopencl-clang-dev libgomp1 expect -y
}

function wget_pulsar {
  LEVEL=$(awk '
  BEGIN {
      while (!/flags/) if (getline < "/proc/cpuinfo" != 1) exit 1
      if (/lm/&&/cmov/&&/cx8/&&/fpu/&&/fxsr/&&/mmx/&&/syscall/&&/sse2/) level = 1
      if (level == 1 && /cx16/&&/lahf/&&/popcnt/&&/sse4_1/&&/sse4_2/&&/ssse3/) level = 2
      if (level == 2 && /avx/&&/avx2/&&/bmi1/&&/bmi2/&&/f16c/&&/fma/&&/abm/&&/movbe/&&/xsave/) level = 3
      if (level == 3 && /avx512f/&&/avx512bw/&&/avx512cd/&&/avx512dq/&&/avx512vl/) level = 4
      print level; 
  }')

  # Выбор URL для скачивания на основе уровня
  if (( LEVEL >= 4 )); then
      URL="https://github.com/subspace/pulsar/releases/download/v0.6.5-alpha/pulsar-ubuntu-x86_64-skylake-v0.6.5-alpha"
  else
      URL="https://github.com/subspace/pulsar/releases/download/v0.6.5-alpha/pulsar-ubuntu-x86_64-v2-v0.6.5-alpha"
  fi
  wget -O pulsar $URL
  sudo chmod +x pulsar
  sudo mv pulsar /usr/local/bin/
}

function read_nodename {
  if [ ! $SUBSPACE_NODENAME ]; then
  echo -e "Enter your node name(random name for telemetry)"
  line
  read SUBSPACE_NODENAME
  export SUBSPACE_NODENAME
  sleep 1
  fi
}

function read_wallet {
  if [ ! $WALLET_ADDRESS ]; then
  echo -e "Enter your polkadot.js extension address"
  line
  read WALLET_ADDRESS
  export WALLET_ADDRESS
  sleep 1
  fi
}

function init_expect {
    sudo rm -rf $HOME/.config/pulsar
    expect <(curl -s https://raw.githubusercontent.com/DOUBLE-TOP/guides/main/subspace/expect)
}

function systemd {
  sudo tee <<EOF >/dev/null /etc/systemd/system/subspace.service
[Unit]
Description=Subspace Node
After=network.target

[Service]
User=$USER
Type=simple
ExecStart=/usr/local/bin/pulsar farm --verbose
Restart=on-failure
LimitNOFILE=548576:1048576

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable subspace
sudo systemctl restart subspace
}

function output_after_install {
    echo -e '\n\e[42mCheck node status\e[0m\n' && sleep 5
    if [[ `systemctl status subspace | grep active` =~ "running" ]]; then
        echo -e "Your Subspace node \e[32minstalled and works\e[39m!"
        echo -e "You can check node status by the command \e[7msystemctl status subspace\e[0m"
        echo -e "Press \e[7mQ\e[0m for exit from status menu"
    else
        echo -e "Your Subspace node \e[31mwas not installed correctly\e[39m, please reinstall."
    fi
}

function main {
    colors
    line
    logo
    line
    read_nodename
    read_wallet
    install_tools
    wget_pulsar
    init_expect
    systemd
    output_after_install
}

main