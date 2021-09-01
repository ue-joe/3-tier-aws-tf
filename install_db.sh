#!/bin/bash
yum update -y
yum install -y mariadb-server
systemctl start mariadb.service
systemctl enable mariadb.service