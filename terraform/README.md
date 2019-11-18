Terraform project for aws configure
------------------
  
######### NETWORK ###############
================
1. Create VPC main
2. Create subnet application in VPC
3. Create subnet db in VPC
4. Create and attach inet_gw to VPC
5. Create route_table in VPC
6. Create sec_group in VPC
7. Link route_table with subnet application

########### INSTANCES ################
============
1. Find ubuntu1804 ami
2. Create worker instance in subnet application
3. Create db instance in subnet db
