provider  "aws" {
	profile = "Asish"
	region = "ap-south-1"
}

resource  "aws_vpc"  "task4_vpc" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames= "true"
 
 tags = {
    Name = "task4_vpc"
  }
}

resource "aws_subnet" "public_subnet" {
   vpc_id     = "${aws_vpc.task4_vpc.id}"
  cidr_block = "192.168.1.0/24"
   availability_zone= "ap-south-1a"
   map_public_ip_on_launch= "true"
  tags = {
    Name = "public_subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id     = "${aws_vpc.task4_vpc.id}"
  cidr_block = "192.168.2.0/24"
  availability_zone= "ap-south-1b"   
  tags = {
    Name = "private_subnet"
  }
}

resource "aws_internet_gateway" "task4_gw" {
  vpc_id = "${aws_vpc.task4_vpc.id}"

  tags = {
    Name = "task4_gw"
  }
}

resource "aws_route_table" "task4_routetable" {
  vpc_id = "${aws_vpc.task4_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.task4_gw.id}"
  }
  
  tags = {
    Name = "task4_routetable"
  }
}


resource "aws_route_table_association" "task4_route_public"{
 subnet_id= aws_subnet.public_subnet.id
  route_table_id = "${aws_route_table.task4_routetable.id}"
}


resource "tls_private_key"  "mytask4key"{
	algorithm= "RSA"
}
resource  "aws_key_pair"   "generated_key"{
	key_name= "mytask4key"
	public_key= "${tls_private_key.mytask4key.public_key_openssh}"
	
	depends_on = [
		tls_private_key.mytask4key
		]
}
resource "local_file"  "store_key_value"{
	
	content= "${tls_private_key.mytask4key.private_key_pem}"
 	filename= "mytask4key.pem"
	file_permission= "0400"
	
	depends_on = [
		tls_private_key.mytask4key
	]
}

resource "aws_security_group"   "wordpresssg" {
  name        = "wordpresssg"
  description = "Security Group for Wordpress site"
  vpc_id      = "${aws_vpc.task4_vpc.id}"

  ingress {
    description = "SSH Protocol"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
    ingress {
    description = "HTTP Protocol"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress{
      description: "ICMP"
       from_port = 0
        to_port = 0
         protocol = "-1"
         cidr_blocks=["0.0.0.0/0"]
    } 

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wordpress_sg"
  }
}

resource "aws_security_group"   "SQLsg" {
  name        = "SQLsg"
  description = "Security Group for SQL DB"
  vpc_id      = "${aws_vpc.task4_vpc.id}"

  ingress {
    description = "SQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups=["${aws_security_group.wordpresssg.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SQL_sg"
  }
}




resource "aws_security_group"   "bastionsg" {
  name        = "bastionsg"
  description = "Security Group for Bastion Instance"
  vpc_id      = "${aws_vpc.task4_vpc.id}"

  ingress {
    description = "SSH Protocol"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion_sg"
  }
}





resource "aws_security_group"   "sqlconnectivitysg" {
  name        = "sqlconnectivitysg"
  description = "Security Group for Bastion Instance and SQL connectivity"
  vpc_id      = "${aws_vpc.task4_vpc.id}"

  ingress {
    description = "SSH Protocol"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_groups=["${aws_security_group.bastionsg.id}"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sqlconnectivity_sg"
  }
}

	

resource  "aws_eip"  "task4_eip"{
	vpc= true
}

resource "aws_nat_gateway"   "task4_ng"{
	allocation_id= "${aws_eip.task4_eip.id}"
	subnet_id= "${aws_subnet.public_subnet.id}"

	tags = {
	    Name = "task4_ng"
	}
}


resource "aws_route_table" "task4_routetable_2" {
  vpc_id = "${aws_vpc.task4_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.task4_ng.id}"
  }
  
  tags = {
    Name = "task4_routetable_2"
  }
}


resource "aws_route_table_association" "task4_route_private"{
 subnet_id= aws_subnet.private_subnet.id
  route_table_id = "${aws_route_table.task4_routetable_2.id}"
}

resource "aws_instance" "wordpress_os"{
	ami= "ami-000cbce3e1b899ebd"
	instance_type= "t2.micro"
	subnet_id= "${aws_subnet.public_subnet.id}"
	vpc_security_group_ids= ["${aws_security_group.wordpresssg.id}"]
	key_name= "mytask4key"
	
	tags = {
	     Name = "wordpress_os"
	}
}

resource "aws_instance"    "sql_os"{
	ami = "ami-08706cb5f68222d09"
	instance_type= "t2.micro"
	subnet_id= "${aws_subnet.private_subnet.id}"
	vpc_security_group_ids=["${aws_security_group.SQLsg.id}","${aws_security_group.sqlconnectivitysg.id}"]
	  key_name= "mytask4key"
	
	tags = {
	        Name="sql_os"
	}
}

resource "aws_instance"  "bastion_os"{
	ami = "ami-0732b62d310b80e97"
	instance_type="t2.micro"
	subnet_id= "${aws_subnet.public_subnet.id}"
	vpc_security_group_ids= ["${aws_security_group.bastionsg.id}"]
	key_name="mytask4key"
	
	tags={
	    Name= " bastion_os"
	}
}

output "mywordpressos_ip" {
  value = aws_instance.wordpress_os.public_ip
}

output "mysqlOSPrivate_ip" {
  value = aws_instance.sql_os.private_ip
}

output "bastionos_ip" {
  value = aws_instance.bastion_os.public_ip
}
