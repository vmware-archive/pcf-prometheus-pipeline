#!/bin/bash

function login_to_director() {
  CREDS=$1

  export BOSH_CA_CERT=$(cat $CREDS/bosh-ca.pem)
  export BOSH_ENVIRONMENT=$(cat $CREDS/director_ip)
  export BOSH_CLIENT=$(cat $CREDS/bosh-username)
  export BOSH_CLIENT_SECRET=$(cat $CREDS/bosh-pass)
}
