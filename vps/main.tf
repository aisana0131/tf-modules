##### AWS VPC #####
resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"
    tags = merge (
    {Name = format(local.name, "vpc")},
  local.common_tags
  )
}


###### AWS PUBLIC SUBNETS #####
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidr)
  vpc_id            = aws_vpc.main.id
  map_public_ip_on_launch = true
  cidr_block        = var.public_subnet_cidr[count.index]
  availability_zone = var.azs[count.index]

  tags = merge (
    {Name = format(local.name, "pub-sub-${count.index+1}")},
  local.common_tags
  )
}

###### AWS PRIVATE SUBNETS #####
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidr)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr[count.index]
  availability_zone = var.azs[count.index]

  tags = merge (
    {Name = format(local.name, "priv-sub-${count.index+1}")},
  local.common_tags
  )
}

##### INTERNET GATEWAY ######
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = merge (
    {Name = format(local.name, "igw")},
  local.common_tags
  )
}

###### PUBLIC ROUTE TABLE ##########
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  route {
    cidr_block = var.vpc_cidr
    gateway_id = "local"
  }

  tags = merge (
    {Name = format(local.name, "public-rt")},
  local.common_tags
  )
}

###### PUBLIC SUBNETS ASSOCIATION #####
resource "aws_route_table_association" "public_rt_association" {
  count = length(var.public_subnet_cidr)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

##### EIP #######
resource "aws_eip" "lb" {
  domain = "vpc"
}

##### NAT GATEWAY #####
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.lb.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge (
    {Name = format(local.name, "nat-gw")},
  local.common_tags
  )
}

###### PRIVATE ROUTE TABLE ##########
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id =aws_nat_gateway.nat.id
  }
  route {
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"
  }

  tags = merge (
    {Name = format(local.name, "private-rt")},
  local.common_tags
  )
}

###### PRIVATE SUBNETS ASSOCIATION #####
resource "aws_route_table_association" "private_rt_association" {
  count = length(var.private_subnet_cidr)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private_rt.id
}