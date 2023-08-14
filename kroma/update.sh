#!/bin/bash

sed -i '/CHAIN_ID/d' $HOME/.profile
sed -i '/CHAIN_ID/d' $HOME/.bash_profile
unset CHAIN_ID
ufw disable

docker-compose -f $HOME/kroma-up/docker-compose.yml --profile validator down

ip_addr=$(curl -s ifconfig.me)
sed -i "s/L1_RPC_ENDPOINT=.*/L1_RPC_ENDPOINT=http:\/\/$ip_addr:58545/" $HOME/kroma-up/.env

source $HOME/kroma-up/.env

cd $HOME/kroma-up

git checkout -- docker-compose.yml

git pull origin main

sudo tee <<EOF >/dev/null $HOME/kroma-up/docker-compose.yml
version: '3.9'
x-logging: &logging
  logging:
    driver: json-file
    options:
      max-size: 10m
      max-file: "3"

services:
  kroma-geth:
    container_name: kroma-geth
    image: kromanetwork/geth:${IMAGE_TAG__KROMA_GETH:-dev-fa80ead}
    restart: unless-stopped
    env_file:
      - envs/${NETWORK_NAME}/geth.env
    entrypoint: 
      - /bin/sh
      - /.kroma/entrypoint.sh
    ports:
      - 6060:6060
      - 8545:8545
      - 8546:8546
      - 8551:8551
      - 30304:30304/tcp
      - 30303:30303/udp
    volumes:
      - db:/.kroma/db
      - ./keys/jwt-secret.txt:/.kroma/keys/jwt-secret.txt
      - ./config/${NETWORK_NAME}/genesis.json:/.kroma/config/genesis.json
      - ./scripts/entrypoint.sh:/.kroma/entrypoint.sh
    profiles:
      - vanilla
      - validator
    <<: *logging

  kroma-node:
    depends_on:
      - kroma-geth
    user: root
    container_name: kroma-node
    image: kromanetwork/node:${IMAGE_TAG__KROMA_NODE:-v0.2.2}
    restart: unless-stopped
    env_file:
      - envs/${NETWORK_NAME}/node.env
    ports:
      - 9545:8545
      - 7300:7300
      - 9003:9003/tcp
      - 9003:9003/udp
    volumes:
      - ./keys/p2p-node-key.txt:/.kroma/keys/p2p-node-key.txt
      - ./keys/jwt-secret.txt:/.kroma/keys/jwt-secret.txt
      - ./config/${NETWORK_NAME}/rollup.json:/.kroma/config/rollup.json
      - ./logs:/.kroma/logs
    profiles:
      - vanilla
      - validator
    <<: *logging

  kroma-validator:
    depends_on:
      - kroma-node
    container_name: kroma-validator
    image: kromanetwork/validator:${IMAGE_TAG__KROMA_VALIDATOR:-v0.2.2}
    restart: unless-stopped
    env_file:
      - envs/${NETWORK_NAME}/validator.env
    profiles:
      - validator
    <<: *logging

volumes:
  db:
EOF

docker-compose --profile validator up -d