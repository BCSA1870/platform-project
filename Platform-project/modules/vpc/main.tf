resource "aws_vpc" "bcsap1" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true   # lets resources have DNS names
  enable_dns_support   = true
 
  tags = {
    Name        = "BCSAP1"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}
 
# Internet Gateway — the door between public subnet and the internet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.bcsap1.id
  tags   = { Name = "BCSAP1-IGW", Environment = var.env }
}
 
# Public subnet — where ALB lives, has a route to the internet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.bcsap1.id
  cidr_block              = var.public_cidr
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true   # resources here get public IPs
 
  tags = { Name = "BCSAP1-Public", Environment = var.env }
}
 
# Second public subnet — ALB requires two AZs for high availability
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.bcsap1.id
  cidr_block              = var.public_cidr_b
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true
 
  tags = { Name = "BCSAP1-Public-B", Environment = var.env }
}
 
# Private subnet — where ECS containers run, no direct internet
resource "aws_subnet" "private" {
vpc_id            = aws_vpc.bcsap1.id
  cidr_block        = var.private_cidr
  availability_zone = "${var.region}a"
 
  tags = { Name = "BCSAP1-Private", Environment = var.env }
}
 
# Second private subnet — for future RDS or multi-AZ ECS
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.bcsap1.id
  cidr_block        = var.private_cidr_b
  availability_zone = "${var.region}b"
 
  tags = { Name = "BCSAP1-Private-B", Environment = var.env }
}
 
# Elastic IP for NAT Gateway (static public IP address)
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "BCSAP1-NAT-EIP" }
}
 
# NAT Gateway — lets private resources reach internet outbound only
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id   # NAT lives in PUBLIC subnet
 
  tags = { Name = "BCSAP1-NAT", Environment = var.env }
}
 
# Route table for public subnet — send all traffic to Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.bcsap1.id
 
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
 
  tags = { Name = "BCSAP1-Public-RT" }
}
 
# Route table for private subnet — send internet traffic through NAT
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.bcsap1.id
 
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
 
  tags = { Name = "BCSAP1-Private-RT" }
}
 
# Associate public subnets with public route table
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
 
resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}
 
# Associate private subnets with private route table
resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
 
resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}
