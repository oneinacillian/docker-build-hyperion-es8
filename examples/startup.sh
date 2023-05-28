#!/bin/bash
systemctl start elasticsearch
systemctl start kibana
systemctl start rabbitmq-server
systemctl start redis-server
tail -f /dev/null