provider "aws" {
  #access_key=""
  #security_key=""
  region = "${var.aws-region}"
}

######################## NETWORK ############################

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "main"
  }
}

resource "aws_subnet" "application" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "application"
  }
}
resource "aws_subnet" "db" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "db"
  }
}
resource "aws_internet_gateway" "inet_gw" {
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "inet_gw"
  }
}

resource "aws_route_table" "application" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.inet_gw.id}"
  }

  tags = {
    Name = "application"
  }
}

# resource "aws_route_table" "db" {
#   vpc_id = "${aws_vpc.main.id}"
#
#   route {
#     cidr_block = "10.0.0.0/16"
#   }
#
#   tags = {
#     Name = "db"
#   }
# }

resource "aws_security_group" "application" {
  vpc_id = "${aws_vpc.main.id}"
  name   = "application"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 22
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "allow_all"
  }
}

resource "aws_route_table_association" "application" {
  subnet_id      = "${aws_subnet.application.id}"
  route_table_id = "${aws_route_table.application.id}"
}

# resource "aws_route_table_association" "db" {
#   subnet_id      = "${aws_subnet.db.id}"
#   route_table_id = "${aws_route_table.db.id}"
# }

################ INSTANCES ###################
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bio*amd64*"]
  }
}


#####################################


resource "aws_instance" "worker" {
  ami                         = data.aws_ami.ubuntu.image_id
  instance_type               = "t2.micro"
  subnet_id                   = "${aws_subnet.application.id}"
  associate_public_ip_address = true
  private_ip                  = "10.0.1.10"
  security_groups             = ["${aws_security_group.application.id}"]
  key_name                    = "aws_key"

  tags = {
    Name = "worker"
  }
}

resource "aws_instance" "db_instance" {
  ami             = data.aws_ami.ubuntu.image_id
  instance_type   = "t2.micro"
  subnet_id       = "${aws_subnet.db.id}"
  private_ip      = "10.0.2.10"
  key_name        = "jump_key"
  security_groups = ["${aws_security_group.application.id}"]

  tags = {
    Name = "db_instance"
  }
}

#########################################################
###########################################################
###########################################################

###### Create network for db #####################
resource "aws_subnet" "db-subnet-a" {
  vpc_id            = "${aws_vpc.main.id}"
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-west-3a"

  tags = {
    Name = "db-subnet-a"
  }
}

resource "aws_subnet" "db-subnet-b" {
  vpc_id            = "${aws_vpc.main.id}"
  cidr_block        = "10.0.4.0/24"
  availability_zone = "eu-west-3b"
  tags = {
    Name = "db-subnet-b"
  }
}

##### bound A and B  AZ subnet in db_subnet_group ############
resource "aws_db_subnet_group" "postgres" {
  name       = "main"
  subnet_ids = ["${aws_subnet.db-subnet-a.id}", "${aws_subnet.db-subnet-b.id}"]

  tags = {
    Name = "postgres"
  }
}

########## Create sg for db_sg ###############

resource "aws_security_group" "db" {
  vpc_id = "${aws_vpc.main.id}"
  name   = "db"

  ingress {
    from_port   = 22
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 22
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "22-5432 allow"
  }
}
########## Create db_sg for db ###############
# resource "aws_db_security_group" "postgres" {
#   name = "postgres"
#
#   ingress {
#     cidr              = "10.0.0.0/16"
#     security_group_id = "${aws_security_group.db.id}"
#   }
# }

########## Create db instance #####################
resource "aws_db_instance" "postgres" {
  allocated_storage         = 20
  storage_type              = "gp2"
  engine                    = "postgres"
  engine_version            = "11.5"
  instance_class            = "db.t2.micro"
  name                      = "postgres_instance"
  username                  = "postgres"
  password                  = "postgres"
  db_subnet_group_name      = "${aws_db_subnet_group.postgres.id}"
  port                      = "5432"
  final_snapshot_identifier = "false"
  identifier                = "postgres"
  multi_az                  = "false"
  vpc_security_group_ids    = ["${aws_security_group.db.id}"]
  skip_final_snapshot       = "false"
  #security_group_names = ["postgres"]

  tags = {
    Name = "postgres"
  }
}
