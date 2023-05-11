provider "aws" {
  region = "us-east-1"
}

variable "public_key_file" {
  description = "Path to public key file"
  default     = "/home/fsantsil/gitRepo/DockerSwarm/id_rsa.pub"
}

resource "aws_vpc" "swarmVpc" {
  cidr_block = "10.0.0.0/16"
}

# Create an Internet Gateway
resource "aws_internet_gateway" "swarm_igw" {
  vpc_id = aws_vpc.swarmVpc.id

  tags = {
    Name = "swarm_igw"
  }
}

resource "aws_internet_gateway_attachment" "swarm_igw_attachment" {
  internet_gateway_id = aws_internet_gateway.swarm_igw.id
  vpc_id              = aws_vpc.swarmVpc.id
}

# Create a route table
resource "aws_route_table" "swarm_route_table" {
  vpc_id = aws_vpc.swarmVpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.swarm_igw.id
  }

  tags = {
    Name = "swarm_route_table"
  }
}

# Associate the route table with the subnet
resource "aws_route_table_association" "route_table_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.swarm_route_table.id
}

resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.swarmVpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_security_group" "allow_ssh" {
  name_prefix = "allow_ssh"
  description = "Allow SSH inbound traffic"

  vpc_id = aws_vpc.swarmVpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 2377
    to_port     = 2377
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 7946
    to_port     = 7946
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 7946
    to_port     = 7946
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# Create an SSH key pair
resource "aws_key_pair" "swarmKey" {
  key_name   = "id_rsa"
  public_key = file("/home/fsantsil/gitRepo/DockerSwarm/id_rsa.pub")
}



resource "aws_instance" "server" {
  ami           = "ami-0b69ea66ff7391e80"
  instance_type = "t2.micro"
  count         = 3

  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  subnet_id = aws_subnet.public_subnet.id

  user_data = <<EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y docker
              sudo systemctl start docker
              sudo systemctl enable docker
              sudo yum install -y epel-release
              sudo yum install -y ansible
              sudo useradd -m -s /bin/bash centos
              sudo mkdir /home/centos/.ssh
              sudo touch /home/centos/.ssh/authorized_keys
              sudo chmod 700 /home/centos/.ssh
              sudo chmod 600 /home/centos/.ssh/authorized_keys
              sudo chown -R centos:centos /home/centos/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDbZ0I9c6XDO22hKsW0nPfMZC2yjGo6OzZc2+DWcGpzaddVSe29TYpQS70wJY6l37BrgyX4ydFXZOx8LMxiq7yS6eUM+D5/6wu/i2L3H+wU0pgvsBGrIBT39EU5I9AxdXgK5Pk5rfOi18uRC7Dxp+TTECBEmJFZzrFYIMQJDVzNRAIlB9Yu+Qu7bBybbwBJTfnMnYFkCQpvaxtwpqBReGFmY70Ycg/r/KroxAYxhfKRllfzUWu722/qQemo0353FCRD7RuevMqEl1RFXxC3FxBZNMrNkL1SsqMIN8Qe7Up/NOGi1leebUVOxfHmhYbwkQ+cOMCSz34eKMm7cQE11etSl1L9nWwnuh6g5LJljciE14U0DxHT8UCp6fxfz+mxNkhzFdAP3XFrQLrmoZbo50ClpNUvOQF6BnRDMlvw6HKs42Y/hWoRwCzgoPYsYK0GS3chPY5c7Td7IgKblBOeAIppN1NjeOhH1PxXqxhhlIKIn02wTMcKL1t7sNVkDU+qkrU= fsantsil@armmachine" | sudo tee -a /home/centos/.ssh/authorized_keys >/dev/null
              EOF

  tags = {
    Name = "server-${count.index + 1}"
  }
}


resource "aws_instance" "serverC8" {
  ami           = "ami-03b2e02378604bf21"
  instance_type = "t2.micro"
  count         = 5

  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  subnet_id = aws_subnet.public_subnet.id

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install -y docker",
      "sudo systemctl start docker",
      "sudo systemctl enable docker",
      "sudo yum install -y epel-release",
      "sudo yum install -y ansible",
      "sudo useradd -m -s /bin/bash centos",
      "sudo mkdir /home/centos/.ssh",
      "sudo touch /home/centos/.ssh/authorized_keys",
      "sudo chmod 700 /home/centos/.ssh",
      "sudo chmod 600 /home/centos/.ssh/authorized_keys",
      "sudo passwd centos",
      "sudo chown -R centos:centos /home/centos/.ssh",
      "echo \"$(cat /home/fsantsil/gitRepo/DockerSwarm/id_rsa.pub)\" | sudo tee -a /home/centos/.ssh/authorized_keys >> /dev/null",
    ]
  }

  tags = {
    Name = "serverC8-${count.index + 1}"
  }
}
# Allocate and associate an Elastic IP with each server
resource "aws_eip" "swarm_eip" {
  count    = length(aws_instance.serverC8)
  instance = aws_instance.serverC8[count.index].id
  vpc      = true

  tags = {
    Name = "eip_swarm_${count.index + 1}"
  }
}
# Allocate and associate an Elastic IP with each server
resource "aws_eip" "swarm_eip2" {
  count    = length(aws_instance.server)
  instance = aws_instance.server[count.index].id
  vpc      = true

  tags = {
    Name = "eip_swarm_${count.index + 1}"
  }
}

